import 'package:flutter/material.dart';

import '../../shared/design/onyx_design.dart';
import '../../shared/widgets/sheet_header.dart';

/// A plain-language reference on study load — what the daily levers mean, a
/// suggested start-slow-then-ramp plan, and the one guardrail that keeps it
/// sustainable. Opened from Settings (near the load controls), not shown on
/// Home; the coach carries the dynamic, personal version.
Future<void> showStudyLoadHelp(BuildContext context) {
  return showOnyxSheet<void>(
    context,
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
      child: Column(
        children: [
          const SheetHeader(
            title: 'How much should I study?',
            subtitle: 'Ambitious but sustainable — start light and ramp up.',
            divider: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Dim.space5, Dim.space3, Dim.space5, Dim.space6),
              children: [
                const _H('What you set'),
                _P(
                    'Just two things — the app works out the rest of the day for '
                    'you:',
                    muted),
                const SizedBox(height: Dim.space2),
                const _Bullet(
                    'Daily study time — the one honest lever: how long you want '
                    'to study each day. The app eases you in and ramps up '
                    'automatically as the habit holds.'),
                const _Bullet(
                    'Each deck’s share — if you’re studying more than one thing, '
                    'how to split the day between them.'),
                const SizedBox(height: Dim.space5),
                const _H('What the app decides for you'),
                _P(
                    'From your daily time, your aims and any deadlines, and how '
                    'your recall is going, the app fills each day with the right '
                    'mix — clearing what’s due to review first, then new material '
                    'and practice, weighted toward whatever’s most urgent. You '
                    'never hand-tune how many of each.',
                    muted),
                const SizedBox(height: Dim.space3),
                _P(
                    'New material has an automatic ceiling. Taking on too much at '
                    'once spikes your future review load and hurts recall, so the '
                    'app holds new material to a sustainable rate — and eases it '
                    'further on its own when you fall behind.',
                    muted),
                const SizedBox(height: Dim.space5),
                const _H('The start-slow ramp'),
                _P(
                    'The day starts short and grows to your full budget over about '
                    'a week of steady days — a missed day barely dents it:',
                    muted),
                const SizedBox(height: Dim.space3),
                const _RampTable(),
                const SizedBox(height: Dim.space5),
                const _H('The one guardrail'),
                _P(
                    'Let recent review success be your gauge. Aim for ~90%. If it '
                    'holds and reviews aren’t piling up, you have room — nudge your '
                    'daily time up. If it dips below ~80% or a backlog builds, the '
                    'app automatically eases new material; clear your reviews '
                    'first, and trim your daily time if it keeps feeling heavy. '
                    'Chasing higher than ~90% isn’t worth it; it explodes the '
                    'workload for little gain.',
                    muted),
                const SizedBox(height: Dim.space4),
                _P(
                    'The coach on Home watches these signals and lets you know '
                    'when there’s room or strain — but it never changes your daily '
                    'time on its own; that stays yours.',
                    muted),
              ],
            ),
          ),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: Dim.space2, vertical: Dim.space2),
                child: Text(c, style: header ? head : cell),
              ),
          ],
        );
    return Table(
      border: TableBorder.all(
        color: theme.colorScheme.outlineVariant,
        width: 0.5,
        borderRadius: Dim.brChip,
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FlexColumnWidth(1.6),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        row(['Phase', 'Daily study time'], header: true),
        row(['Days 1–2', '~90 min (ease-in)']),
        row(['Building', 'ramping up']),
        row(['~1 week+', 'your full budget']),
      ],
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Dim.space2),
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
      padding: const EdgeInsets.only(bottom: Dim.space2),
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
