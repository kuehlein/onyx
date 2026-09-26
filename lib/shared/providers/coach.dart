import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/coach.dart';
import '../../core/database/database.dart';
import '../../core/interview/critic.dart';
import '../models/card.dart';
import '../../core/clock.dart';
import 'ai.dart';
import 'clock.dart';
import 'database.dart';
import 'interview.dart';
import 'readiness.dart';
import 'template.dart';
import 'vault.dart';

part 'coach.g.dart';

/// The active subject's coach **skill augmentation**, loaded from its vault skill
/// ([DeckTemplate.coachSkill] → `_meta/coach.md`, parsed by
/// [coachSkillFromMarkdown]), or [CoachSkill.none] when the subject declares no
/// skill or the file is missing — the research-backed foundation always stands,
/// and a subject's vault skill layers its own domain framing on top.
@riverpod
Future<CoachSkill> coachSkill(Ref ref) async {
  // Any failure to resolve the subject / vault / skill → no augmentation; the
  // research-backed foundation still stands, so a coach turn never breaks because
  // a skill file couldn't load.
  try {
    final source = ref.watch(vaultSourceProvider);
    final config = await ref.watch(activeTemplateConfigProvider.future);
    final name = config.coachSkill;
    if (name == null || source == null) return CoachSkill.none;
    final md = await source.readMeta(name);
    return md == null ? CoachSkill.none : coachSkillFromMarkdown(md);
  } catch (_) {
    return CoachSkill.none;
  }
}

/// The conversation state for one coach surface.
class CoachState {
  const CoachState({
    this.messages = const [],
    this.busy = false,
    this.error,
    this.done = false,
  });

  final List<CoachMessage> messages;

  /// A reply is in flight.
  final bool busy;

  /// A user-presentable failure from the last send (network/auth), or null.
  final String? error;

  /// First-exposure tutor only (n0015): the exchange has wrapped up — the tutor
  /// emitted `<tutor-done/>` or the learner-turn cap was reached. The UI stops
  /// soliciting more turns. Always false for the coach/examiner personas.
  final bool done;

  bool get isEmpty => messages.isEmpty;

  /// The most recent advisory grade the coach offered, or null. Drives the
  /// button highlight in the study screen.
  int? get suggestedGrade {
    for (final m in messages.reversed) {
      if (m.role == CoachRole.assistant) return m.suggestedGrade;
    }
    return null;
  }

  CoachState copyWith({
    List<CoachMessage>? messages,
    bool? busy,
    String? error,
    bool clearError = false,
    bool? done,
  }) =>
      CoachState(
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
        done: done ?? this.done,
      );
}

/// A coach conversation keyed by card (and optional section slug). Persisted to
/// the local `coach_messages` table, so it survives leaving and re-entering the
/// chat (and a restore-from-vault). It is never written to the vault snapshot,
/// so it is intentionally dropped on reinstall.
@riverpod
class Coach extends _$Coach {
  /// The subject's skill augmentation, resolved as part of this provider's own
  /// build (not with a fresh await inside `send`, which would open a disposal
  /// window on the slow vault read). Re-resolved whenever the skill changes.
  CoachSkill _skill = CoachSkill.none;

  /// The surface this conversation belongs to (n0015) — set from the [build]
  /// family arg and used to scope BOTH the load filter and every persisted row,
  /// so a tutor and an examiner never share a transcript on one `(card, section)`.
  CoachKind _kind = CoachKind.coach;

  @override
  Future<CoachState> build(String cardId, String? sectionSlug,
      {CoachKind kind = CoachKind.coach}) async {
    _kind = kind;
    // Register both deps before the first await (disposal hazard: a rebuild while
    // the vault read is pending must not leave a post-await `ref.watch`).
    final skillFuture = ref.watch(coachSkillProvider.future);
    final db = ref.watch(appDatabaseProvider);
    _skill = await skillFuture;
    // Multiple where() calls AND together, avoiding the `&` operator import.
    final rows = await (db.select(db.coachMessages)
          ..where((m) => m.cardId.equals(cardId))
          ..where((m) => sectionSlug == null
              ? m.sectionSlug.isNull()
              : m.sectionSlug.equals(sectionSlug))
          ..where((m) => m.kind.equals(kind.name))
          ..orderBy([(m) => OrderingTerm(expression: m.id)]))
        .get();
    return CoachState(messages: rows.map(_toMessage).toList());
  }

  /// Send [text] as the learner's turn and append the coach's reply, persisting
  /// both. [card] and [section] supply the material; [revealed] and [grading]
  /// shape the coach's behavior (hint vs. discuss; whether an advisory grade
  /// may be offered).
  Future<void> send(
    String text, {
    required Card card,
    CardSection? section,
    required bool revealed,
    required bool grading,
    bool firstExposure = false,
    String? interviewContext,
  }) async {
    final current = state.asData?.value ?? const CoachState();
    final trimmed = text.trim();
    if (trimmed.isEmpty || current.busy || current.done) return;

    // First-exposure tutor (n0015): a HARD learner-turn cap enforced in code, not
    // just the prompt. Once the learner has used their allowed turns, wrap up
    // rather than send again.
    if (firstExposure &&
        current.messages.where((m) => m.role == CoachRole.user).length >=
            firstExposureMaxLearnerTurns) {
      state = AsyncData(current.copyWith(done: true));
      return;
    }

    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = AsyncData(current.copyWith(
          error: 'Add your Anthropic API key in Settings to use the coach.'));
      return;
    }

    final db = ref.read(appDatabaseProvider);
    const userMessage = CoachRole.user;
    await _persist(db, card.id, section?.slug, userMessage, trimmed, null);
    final history = [...current.messages, CoachMessage(userMessage, trimmed)];
    state = AsyncData(
        current.copyWith(messages: history, busy: true, clearError: true));

    try {
      final reply = await claude.chat(
        system: buildCoachSystem(
          card: card,
          section: section,
          revealed: revealed,
          grading: grading,
          firstExposure: firstExposure,
          interviewContext: interviewContext,
          skill: _skill, // resolved in build(); no await gap here
        ),
        messages: [
          for (final m in history)
            (
              role: m.role == CoachRole.user ? 'user' : 'assistant',
              content: m.text,
            ),
        ],
      );
      if (firstExposure) {
        // First exposure never grades: parse only text + the <tutor-done/> close
        // (no applied assessment). Wrap up on the sentinel or the learner-turn cap.
        final fe = parseFirstExposureReply(reply);
        await _persist(
            db, card.id, section?.slug, CoachRole.assistant, fe.text, null);
        final done = fe.done ||
            history.where((m) => m.role == CoachRole.user).length >=
                firstExposureMaxLearnerTurns;
        state = AsyncData(current.copyWith(
          messages: [...history, CoachMessage(CoachRole.assistant, fe.text)],
          busy: false,
          done: done,
        ));
        return;
      }
      final parsed = parseCoachReply(reply);
      await _persist(db, card.id, section?.slug, CoachRole.assistant,
          parsed.text, parsed.grade);
      // In a mock interview, log the coach's structured applied assessment —
      // separate from the human FSRS grade; it only feeds readiness.
      if (grading && parsed.assessment != null) {
        final clock = ref.read(clockProvider).asData?.value ?? Clock.real;
        final attemptId = await ref.read(appliedRepositoryProvider).record(
              cardId: card.id,
              sectionSlug: section?.slug,
              domain: card.domain,
              assessment: parsed.assessment!,
              source: 'interview-coach',
              occurredAt: clock.now(),
            );
        // Refresh the dashboard: new applied evidence can graduate readiness.
        ref.invalidate(appliedTransferProvider);
        // Bounded adversarial second opinion — best-effort; never fails the send.
        await _runCritic(
          claude: claude,
          card: card,
          section: section,
          history: [...history, CoachMessage(CoachRole.assistant, parsed.text)],
          attemptId: attemptId,
          coachScore: parsed.assessment!.appliedScore,
        );
      }
      state = AsyncData(current.copyWith(
        messages: [
          ...history,
          CoachMessage(CoachRole.assistant, parsed.text,
              suggestedGrade: parsed.grade),
        ],
        busy: false,
      ));
    } on ClaudeException catch (e) {
      state = AsyncData(current.copyWith(
          messages: history, busy: false, error: _friendly(e)));
    }
  }

  /// Runs the bounded adversarial second opinion on an applied attempt: a
  /// skeptical, independent grader re-scores the candidate's answers, and the
  /// verdict (its score + whether it corroborates the coach) is stored so the
  /// readiness signal uses the reconciled mean. Best-effort: any failure is
  /// swallowed so a critic hiccup never disrupts the coaching turn.
  Future<void> _runCritic({
    required ClaudeService claude,
    required Card card,
    required CardSection? section,
    required List<CoachMessage> history,
    required int attemptId,
    required int coachScore,
  }) async {
    try {
      final reply = await claude.complete(
        system: buildCriticSystem(
            card: card, section: section, topicFit: _skill.topicFit),
        prompt: buildCriticTranscript([
          for (final m in history)
            (
              role: m.role == CoachRole.user ? 'user' : 'assistant',
              content: m.text,
            ),
        ]),
        maxTokens: 200,
      );
      final verdict = parseCriticVerdict(reply);
      if (verdict == null) return;
      await ref.read(appliedRepositoryProvider).recordVerdict(
            attemptId: attemptId,
            verifierScore: verdict.appliedScore,
            verified: criticAgrees(coachScore, verdict.appliedScore),
          );
      ref.invalidate(appliedTransferProvider);
    } catch (_) {
      // Second opinion is advisory; leave the attempt with the coach score.
    }
  }

  Future<void> _persist(
    AppDatabase db,
    String cardId,
    String? sectionSlug,
    CoachRole role,
    String body,
    int? suggestedGrade,
  ) =>
      db.into(db.coachMessages).insert(CoachMessagesCompanion.insert(
            cardId: cardId,
            sectionSlug: Value(sectionSlug),
            kind: Value(_kind.name),
            role: role == CoachRole.user ? 'user' : 'assistant',
            body: body,
            suggestedGrade: Value(suggestedGrade),
            createdAt: DateTime.now(),
          ));

  CoachMessage _toMessage(CoachMessageRow row) => CoachMessage(
        row.role == 'user' ? CoachRole.user : CoachRole.assistant,
        row.body,
        suggestedGrade: row.suggestedGrade,
      );
}

/// Deletes the per-section coach conversations **of one [kind]**, leaving Browse
/// (whole-card, null-section) chats and the *other* kind intact. Called at the
/// start of each study session so a previous session's chats never resurface —
/// scoped by kind (n0015) so a Learn session clearing its [CoachKind.tutor] rows
/// no longer wipes the Review [CoachKind.examiner] transcript, and vice-versa. A
/// chat still survives closing/reopening the coach *within* a session (reloaded
/// from the DB).
Future<void> clearTestCoachConversations(AppDatabase db, CoachKind kind) =>
    (db.delete(db.coachMessages)
          ..where((m) => m.sectionSlug.isNotNull())
          ..where((m) => m.kind.equals(kind.name)))
        .go();

/// Turn raw API failures into something calm and actionable for the learner.
String _friendly(ClaudeException e) {
  if (e.statusCode == 401) {
    return 'Your Anthropic API key was rejected — it may have expired or been '
        'revoked. Update it in Settings (or your .env on desktop).';
  }
  if (e.message.toLowerCase().contains('credit balance')) {
    return 'Your Anthropic API account is out of credits. The API bills '
        'separately from a Claude Pro/Max subscription — add credits at '
        'console.anthropic.com → Billing.';
  }
  if (e.message.startsWith('Network error')) {
    return "Couldn't reach Claude — check your connection and try again.";
  }
  return e.message;
}
