import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/flow_grader.dart';
import '../../core/interview/assessment.dart';
import '../../core/practice/mock_session.dart';
import '../../core/subject/active_subject.dart';
import '../../core/subject/dependency_gating.dart';
import '../../core/subject/flow_prompt.dart';
import '../../core/subject/flow_spec.dart';
import '../models/card.dart';
import 'ai.dart';
import 'clock.dart';
import 'interview.dart';
import 'practice_plan.dart';
import 'readiness.dart';
import 'srs.dart';
import 'system_design.dart' show scoreToRecurrence;
import 'vault.dart';

part 'flow_runner.g.dart';

/// A config-driven flow/card unlocks once at least this fraction of its
/// `depends-on` concepts clears the competence bar — the SAME bar the covered
/// frontier is drawn at, so "unlocked" and "the AI may use it" coincide.
const double kFlowGateBar = 0.7;

/// The recognition-clock section key for a config-flow card's re-practice schedule
/// (shared with every mock flow — see system_design.dart / behavioral.dart).
const _recognitionSlug = 'mock';

/// Drives one **config-driven** practice flow (task #30, "G2b") on the shared
/// mock-session engine (core/practice/mock_session.dart) — the GENERIC sibling of
/// [SdMockSession]/[BehavioralMockSession] for vault-authored flows (e.g. a Korean
/// `conversation` flow with `scheduling: mock`). The interlocutor + grader personas
/// come from the vault `skill` file (assembled by [assembleFlowPrompt] /
/// [buildFlowGraderSystem]); this class only wires the engine and records what a
/// grade means (an applied-transfer attempt + a spaced-recurrence advance).
///
/// Deliberately free of vault I/O: the caller (the future screen) loads the
/// [skill] text with `loadFlowSkill` and computes the covered-knowledge [frontier]
/// from the card's `depends-on` competence, then passes both in — so this Notifier
/// is trivially testable. Ephemeral per card id.
@riverpod
class FlowRunnerSession extends _$FlowRunnerSession {
  // Quality-critical path (the interlocutor must stay on-task and the grader must
  // resist sycophancy), so use a stronger model than the cheap default. The user
  // supplies their own key; mocks are occasional.
  static const _model = 'claude-sonnet-4-6';

  /// How many independent adversarial graders vote on the final score.
  static const _panelSize = 3;

  @override
  MockSessionState build(String cardId) => const MockSessionState();

  ClaudeService? _claudeOrError() {
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = state.copyWith(
          error: 'Add your Anthropic API key in Settings to run a mock.');
    }
    return claude;
  }

  /// Kick off the session with a terse, generic opener that doesn't leak the
  /// answer (the vault skill owns the actual scenario/persona).
  void start({
    required Card card,
    required String skill,
    required Set<String> frontier,
  }) =>
      state = mockStart(state, "Whenever you're ready — go ahead.");

  /// Send the learner's turn (the vault interlocutor while running, the tutor once
  /// done). [skill]/[frontier] are supplied by the caller (no vault I/O here).
  Future<void> send(
    String text, {
    required Card card,
    required String skill,
    required Set<String> frontier,
  }) async {
    final claude = _claudeOrError();
    if (claude == null) return;
    await mockSend(
      claude: claude,
      model: _model,
      text: text,
      read: () => state,
      write: (s) => state = s,
      runningSystem: assembleFlowPrompt(
          skill: skill, problem: card.overview, frontier: frontier),
      doneSystem: buildFlowTutorSystem(skill: skill, frontier: frontier),
    );
  }

  /// End the session: an interlocutor debrief, an adversarial grader panel over
  /// the cold transcript, record the applied attempt, and advance the
  /// spaced-recurrence clock (schedules the next re-practice).
  Future<void> endAndGrade({
    required Card card,
    required String skill,
    required Set<String> frontier,
  }) async {
    final claude = _claudeOrError();
    if (claude == null) return;
    await mockEndAndGrade(
      claude: claude,
      model: _model,
      panelSize: _panelSize,
      read: () => state,
      write: (s) => state = s,
      interviewerSystem: assembleFlowPrompt(
          skill: skill, problem: card.overview, frontier: frontier),
      graderSystem: buildFlowGraderSystem(
          skill: skill, problem: card.overview, frontier: frontier),
      dimensions: flowRubricDimensions.toSet(),
      onGraded: (grade) async {
        final now = (await ref.read(clockProvider.future)).now();
        await ref.read(appliedRepositoryProvider).record(
              cardId: card.id,
              domain: card.domain,
              source: card.type,
              occurredAt: now,
              assessment: AppliedAssessment(
                appliedScore: grade.appliedScore,
                rubric: grade.rubric,
                hintLevel: 0,
                note: grade.note,
              ),
            );
        // Advance the spaced-recurrence clock (schedules the next re-practice).
        await ref.read(recognitionRepositoryProvider).recordExplain(
              cardId: card.id,
              sectionSlug: _recognitionSlug,
              outcome: scoreToRecurrence(grade.appliedScore),
              now: now,
            );
        ref
          ..invalidate(appliedTransferProvider)
          ..invalidate(practiceAvailabilityProvider);
      },
    );
  }
}

/// Everything the [FlowRunnerScreen] needs to run one config-driven flow, resolved
/// off the vault + SRS state so the screen holds no vault I/O. Built by
/// [flowRunnerContext].
class FlowRunnerContext {
  const FlowRunnerContext({
    required this.card,
    required this.flow,
    required this.skill,
    required this.frontier,
    required this.gate,
    this.weakLabels = const {},
  });

  /// The card for the requested id, or null when it isn't in the index (the
  /// screen renders a calm empty state).
  final Card? card;

  /// The flow describing [card]'s `type:` (drives the label/icon), or null.
  final FlowSpec? flow;

  /// The vault-authored interlocutor/grader skill text, or null when the flow
  /// declares none or the file is missing (the screen treats it as unavailable —
  /// this generic runner only serves vault flows).
  final String? skill;

  /// The covered-knowledge frontier (concepts at/above [kFlowGateBar]) the AI may
  /// draw on. Empty → no vocabulary constraint.
  final Set<String> frontier;

  /// The `depends-on` competence gate (soft — the screen offers "Start anyway").
  final GateStatus gate;

  /// Friendly display labels for the gate's still-weak prerequisites
  /// (conceptId → card title), for the gate panel. Falls back to the id.
  final Map<String, String> weakLabels;
}

/// Resolves the [FlowRunnerContext] for [cardId]: finds the card, loads its flow's
/// vault skill, and computes the `depends-on` competence gate + covered frontier —
/// the SAME per-concept `comfort` measure the daily plan uses (fraction of a
/// concept card's quizzable sections with SRS state), with a filename→id hop
/// because `depends-on` may reference a concept by its file slug.
@riverpod
Future<FlowRunnerContext> flowRunnerContext(Ref ref, String cardId) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  final source = ref.read(vaultSourceProvider);

  final card = index.cards.where((c) => c.id == cardId).firstOrNull;
  if (card == null) {
    return const FlowRunnerContext(
      card: null,
      flow: null,
      skill: null,
      frontier: {},
      gate: GateStatus(unlocked: true, metFraction: 1, satisfied: [], weak: []),
    );
  }

  final flow = activeSubject.flowForType(card.type);
  final skill =
      source == null ? null : await loadFlowSkill(source.readCard, flow?.skill);

  // Per-concept comfort = fraction of a concept card's quizzable sections that
  // have SRS state (mirrors daily_plan.dart). Index concept cards by filename
  // slug too, since `depends-on` may name a concept by its file, not its id.
  final comfort = <String, double>{};
  final label = <String, String>{};
  final conceptIdByFile = <String, String>{};
  for (final c in index.cards) {
    if (c.type != kTypeFlashcard) continue;
    final slug = c.filePath.split('/').last.replaceFirst(RegExp(r'\.md$'), '');
    conceptIdByFile[slug] = c.id;
    label[c.id] = c.title;
    final q = c.quizzableSections.toList();
    if (q.isEmpty) continue;
    final studied =
        q.where((s) => states.byKey.containsKey('${c.id}::${s.slug}')).length;
    comfort[c.id] = studied / q.length;
  }
  double comfortOf(String dep) =>
      comfort[dep] ?? comfort[conceptIdByFile[dep] ?? ''] ?? 0.0;
  String labelOf(String dep) =>
      label[dep] ?? label[conceptIdByFile[dep] ?? ''] ?? dep;

  final gate = evaluateGate(
    dependsOn: card.dependsOn,
    competenceOf: comfortOf,
    competenceBar: kFlowGateBar,
  );
  final frontier = coveredFrontier(
    concepts: card.dependsOn,
    competenceOf: comfortOf,
    competenceBar: kFlowGateBar,
  );
  return FlowRunnerContext(
    card: card,
    flow: flow,
    skill: skill,
    frontier: frontier,
    gate: gate,
    weakLabels: {for (final d in gate.weak) d: labelOf(d)},
  );
}
