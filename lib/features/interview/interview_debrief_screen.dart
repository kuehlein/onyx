import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/coach_update_chat.dart' show CoachRole;
import '../../core/ai/interview_debrief.dart';
import '../../core/deck/aim.dart' show AimOutcome;
import '../../core/readiness/readiness.dart' show prettyDomain;
import '../../shared/design/onyx_design.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/interview_debrief.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/chat_view.dart';

/// The post-interview debrief chat for one aim: say how it went, and the coach
/// records the outcome + adjusts the plan toward what you were weak on
/// (approve-then-apply). Reached from the interview sheet (#90).
class InterviewDebriefScreen extends ConsumerStatefulWidget {
  const InterviewDebriefScreen({required this.aimId, super.key});

  /// The [Aim.id] being debriefed (on the active deck).
  final String aimId;

  @override
  ConsumerState<InterviewDebriefScreen> createState() =>
      _InterviewDebriefScreenState();
}

class _InterviewDebriefScreenState
    extends ConsumerState<InterviewDebriefScreen> {
  Future<void> _apply() async {
    final messenger = ScaffoldMessenger.of(context);
    final aim =
        await ref.read(interviewDebriefProvider(widget.aimId).notifier).apply();
    if (aim == null) return;
    messenger.showSnackBar(
        const SnackBar(content: Text('Debrief saved — your plan is updated.')));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(interviewDebriefProvider(widget.aimId));
    final hasKey = ref.watch(claudeServiceProvider) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Interview debrief')),
      body: !hasKey
          ? const _NeedsKey()
          : ChatView(
              messages: [
                for (final m in state.messages)
                  ChatTurn(isUser: m.role == CoachRole.user, text: m.text),
              ],
              busy: state.busy,
              error: state.error,
              hintText: 'e.g. Went well on graphs, blanked on a DP one…',
              opener: const _Opener(),
              trailing: state.result != null
                  ? _DebriefCard(state.result!, _apply)
                  : null,
              onSend: (t) => ref
                  .read(interviewDebriefProvider(widget.aimId).notifier)
                  .send(t),
            ),
    );
  }
}

class _Opener extends StatelessWidget {
  const _Opener();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Dim.space5),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined,
              size: Dim.iconLg, color: theme.colorScheme.primary),
          const SizedBox(height: Dim.space3),
          Text('How did it go?',
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Dim.space2),
          Text(
            'Tell me how the interview went — what felt strong, where you '
            'struggled, any question you couldn’t finish. I’ll record the '
            'outcome and adjust your remaining study for what came up.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DebriefCard extends StatelessWidget {
  const _DebriefCard(this.result, this.onApply);

  final DebriefResult result;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Reweighted domains/concepts, strongest boost first.
    final domains = result.domainWeights.keys.toList()
      ..sort((a, b) =>
          result.domainWeights[b]!.compareTo(result.domainWeights[a]!));
    final concepts = result.conceptWeights.keys.toList()
      ..sort((a, b) =>
          result.conceptWeights[b]!.compareTo(result.conceptWeights[a]!));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: Dim.space2),
      padding: const EdgeInsets.all(Dim.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: Dim.brCard,
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: Dim.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Proposed adjustments',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          if (result.outcome != null && result.outcome != AimOutcome.pending)
            Padding(
              padding: const EdgeInsets.only(top: Dim.space1),
              child: Text(
                  'Outcome: '
                  '${result.outcome == AimOutcome.passed ? 'Passed' : 'Didn’t pass'}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          if (domains.isNotEmpty) ...[
            const SizedBox(height: Dim.space3),
            _ChipRow(
                label: 'Focus more on',
                items: domains,
                tone: StatusTone.accent),
          ],
          if (concepts.isNotEmpty) ...[
            const SizedBox(height: Dim.space2),
            _ChipRow(
                label: 'Concepts', items: concepts, tone: StatusTone.muted),
          ],
          if (result.summary.isNotEmpty) ...[
            const SizedBox(height: Dim.space3),
            CardMarkdown(result.summary, compact: true),
          ],
          const SizedBox(height: Dim.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.check),
              label: const Text('Apply to my plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow(
      {required this.label, required this.items, required this.tone});

  final String label;
  final List<String> items;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: Dim.space2),
        Wrap(
          spacing: Dim.space2,
          runSpacing: Dim.space2,
          children: [
            for (final it in items)
              StatusPill(tone: tone, label: prettyDomain(it), dense: true),
          ],
        ),
      ],
    );
  }
}

class _NeedsKey extends StatelessWidget {
  const _NeedsKey();

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'Add your Anthropic API key to debrief an interview.',
        action: FilledButton.tonal(
          onPressed: () => context.go('/settings'),
          child: const Text('Open Settings'),
        ),
      );
}
