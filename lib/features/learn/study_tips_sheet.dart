import 'package:flutter/material.dart';

import '../../core/study/study_tips.dart';
import '../../shared/widgets/fading_scroll_edges.dart';

/// Opens the full list of evidence-based study tips as a bottom sheet. Available
/// from the Learn app bar (studying / first exposure), not while testing.
Future<void> showStudyTipsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => const _StudyTipsSheet(),
  );
}

class _StudyTipsSheet extends StatelessWidget {
  const _StudyTipsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('Study tips', style: theme.textTheme.titleLarge),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Habits that make learning stick — worth keeping in mind as you go.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FadingScrollEdges(
              color: theme.colorScheme.surfaceContainerLow,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: studyTips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) => _TipRow(studyTips[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow(this.tip);
  final StudyTip tip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_outline,
              size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tip.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(tip.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single-slide reminder shown once before a Learn session starts — one
/// rotating tip to prime the learner, then a Start button into the cards. A
/// brief priming moment (not clutter during study), consistent with keeping the
/// study screen itself focused.
class StudyTipIntro extends StatelessWidget {
  const StudyTipIntro({
    super.key,
    required this.tip,
    required this.onStart,
    required this.onMore,
  });

  final StudyTip tip;
  final VoidCallback onStart;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text('Before you start',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 12),
              Text(tip.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(tip.body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.45, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Start learning'),
              ),
              const SizedBox(height: 4),
              TextButton(onPressed: onMore, child: const Text('More tips')),
            ],
          ),
        ),
      ),
    );
  }
}
