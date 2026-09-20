import 'package:flutter/material.dart';

import '../../core/study/study_tips.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/widgets/fading_scroll_edges.dart';
import '../../shared/widgets/sheet_header.dart';

/// Opens the full list of evidence-based study tips as a bottom sheet. Available
/// from the Learn app bar (studying / first exposure), not while testing.
Future<void> showStudyTipsSheet(BuildContext context) {
  return showOnyxSheet<void>(
    context,
    builder: (_) => const _StudyTipsSheet(),
  );
}

class _StudyTipsSheet extends StatelessWidget {
  const _StudyTipsSheet();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeader(
            icon: Icons.tips_and_updates_outlined,
            title: 'Study tips',
            subtitle:
                'Habits that make learning stick — worth keeping in mind.',
            divider: true,
          ),
          Expanded(
            child: FadingScrollEdges(
              color: sheetSurface(context),
              child: ListView.separated(
                padding:
                    const EdgeInsets.fromLTRB(20, Dim.space3, 20, Dim.space5),
                itemCount: studyTips.length,
                separatorBuilder: (_, __) => const SizedBox(height: Dim.space4),
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
          padding: const EdgeInsets.only(top: Dim.space1),
          child: Icon(Icons.check_circle_outline,
              size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: Dim.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tip.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: Dim.space1),
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
        constraints: const BoxConstraints(maxWidth: Dim.maxNarrowWidth),
        child: Padding(
          padding: const EdgeInsets.all(Dim.space6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: Dim.space5),
              Text('Before you start',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: Dim.space3),
              Text(tip.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: Dim.space3),
              Text(tip.body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.45, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: Dim.space6),
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: Dim.space4)),
                child: const Text('Start learning'),
              ),
              const SizedBox(height: Dim.space1),
              TextButton(onPressed: onMore, child: const Text('More tips')),
            ],
          ),
        ),
      ),
    );
  }
}
