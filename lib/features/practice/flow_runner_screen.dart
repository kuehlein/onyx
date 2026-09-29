// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/coach.dart' show CoachRole;
import '../../core/interview/assessment.dart' show flowRubricDimensions;
import '../../core/practice/mock_session.dart';
import '../../core/template/flow_spec.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/flow_runner.dart';
import '../../shared/widgets/chat_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/mock_grade_summary.dart';
import '../../shared/widgets/session_timer.dart';

/// A live, **config-driven** practice flow for one card (task #30, "G2b-2") — the
/// generic sibling of [SdMockScreen]/[BehavioralMockScreen] for vault-authored
/// flows (e.g. a Korean `conversation`). Like those, you land straight in it: it
/// auto-starts, a count-up stopwatch times the answer, and on End an adversarial
/// grader panel scores the transcript; afterward you can keep chatting with a
/// tutor to learn. The interlocutor/grader persona comes from the flow's vault
/// `skill` file; the covered-knowledge frontier (and the soft `depends-on` gate)
/// are resolved by [flowRunnerContext].
class FlowRunnerScreen extends ConsumerStatefulWidget {
  const FlowRunnerScreen({
    super.key,
    required this.flowType,
    required this.cardId,
  });

  /// The card `type:` (== the practice-track id), carried for routing symmetry.
  final String flowType;
  final String cardId;

  @override
  ConsumerState<FlowRunnerScreen> createState() => _FlowRunnerScreenState();
}

class _FlowRunnerScreenState extends ConsumerState<FlowRunnerScreen> {
  // The learner tapped "Start anyway" past the soft prerequisite gate. Access-
  // only: an override never confers competence (see flow_access.dart), so it lives
  // as ephemeral screen state, not a stored flag.
  bool _override = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(flowRunnerContextProvider(widget.cardId));
    return async.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (_, __) => const Scaffold(
        body: EmptyState(
          icon: Icons.explore_off_outlined,
          title: "This practice isn't available",
        ),
      ),
      data: (ctx) {
        final card = ctx.card;
        final flow = ctx.flow;
        final skill = ctx.skill;
        // No card, or a flow with no vault skill: this generic runner only serves
        // vault-authored flows — show a calm, non-alarming empty state.
        if (card == null || flow == null || skill == null) {
          return const Scaffold(
            appBar: null,
            body: SafeArea(
              child: EmptyState(
                icon: Icons.explore_off_outlined,
                title: "This practice isn't available",
                message:
                    "This flow doesn't have a practice script yet, so there's "
                    'nothing to run here.',
              ),
            ),
          );
        }

        // Soft gate: prerequisites unmet and not opened early → the gate panel.
        if (!ctx.gate.unlocked && !_override) {
          return _GatePanel(
            flow: flow,
            weakLabels: ctx.weakLabels,
            gateWeak: ctx.gate.weak,
            onStartAnyway: () => setState(() => _override = true),
          );
        }

        return _RunnerBody(
          cardId: widget.cardId,
          card: card,
          flow: flow,
          skill: skill,
          frontier: ctx.frontier,
        );
      },
    );
  }
}

/// The soft prerequisite gate (mirrors the provisional/"open anyway" intent of
/// flow_access.dart): this flow builds on things the learner hasn't studied yet.
/// Never a hard wall — "Start anyway" opens it provisionally; Back steps out.
class _GatePanel extends StatelessWidget {
  const _GatePanel({
    required this.flow,
    required this.weakLabels,
    required this.gateWeak,
    required this.onStartAnyway,
  });

  final FlowSpec flow;
  final Map<String, String> weakLabels;
  final List<String> gateWeak;
  final VoidCallback onStartAnyway;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Friendly prerequisite names (fall back to the raw id), de-duplicated.
    final missing = {for (final d in gateWeak) weakLabels[d] ?? d}.toList();

    return Scaffold(
      appBar: AppBar(title: Text(flow.displayLabel)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Dim.space6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, size: Dim.iconLg, color: cs.primary),
                  const SizedBox(height: Dim.space4),
                  Text(
                    'This builds on things you haven\'t studied yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: Dim.space3),
                    Text(
                      'Get comfortable with these first for the most out of it:',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: Dim.space2),
                    for (final m in missing)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: Dim.space1 / 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.circle,
                                size: Dim.space1, color: cs.onSurfaceVariant),
                            const SizedBox(width: Dim.space2),
                            Flexible(
                              child: Text(m, style: theme.textTheme.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: Dim.space6),
                  FilledButton(
                    onPressed: onStartAnyway,
                    child: const Text('Start anyway'),
                  ),
                  const SizedBox(height: Dim.space2),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The runnable session (once unlocked or overridden). Drives
/// [FlowRunnerSession] exactly like [SdMockScreen] drives its mock session.
class _RunnerBody extends ConsumerStatefulWidget {
  const _RunnerBody({
    required this.cardId,
    required this.card,
    required this.flow,
    required this.skill,
    required this.frontier,
  });

  final String cardId;
  final Card card;
  final FlowSpec flow;
  final String skill;
  final Set<String> frontier;

  @override
  ConsumerState<_RunnerBody> createState() => _RunnerBodyState();
}

class _RunnerBodyState extends ConsumerState<_RunnerBody> {
  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final flow = widget.flow;
    final skill = widget.skill;
    final frontier = widget.frontier;

    final state = ref.watch(flowRunnerSessionProvider(widget.cardId));
    final session = ref.read(flowRunnerSessionProvider(widget.cardId).notifier);
    final theme = Theme.of(context);
    final running = state.phase == MockPhase.running;
    final done = state.phase == MockPhase.done;

    // Land straight in the session (like the SD/Algorithms sessions).
    if (state.phase == MockPhase.intro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          session.start(card: card, skill: skill, frontier: frontier);
        }
      });
    }

    // Whether the learner has actually answered (beyond the assistant opener).
    // If not, "End" is really a cancel: pop without grading or spending tokens.
    final answered = state.messages.any((m) => m.role == CoachRole.user);

    return Scaffold(
      appBar: AppBar(
        title: Text(card.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (running && !state.busy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dim.space2),
              child: TextButton.icon(
                onPressed: answered
                    ? () => session.endAndGrade(
                        card: card, skill: skill, frontier: frontier)
                    : () => Navigator.of(context).maybePop(),
                icon: Icon(answered ? Icons.flag_outlined : Icons.close,
                    size: Dim.iconMd),
                label: Text(answered ? 'End & grade' : 'Cancel'),
              ),
            ),
          if (done)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dim.space2),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.check, size: Dim.iconMd),
                label: const Text('Done'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (running || state.phase == MockPhase.grading)
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              child: const Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        Dim.space4, Dim.space2, Dim.space3, Dim.space2),
                    child: Row(
                      children: [
                        SessionTimer(
                            mode: TimerMode.countUp, idleLabel: 'Answer timer'),
                      ],
                    ),
                  ),
                  Divider(height: 1),
                ],
              ),
            ),
          if (state.grade != null)
            MockGradeSummary(
              grade: state.grade!,
              dimensions: flowRubricDimensions,
              feedsLabel: '${flow.displayLabel} practice',
            ),
          Expanded(
            child: ChatView(
              messages: [
                for (final m in state.messages)
                  ChatTurn(isUser: m.role == CoachRole.user, text: m.text),
              ],
              onSend: (t) =>
                  session.send(t, card: card, skill: skill, frontier: frontier),
              busy: state.busy,
              error: state.error,
              enabled: running || done,
              hintText: running
                  ? 'Type your response…'
                  : done
                      ? 'Ask how to improve…'
                      : 'Grading…',
              fadeColor: theme.colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}
