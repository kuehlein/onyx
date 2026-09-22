// This IS the built-in Behavioral flow's engine; a new subject runs on the
// generic vault-flow path (flow_runner), so the type filter doesn't reintroduce
// the invariant-#2 drift the guard prevents elsewhere.
// ignore_for_file: no_card_type_branch
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/behavioral_interviewer.dart';
import '../../core/ai/claude_service.dart';
import '../../core/interview/assessment.dart';
import '../../core/interview/behavioral_grader.dart';
import '../../core/practice/mock_session.dart';
import '../../core/readiness/target.dart';
import '../../core/srs/recognition.dart';
import '../models/card.dart';
import 'ai.dart';
import 'clock.dart';
import 'interview.dart';
import 'readiness.dart';
import 'srs.dart';
import 'vault.dart';

part 'behavioral.g.dart';

/// The recognition-clock section key for a competency's re-mock schedule.
const _recognitionSlug = 'mock';

/// Applied-attempt source tag for behavioral mocks.
const behavioralSource = 'behavioral';

/// Maps a mock's overall score to a spaced-recurrence outcome (same lightweight
/// expanding-interval scheduler the other tracks use). Carries NO readiness weight;
/// only decides when a competency is due to re-practice.
ExplainOutcome _scoreToRecurrence(int score) => score >= 70
    ? ExplainOutcome.solid
    : score >= 45
        ? ExplainOutcome.shaky
        : ExplainOutcome.lost;

/// Behavioral competencies ordered by **spaced recurrence**: overdue re-mocks
/// first (most overdue first), then never-mocked, then upcoming (soonest due).
@riverpod
Future<List<Card>> behavioralCompetencies(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(recognitionRepositoryProvider).loadStates();
  final now = (await ref.watch(clockProvider.future)).now();
  // Read studyCards (not cards) so status:draft competencies are excluded from
  // the practice list — the ADR-0003 invariant the sibling tracks already honor.
  final cards = [
    for (final c in index.studyCards)
      if (c.type == kTypeBehavioral) c,
  ];
  DateTime? dueOf(Card c) => states['${c.id}::$_recognitionSlug']?.dueAt;
  // 0 = overdue, 1 = never mocked, 2 = upcoming.
  int bucket(Card c) {
    final d = dueOf(c);
    if (d == null) return 1;
    return d.isAfter(now) ? 2 : 0;
  }

  cards.sort((a, b) {
    final ba = bucket(a), bb = bucket(b);
    if (ba != bb) return ba.compareTo(bb);
    final da = dueOf(a), db = dueOf(b);
    if (da != null && db != null) return da.compareTo(db);
    return a.title.compareTo(b.title);
  });
  return cards;
}

/// The due date for a competency's next re-mock, or null if never mocked.
@riverpod
Future<DateTime?> behavioralDue(Ref ref, String competencyId) async {
  final states = await ref.watch(recognitionRepositoryProvider).loadStates();
  return states['$competencyId::$_recognitionSlug']?.dueAt;
}

/// Auto support mode from demonstrated competence: **coaching** until a few mocks
/// are done AND scoring decently, then **realistic** (scaffolding fade). Overridable
/// per session in the UI.
@riverpod
Future<SupportMode> behavioralAutoSupportMode(Ref ref) async {
  final attempts = await ref
      .watch(appliedRepositoryProvider)
      .attempts(domain: behavioralSource);
  final mocks = [
    for (final a in attempts)
      if (a.source == behavioralSource) a,
  ];
  if (mocks.length < 3) return SupportMode.coaching;
  final recent = mocks.take(3).toList();
  final mean =
      recent.map((a) => a.appliedScore).reduce((x, y) => x + y) / recent.length;
  return mean >= 60 ? SupportMode.realistic : SupportMode.coaching;
}

/// Drives one behavioral mock interview on the shared mock-session engine
/// (core/practice/mock_session.dart): a hard-coded opener posing a competency
/// prompt, interviewer turns (calibrated by level + support), then on End an
/// interviewer debrief plus an adversarial grader **panel** over the cold
/// transcript that records the applied-transfer attempt and advances the
/// spaced-recurrence clock. A post-mock tutor teaches STAR+L. Ephemeral per
/// competency id. This class supplies only the behavioral prompts/rubric + what to
/// record on a grade.
@riverpod
class BehavioralMockSession extends _$BehavioralMockSession {
  static const _model = 'claude-sonnet-4-6';
  static const _panelSize = 3;

  @override
  MockSessionState build(String competencyId) => const MockSessionState();

  ClaudeService? _claudeOrError() {
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = state.copyWith(
          error: 'Add your Anthropic API key in Settings to run a mock.');
    }
    return claude;
  }

  /// Kick off the interview with a terse, hard-coded opener (a prompt from the
  /// competency's bank).
  void start({required Card card}) =>
      state = mockStart(state, behavioralOpeningLine(card));

  /// Send the candidate's turn (interviewer while running, tutor once done).
  Future<void> send(
    String text, {
    required Card card,
    required SeniorityLevel level,
    required SupportMode support,
  }) async {
    final claude = _claudeOrError();
    if (claude == null) return;
    await mockSend(
      claude: claude,
      model: _model,
      text: text,
      read: () => state,
      write: (s) => state = s,
      runningSystem: buildBehavioralInterviewerSystem(
          card: card, level: level, support: support),
      doneSystem: buildBehavioralTutorSystem(card: card, level: level),
    );
  }

  /// End the interview: interviewer debrief, adversarial grader panel over the
  /// transcript, record the applied attempt (assisted mocks are softer evidence),
  /// and advance the spaced-recurrence clock.
  Future<void> endAndGrade({
    required Card card,
    required SeniorityLevel level,
    required SupportMode support,
  }) async {
    final claude = _claudeOrError();
    if (claude == null) return;
    await mockEndAndGrade(
      claude: claude,
      model: _model,
      panelSize: _panelSize,
      read: () => state,
      write: (s) => state = s,
      interviewerSystem: buildBehavioralInterviewerSystem(
          card: card, level: level, support: support),
      graderSystem: buildBehavioralGraderSystem(card: card, level: level),
      dimensions: behavioralRubricDimensions.toSet(),
      onGraded: (grade) async {
        final now = (await ref.read(clockProvider.future)).now();
        await ref.read(appliedRepositoryProvider).record(
              cardId: card.id,
              domain: card.domain,
              source: behavioralSource,
              occurredAt: now,
              assessment: AppliedAssessment(
                appliedScore: grade.appliedScore,
                rubric: grade.rubric,
                // Coaching-mode mocks were assisted → softer evidence.
                hintLevel: support == SupportMode.coaching ? 1 : 0,
                note: grade.note,
              ),
            );
        await ref.read(recognitionRepositoryProvider).recordExplain(
              cardId: card.id,
              sectionSlug: _recognitionSlug,
              outcome: _scoreToRecurrence(grade.appliedScore),
              now: now,
            );
        ref
          ..invalidate(appliedTransferProvider)
          ..invalidate(behavioralCompetenciesProvider)
          ..invalidate(behavioralDueProvider)
          ..invalidate(behavioralAutoSupportModeProvider);
      },
    );
  }
}
