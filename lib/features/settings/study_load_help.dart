import 'package:flutter/material.dart';

/// A plain-language reference on study load — what the daily levers mean, a
/// suggested start-slow-then-ramp plan, and the one guardrail that keeps it
/// sustainable. Opened from Settings (near the load controls), not shown on
/// Home; the coach carries the dynamic, personal version.
Future<void> showStudyLoadHelp(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => const _StudyLoadHelp(),
  );
}

class _StudyLoadHelp extends StatelessWidget {
  const _StudyLoadHelp();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text('How much should I study?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Ambitious but sustainable — start light and ramp up.',
              style: muted),
          const SizedBox(height: 20),
          const _H('The five activities'),
          _P(
              'You make progress on five fronts. They cost very different '
              'amounts of time:',
              muted),
          const SizedBox(height: 8),
          const _Bullet(
              'Learn — new concept cards. Quick each, but this is the '
              'hidden load dial: every new card creates a tail of future '
              'reviews.'),
          const _Bullet(
              'Review — concept cards coming due. Seconds each; the count '
              'is set by FSRS, not by you.'),
          const _Bullet(
              'Algorithms — the time sink. A fresh solve is 20–40 min; an '
              'explain is ~5 min and phone-doable.'),
          const _Bullet(
              'Mock interviews — the applied test. ~20–40 min; you start '
              'these yourself.'),
          const _Bullet(
              'Interview prep — set a target/date so the rest aims at it.'),
          const SizedBox(height: 20),
          const _H('A start-slow ramp'),
          _P('Only step up when the week felt fine (see the guardrail below).',
              muted),
          const SizedBox(height: 12),
          const _RampTable(),
          const SizedBox(height: 20),
          const _H('The one guardrail'),
          _P(
              'Let recent review success be your gauge. Aim for ~90%. If it '
              'holds and reviews aren’t piling up, you have room to add a '
              'little. If it drops below ~80% or a backlog builds, hold or ease '
              'off — that’s the signal the load is too high. Chasing higher '
              'than ~90% isn’t worth it; it explodes the workload for little '
              'gain.',
              muted),
          const SizedBox(height: 16),
          _P(
              'New cards are the lever to ramp slowly — everything else mostly '
              'follows from them. The coach on Home watches these signals and '
              'will suggest an adjustment when it sees room (or strain).',
              muted),
        ],
      ),
    );
  }
}

class _RampTable extends StatelessWidget {
  const _RampTable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final head =
        theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);
    final cell = theme.textTheme.bodySmall;
    TableRow row(List<String> cells, {bool header = false}) => TableRow(
          decoration: header
              ? BoxDecoration(color: theme.colorScheme.surfaceContainerHighest)
              : null,
          children: [
            for (final c in cells)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(c, style: header ? head : cell),
              ),
          ],
        );
    return Table(
      border: TableBorder.all(
        color: theme.colorScheme.outlineVariant,
        width: 0.5,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1.1),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        row(['Phase', 'New/day', 'Algos', 'Mocks/wk'], header: true),
        row(['Weeks 1–2', '8', '1–2', '0–1']),
        row(['Weeks 3–4', '12', '2–4', '1']),
        row(['Week 5+', '15–18', '2–6', '2']),
      ],
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _P extends StatelessWidget {
  const _P(this.text, this.style);
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Text(text, style: style);
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: muted),
          Expanded(child: Text(text, style: muted)),
        ],
      ),
    );
  }
}
