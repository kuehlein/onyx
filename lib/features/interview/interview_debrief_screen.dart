import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/coach_update_chat.dart' show CoachRole;
import '../../core/ai/interview_debrief.dart';
import '../../core/readiness/prep_goal.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/interview_debrief.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/chat_view.dart';

/// The post-interview debrief chat for one prep goal: say how it went, and the
/// coach records the outcome + adjusts the plan toward what you were weak on
/// (approve-then-apply). Reached from a goal in the upcoming-interviews list.
class InterviewDebriefScreen extends ConsumerStatefulWidget {
  const InterviewDebriefScreen({required this.goalId, super.key});

  final String goalId;

  @override
  ConsumerState<InterviewDebriefScreen> createState() =>
      _InterviewDebriefScreenState();
}

class _InterviewDebriefScreenState
    extends ConsumerState<InterviewDebriefScreen> {
  Future<void> _apply() async {
    final messenger = ScaffoldMessenger.of(context);
    final goal = await ref
        .read(interviewDebriefProvider(widget.goalId).notifier)
        .apply();
    if (goal == null) return;
    messenger.showSnackBar(
        const SnackBar(content: Text('Debrief saved — your plan is updated.')));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(interviewDebriefProvider(widget.goalId));
    final hasKey = ref.watch(claudeServiceProvider) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Interview debrief')),
      body: !hasKey
          ? _NeedsKey(theme)
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
                  .read(interviewDebriefProvider(widget.goalId).notifier)
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined,
              size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('How did it go?',
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
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
    final muted = theme.colorScheme.onSurfaceVariant;
    // Reweighted domains/concepts, strongest boost first.
    final domains = result.domainWeights.keys.toList()
      ..sort((a, b) =>
          result.domainWeights[b]!.compareTo(result.domainWeights[a]!));
    final concepts = result.conceptWeights.keys.toList()
      ..sort((a, b) =>
          result.conceptWeights[b]!.compareTo(result.conceptWeights[a]!));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Proposed adjustments',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          if (result.outcome != null && result.outcome != GoalOutcome.pending)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  'Outcome: '
                  '${result.outcome == GoalOutcome.passed ? 'Passed' : 'Didn’t pass'}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          if (domains.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ChipRow(
                label: 'Focus more on',
                items: domains,
                color: theme.colorScheme.primary),
          ],
          if (concepts.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ChipRow(label: 'Concepts', items: concepts, color: muted),
          ],
          if (result.summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            CardMarkdown(result.summary, compact: true),
          ],
          const SizedBox(height: 14),
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
      {required this.label, required this.items, required this.color});

  final String label;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final it in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(_pretty(it),
                    style: theme.textTheme.labelSmall?.copyWith(color: color)),
              ),
          ],
        ),
      ],
    );
  }

  /// A readable label for a domain/concept key (ds-a → "DS & A").
  String _pretty(String key) {
    switch (key) {
      case 'ds-a':
        return 'DS & A';
      case 'system-design':
        return 'System design';
    }
    return key
        .split(RegExp(r'[-_]'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _NeedsKey extends StatelessWidget {
  const _NeedsKey(this.theme);
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Add your Anthropic API key to debrief an interview.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => context.go('/settings'),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
