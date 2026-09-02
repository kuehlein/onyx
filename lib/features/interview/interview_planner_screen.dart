import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/coach_update_chat.dart' show CoachRole;
import '../../core/ai/interview_plan.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/interview_planner.dart';
import '../../shared/widgets/card_markdown.dart';

const _amber = Color(0xFFE3B341);

/// The "plan an interview" chat: describe an upcoming interview, answer any
/// clarifying questions, review the proposed plan, and save it as an active
/// prep goal (which then reprioritises study via the targeting layer).
class InterviewPlannerScreen extends ConsumerStatefulWidget {
  const InterviewPlannerScreen({super.key});

  @override
  ConsumerState<InterviewPlannerScreen> createState() =>
      _InterviewPlannerScreenState();
}

class _InterviewPlannerScreenState
    extends ConsumerState<InterviewPlannerScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await ref.read(interviewPlannerProvider.notifier).send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _accept() async {
    final messenger = ScaffoldMessenger.of(context);
    final goal = await ref.read(interviewPlannerProvider.notifier).accept();
    if (goal == null) return;
    messenger.showSnackBar(SnackBar(
        content: Text('Prep goal saved — study is now prioritised for '
            '${goal.companyName}.')));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(interviewPlannerProvider);
    final hasKey = ref.watch(claudeServiceProvider) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Plan an interview')),
      body: !hasKey
          ? _NeedsKey(theme)
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    children: [
                      if (state.isEmpty) const _Opener(),
                      for (final m in state.messages)
                        _Bubble(isUser: m.role == CoachRole.user, text: m.text),
                      if (state.plan != null) _PlanCard(state.plan!, _accept),
                      if (state.busy)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Thinking…'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (state.error != null)
                  Container(
                    width: double.infinity,
                    color: theme.colorScheme.errorContainer,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Text(state.error!,
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer)),
                  ),
                _InputBar(controller: _input, busy: state.busy, onSend: _send),
              ],
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
          Icon(Icons.event_note_outlined,
              size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Describe your interview',
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Company, role, team, and roughly when. I’ll build a study plan '
            'from what you already have — and flag what to prep elsewhere. '
            'Company specifics are advisory, so correct me if I’m off.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(this.plan, this.onSave);

  final InterviewPlan plan;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Domains/concepts sorted by weight, strongest first.
    final domains = plan.domainWeights.keys.toList()
      ..sort(
          (a, b) => plan.domainWeights[b]!.compareTo(plan.domainWeights[a]!));
    final concepts = plan.conceptWeights.keys.toList()
      ..sort(
          (a, b) => plan.conceptWeights[b]!.compareTo(plan.conceptWeights[a]!));

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
          Text('Proposed plan',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 4),
          Text('${plan.company}${plan.role.isEmpty ? '' : ' · ${plan.role}'}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(
            plan.date == null
                ? 'No date set'
                : 'Interview: ${_fmt(plan.date!)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (domains.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ChipRow(
                label: 'Prioritise',
                items: domains,
                color: theme.colorScheme.primary),
          ],
          if (concepts.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ChipRow(label: 'Concepts', items: concepts, color: muted),
          ],
          if (plan.missingConcepts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
                'As you build your deck, consider adding: '
                '${plan.missingConcepts.join(', ')}.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ],
          if (plan.appGaps.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: _amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      'Onyx doesn’t cover: '
                      '${plan.appGaps.join(', ')} — prep that elsewhere.',
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: _amber)),
                ),
              ],
            ),
          ],
          if (plan.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            CardMarkdown(plan.summary, compact: true),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.check),
              label: Text('Save & activate — prioritise for ${plan.company}'),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
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
                child: Text(prettyLabel(it),
                    style: theme.textTheme.labelSmall?.copyWith(color: color)),
              ),
          ],
        ),
      ],
    );
  }

  /// A readable label for a domain/concept key (ds-a → "DS & A").
  String prettyLabel(String key) {
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.isUser, required this.text});

  final bool isUser;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: isUser
                  ? Text(text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          height: 1.4,
                          color: theme.colorScheme.onPrimaryContainer))
                  : CardMarkdown(text, compact: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar(
      {required this.controller, required this.busy, required this.onSend});

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: busy ? null : (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'e.g. Google, senior backend, Maps, in 2 weeks…',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: busy ? null : onSend,
              icon: const Icon(Icons.arrow_upward),
              style: IconButton.styleFrom(
                  fixedSize: const Size(40, 40), padding: EdgeInsets.zero),
            ),
          ],
        ),
      ),
    );
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
            Text('Add your Anthropic API key to plan an interview.',
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
