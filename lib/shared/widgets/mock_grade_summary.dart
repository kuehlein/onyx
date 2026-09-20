import 'package:flutter/material.dart';

import '../../core/interview/assessment.dart' show rubricLabel;
import '../../core/practice/mock_grader.dart';
import '../design/onyx_design.dart';

/// A clean banner of a reconciled mock [MockGrade]: a prominent score disc, a
/// calibrated verdict label, per-dimension rubric bars, and the grader's note.
/// Shared by every mock practice track (system design, behavioral); pass the
/// track's rubric [dimensions] (in display order) and a [feedsLabel] naming which
/// readiness it feeds.
class MockGradeSummary extends StatelessWidget {
  const MockGradeSummary({
    super.key,
    required this.grade,
    required this.dimensions,
    required this.feedsLabel,
  });

  final MockGrade grade;
  final List<String> dimensions;
  final String feedsLabel;

  ({String label, Color color}) get _verdict {
    final s = grade.appliedScore;
    if (s >= 80) return (label: 'Strong', color: StatusColor.good);
    if (s >= 65) return (label: 'Solid', color: StatusColor.good);
    if (s >= 50) return (label: 'Developing', color: StatusColor.warn);
    return (label: 'Needs work', color: StatusColor.bad);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = _verdict;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          Dim.space4, Dim.space3, Dim.space4, Dim.space1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: Dim.brSheet,
        border: Border.all(color: v.color.withValues(alpha: Dim.emphasisLow)),
      ),
      padding: const EdgeInsets.all(Dim.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ScoreDisc(score: grade.appliedScore, color: v.color),
              const SizedBox(width: Dim.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.label,
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: v.color, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(feedsLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          if (grade.rubric.isNotEmpty) ...[
            const SizedBox(height: Dim.space4),
            for (final key in dimensions)
              if (grade.rubric[key] != null)
                _RubricRow(label: rubricLabel(key), value: grade.rubric[key]!),
          ],
          if ((grade.note ?? '').isNotEmpty) ...[
            const SizedBox(height: Dim.space3),
            Text(grade.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: Dim.space1),
          Text('Read the debrief below, or ask the coach how to improve.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ScoreDisc extends StatelessWidget {
  const _ScoreDisc({required this.score, required this.color});
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 5,
              backgroundColor: color.withValues(alpha: Dim.fill),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text('$score',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RubricRow extends StatelessWidget {
  const _RubricRow({required this.label, required this.value});
  final String label;
  final int value; // 1..5

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Dim.space2),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 1; i <= 5; i++) ...[
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= value
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  if (i < 5) const SizedBox(width: Dim.space1),
                ],
              ],
            ),
          ),
          const SizedBox(width: Dim.space3),
          Text('$value/5', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
