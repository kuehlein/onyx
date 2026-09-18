import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/story_coach.dart'
    show CoachRole, StoryDraft, buildStoryCoachSystem;
import '../../core/readiness/target.dart';
import '../../core/story/competency.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/story.dart';
import '../../shared/providers/story_coach_chat.dart';
import '../../shared/widgets/chat_view.dart';

/// The career brain-dump: the coach interviews you about your career and drafts
/// STAR+L stories you save to the vault. Gap-targeted (drives toward the
/// competencies you don't yet have a story for). Builds material — never grades.
class StoryCaptureScreen extends ConsumerWidget {
  const StoryCaptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasKey = ref.watch(claudeServiceProvider) != null;
    final state = ref.watch(storyCoachChatProvider);
    final notifier = ref.read(storyCoachChatProvider.notifier);

    // Coverage → gap-targeted system prompt. A competency is "covered" once a
    // complete story tags it.
    final stories = ref.watch(storiesProvider).asData?.value ?? const [];
    final covered = <String>{
      for (final s in stories)
        if (s.isComplete) ...s.competencies,
    };
    final have = [
      for (final k in kCompetencyKeys)
        if (covered.contains(k)) k
    ];
    final gaps = [
      for (final k in kCompetencyKeys)
        if (!covered.contains(k)) k
    ];
    final level = ref.watch(activeTargetProvider).asData?.value.level.label;
    final system = buildStoryCoachSystem(have: have, gaps: gaps, level: level);

    return Scaffold(
      appBar: AppBar(title: const Text('Build your stories')),
      body: Column(
        children: [
          _CoverageStrip(covered: covered.length),
          Expanded(
            child: !hasKey
                ? const _NoKey()
                : ChatView(
                    messages: [
                      for (final m in state.messages)
                        ChatTurn(
                            isUser: m.role == CoachRole.user, text: m.text),
                    ],
                    busy: state.busy,
                    error: state.error,
                    hintText: 'Tell the coach about your career…',
                    opener: _Opener(gaps: gaps),
                    trailing: state.draft == null
                        ? null
                        : _DraftCard(
                            draft: state.draft!,
                            onSave: () => _save(context, ref),
                            onDismiss: notifier.dismissDraft,
                          ),
                    onSend: (t) => notifier.send(t, system: system),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final story = await ref.read(storyCoachChatProvider.notifier).saveDraft();
    if (story != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Saved “${story.title}” to your story bank.')),
      );
    }
  }
}

class _CoverageStrip extends StatelessWidget {
  const _CoverageStrip({required this.covered});
  final int covered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = kBehavioralCompetencies.length;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Icon(Icons.checklist_rtl_outlined,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text('$covered of $total competencies covered',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Opener extends StatelessWidget {
  const _Opener({required this.gaps});
  final List<String> gaps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = gaps.take(3).map(competencyLabel).join(', ');
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.auto_stories_outlined,
              size: 36, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Tell me about your career and I\'ll help you turn it into strong '
            'STAR stories — a situation, what you did, and the result. Just talk; '
            'I\'ll draft, and you save the ones you like.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Let\'s start with what you\'re missing: $missing.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// The coach's drafted story, shown at the foot of the transcript with Save / Not
/// now. Saving writes a markdown note to the vault's story bank.
class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.onSave,
    required this.onDismiss,
  });

  final StoryDraft draft;
  final VoidCallback onSave;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Draft story',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(draft.title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (draft.competencies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in draft.competencies)
                  Chip(
                    label: Text(competencyLabel(c)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
          if (!draft.hasQuantifiedResult) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No number in the result yet — a metric makes it much stronger.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save to story bank'),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onDismiss, child: const Text('Not now')),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoKey extends StatelessWidget {
  const _NoKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Building stories needs an Anthropic API key — add one in Settings.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
