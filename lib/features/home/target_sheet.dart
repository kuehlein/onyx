import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/readiness/projection.dart';
import '../../core/readiness/target.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/status_colors.dart';

/// Opens the target-selection sheet. Lets the user pick the interview they're
/// aiming at (level × company × track) and an optional date; both re-shape the
/// readiness roll-up and drive the pace readout.
Future<void> showTargetSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // Open tall (up to 92% of the screen) so the calendar + forecast aren't
      // clipped below the fold; the body scrolls within if it's still taller.
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      builder: (_) => const _TargetSheet(),
    );

class _TargetSheet extends ConsumerStatefulWidget {
  const _TargetSheet();

  @override
  ConsumerState<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends ConsumerState<_TargetSheet> {
  ReadinessTarget? _draft;

  ReadinessTarget get _t =>
      _draft ??
      ref.read(readinessTargetControllerProvider).asData?.value ??
      ReadinessTarget.fallback;

  void _set(ReadinessTarget next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = _t;
    final date = t.interviewDate;
    final forecast = ref.watch(readinessForecastProvider).asData?.value;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your target', style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                'What are you preparing for? This weights the domains that matter '
                'and sets the bar.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _ChipGroup<SeniorityLevel>(
                label: 'Level',
                values: SeniorityLevel.values,
                selected: t.level,
                labelOf: (v) => v.label,
                onSelected: (v) => _set(t.copyWith(level: v)),
              ),
              _ChipGroup<CompanyTier>(
                label: 'Company',
                values: CompanyTier.values,
                selected: t.company,
                labelOf: (v) => v.label,
                onSelected: (v) => _set(t.copyWith(company: v)),
              ),
              _ChipGroup<Track>(
                label: 'Track',
                values: Track.values,
                selected: t.track,
                labelOf: (v) => v.label,
                onSelected: (v) => _set(t.copyWith(track: v)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Interview date (optional)',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  if (date != null)
                    TextButton(
                      onPressed: () => _set(t.copyWith(interviewDate: null)),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Inline calendar with per-day readiness-zone underlines (the OS
              // picker can't colour individual cells). Tapping a day sets the date.
              _ZoneCalendar(
                forecast: forecast,
                selected: date,
                onSelect: (d) => _set(t.copyWith(interviewDate: d)),
              ),
              const SizedBox(height: 8),
              const _CalendarLegend(),
              const SizedBox(height: 14),
              // Ready-date readout: on-track date, push/ease range, and the pace
              // needed to hit the chosen date.
              _ForecastBlock(chosenDate: date),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await ref
                        .read(readinessTargetControllerProvider.notifier)
                        .save(t);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Save target'),
                ),
              ),
              const SizedBox(height: 4),
              // The base aim above is your general target; a specific interview
              // (company + date) layers on top via the AI planner.
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/plan-interview');
                  },
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('Plan for a specific interview'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(labelOf(v)),
                  selected: v == selected,
                  onSelected: (_) => onSelected(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The readiness-forecast readout: at your recent pace, the day recall readiness
/// crosses the target, a push/ease range, a colour-zoned timeline, and — when a
/// date is chosen — the exact pace needed to hit it. Reflects the *saved* aim
/// (the projection is a forward simulation, too heavy to recompute on every
/// draft chip tap); the date feedback uses the draft date.
class _ForecastBlock extends ConsumerWidget {
  const _ForecastBlock({this.chosenDate});

  final DateTime? chosenDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final async = ref.watch(readinessForecastProvider);

    Widget shell(Widget child) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        );

    if (async.isLoading) {
      return shell(Text('Estimating your timeline…',
          style: theme.textTheme.bodySmall?.copyWith(color: muted)));
    }
    final f = async.asData?.value;
    if (f == null) return const SizedBox.shrink();

    final rows = <Widget>[
      Row(children: [
        Icon(Icons.trending_up, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text('Readiness forecast', style: theme.textTheme.labelLarge),
      ]),
      const SizedBox(height: 6),
    ];

    if (f.alreadyReady) {
      rows.add(Text('You’re already at your target for this aim.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: statusGood, fontWeight: FontWeight.w600)));
    } else {
      final curDate = f.currentReadyDate;
      if (curDate == null) {
        final earliest = f.earliestReadyDate;
        rows.add(Text(
            'At ~${f.currentPerDay} new/day you won’t hit your target within a '
            'year. Even at ~${f.maxSampledPerDay}/day the earliest is '
            '${earliest == null ? "over a year out" : _fmtDate(earliest)}.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted)));
      } else {
        rows.add(RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface),
            children: [
              TextSpan(text: 'At ~${f.currentPerDay} new/day, ready by '),
              TextSpan(
                  text: _fmtDate(curDate),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: '.'),
            ],
          ),
        ));
        final push = f.pushReadyDate;
        final chill = f.chillReadyDate;
        rows.add(const SizedBox(height: 4));
        rows.add(Text(
          'Push ~${f.pushPerDay}/day → ${push == null ? '1yr+' : _fmtDate(push)}'
          '    ·    '
          'Ease ~${f.chillPerDay}/day → ${chill == null ? '1yr+' : _fmtDate(chill)}',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ));
      }

      if (chosenDate != null) {
        final days = chosenDate!.difference(f.today).inDays;
        final req = f.requiredPerDayFor(days);
        rows.add(const SizedBox(height: 8));
        if (req == null) {
          final earliest = f.earliestReadyDate;
          rows.add(_note(
              Icons.block,
              'Even at ~${f.maxSampledPerDay}/day you can’t be ready by '
              '${_fmtDate(chosenDate!)} — earliest is '
              '${earliest == null ? "over a year out" : _fmtDate(earliest)}.',
              statusBad,
              theme));
        } else if (req <= f.currentPerDay) {
          rows.add(_note(
              Icons.check_circle_outline,
              'On track — your pace reaches ${_fmtDate(chosenDate!)}.',
              statusGood,
              theme));
        } else {
          rows.add(_note(
              Icons.bolt,
              'To be ready by ${_fmtDate(chosenDate!)}, study ~$req/day '
              '(up from ~${f.currentPerDay}).',
              statusWarn,
              theme));
        }
      }
    }

    return shell(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    ));
  }

  Widget _note(IconData icon, String text, Color color, ThemeData theme) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodySmall?.copyWith(color: color)),
          ),
        ],
      );
}

/// An inline month calendar whose day cells are **underlined by readiness zone**:
/// green = comfortable at your pace, amber = reachable but needs a faster pace,
/// red = not reachable even at the fastest sampled pace. Tapping a day sets the
/// interview date. Replaces the OS date picker (whose theme colours are per-state,
/// not per-date, so it can't zone-colour cells) — plain widgets, no runtime jank.
class _ZoneCalendar extends StatefulWidget {
  const _ZoneCalendar({
    required this.forecast,
    required this.selected,
    required this.onSelect,
  });

  final ReadinessForecast? forecast;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_ZoneCalendar> createState() => _ZoneCalendarState();
}

class _ZoneCalendarState extends State<_ZoneCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    // Open on the month the user most likely wants to pick in: their current
    // date if any, else the on-track month, else the earliest reachable month —
    // so we don't land on a month with nothing worth selecting.
    final anchor = widget.selected ??
        widget.forecast?.currentReadyDate ??
        widget.forecast?.earliestReadyDate ??
        _today.add(const Duration(days: 30));
    final today = _today;
    final curMonth = DateTime(today.year, today.month);
    var m = DateTime(anchor.year, anchor.month);
    if (m.isBefore(curMonth)) m = curMonth; // never start before this month
    _month = m;
  }

  DateTime get _today {
    final t = widget.forecast?.today ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color? _zoneColor(DateTime d) {
    final f = widget.forecast;
    if (f == null || f.alreadyReady) return null;
    final off = d.difference(_today).inDays;
    if (off < 0) return null;
    final earliest = f.earliestReadyDay;
    final current = f.currentReadyDay;
    if (current != null && off >= current) return statusGood;
    if (earliest != null && off >= earliest) return statusWarn;
    if (earliest == null && current == null) return null;
    return statusBad;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final loc = MaterialLocalizations.of(context);
    final firstDow = loc.firstDayOfWeekIndex; // 0=Sun … 6=Sat
    final today = _today;
    final grid = monthGrid(_month.year, _month.month, firstDayOfWeek: firstDow);
    final canPrev = _month.isAfter(DateTime(today.year, today.month));

    final cells = <Widget>[
      for (var i = 0; i < grid.leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= grid.days; day++)
        Builder(builder: (_) {
          final date = DateTime(_month.year, _month.month, day);
          final past = date.isBefore(today);
          return _DayCell(
            day: day,
            past: past,
            selected:
                widget.selected != null && _sameDay(date, widget.selected!),
            isToday: _sameDay(date, today),
            zoneColor: _zoneColor(date),
            onTap: past ? null : () => widget.onSelect(date),
          );
        }),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: a prominent month title with well-spaced navigation arrows.
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
              onPressed: canPrev
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1))
                  : null,
            ),
            Expanded(
              child: Center(
                child: Text('${_monthName(_month.month)} ${_month.year}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(loc.narrowWeekdays[(firstDow + i) % 7],
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: muted, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          children: cells,
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.past,
    required this.selected,
    required this.isToday,
    required this.zoneColor,
    required this.onTap,
  });

  final int day;
  final bool past;
  final bool selected;
  final bool isToday;
  final Color? zoneColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = past
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface;
    // Zone shown as a soft cell wash (a heatmap) — clearly visible, not a
    // hair-thin underline. Selected wins with the primary fill; the wash fades
    // on past days.
    final bg = selected
        ? theme.colorScheme.primary
        : zoneColor?.withValues(alpha: past ? 0.08 : 0.26);
    return Material(
      color: bg ?? Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isToday && !selected
                ? Border.all(color: theme.colorScheme.primary, width: 1.4)
                : null,
          ),
          child: Text('$day',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight:
                      selected || isToday ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }
}

/// Legend for the zone-coloured calendar cells.
class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.26),
                    borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(color: muted)),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(statusGood, 'Ready / comfortable'),
        item(statusWarn, 'Needs a faster pace'),
        item(statusBad, 'Not reachable yet'),
      ],
    );
  }
}

/// The month-grid layout for a locale whose week starts on [firstDayOfWeek]
/// (0=Sunday … 6=Saturday, matching `MaterialLocalizations.firstDayOfWeekIndex`):
/// how many leading blank cells precede day 1, and how many days the month has.
/// This is the only date arithmetic in the calendar — public and unit-tested.
/// Relies entirely on Dart's `DateTime` normalization (leap years, month
/// rollover); no hand-rolled math.
({int leading, int days}) monthGrid(int year, int month,
    {int firstDayOfWeek = 0}) {
  final firstWeekday = DateTime(year, month, 1).weekday % 7; // 0=Sun … 6=Sat
  return (
    leading: (firstWeekday - firstDayOfWeek + 7) % 7,
    days: DateTime(year, month + 1, 0).day,
  );
}

String _monthName(int m) => const [
      'January', 'February', 'March', 'April', 'May', 'June', //
      'July', 'August', 'September', 'October', 'November', 'December'
    ][m - 1];

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
