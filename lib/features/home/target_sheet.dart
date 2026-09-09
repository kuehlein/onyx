import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/readiness/prep_goal.dart';
import '../../core/readiness/projection.dart';
import '../../core/readiness/target.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/status_colors.dart';
import '../interview/interview_planner_screen.dart';

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
  bool? _showDims; // null = auto: open until a target has been configured

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
    final muted = theme.colorScheme.onSurfaceVariant;
    // Open the dimension pickers by default until a target has been configured
    // (the controller returns the const fallback only when nothing is set).
    final saved = ref.watch(readinessTargetControllerProvider).asData?.value;
    final unconfigured =
        saved == null || identical(saved, ReadinessTarget.fallback);
    final showDims = _showDims ?? unconfigured;
    // Scheduled interviews (prep goals with at least one dated round) — every
    // round is flagged on the calendar and the loops are listed below it.
    final goals =
        ref.watch(prepGoalsProvider).asData?.value ?? const <PrepGoal>[];
    final scheduled = [
      for (final g in goals)
        if (g.roundDates.isNotEmpty) g,
    ]..sort((a, b) => a.nextRoundDate()!.compareTo(b.nextRoundDate()!));
    // Every round date → the labels of the round(s) on that day (for the
    // calendar flags + their long-press tooltip).
    final roundsByDate = <DateTime, List<String>>{};
    for (final g in goals) {
      for (final r in g.effectiveRounds) {
        final rd = r.date;
        if (rd == null) continue;
        final d = DateTime(rd.year, rd.month, rd.day);
        final who = g.companyName.isEmpty ? '' : '${g.companyName} · ';
        roundsByDate.putIfAbsent(d, () => []).add('$who${r.label}');
      }
    }
    Future<void> openPlanner() async {
      final before = {
        for (final g in (ref.read(prepGoalsProvider).asData?.value ??
            const <PrepGoal>[]))
          g.id
      };
      // Push over the sheet (imperative, not go_router) so saving/cancelling in
      // the planner returns to this still-open sheet rather than dumping to Home.
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const InterviewPlannerScreen()),
      );
      if (!mounted) return;
      final after =
          ref.read(prepGoalsProvider).asData?.value ?? const <PrepGoal>[];
      final added = [
        for (final g in after)
          if (!before.contains(g.id) && g.date != null) g,
      ];
      // Surface a newly-added interview: focus its date so its flag is visible.
      if (added.isNotEmpty) _set(_t.copyWith(interviewDate: added.first.date));
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your target', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              // Target dimensions: a form-field-style panel that expands to the
              // level/company/track pickers. Open by default until configured;
              // AnimatedSize gives it a smooth drawer-like open/close.
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: showDims
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _showDims = false),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 10, 10, 4),
                                child: Row(children: [
                                  Text('Target',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(color: muted)),
                                  const Spacer(),
                                  Icon(Icons.expand_less,
                                      size: 20, color: muted),
                                ]),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                              child: Column(
                                children: [
                                  _ChipGroup<SeniorityLevel>(
                                    label: 'Level',
                                    values: SeniorityLevel.values,
                                    selected: t.level,
                                    labelOf: (v) => v.label,
                                    onSelected: (v) =>
                                        _set(t.copyWith(level: v)),
                                  ),
                                  _ChipGroup<CompanyTier>(
                                    label: 'Company',
                                    values: CompanyTier.values,
                                    selected: t.company,
                                    labelOf: (v) => v.label,
                                    onSelected: (v) =>
                                        _set(t.copyWith(company: v)),
                                  ),
                                  _ChipGroup<Track>(
                                    label: 'Track',
                                    values: Track.values,
                                    selected: t.track,
                                    labelOf: (v) => v.label,
                                    onSelected: (v) =>
                                        _set(t.copyWith(track: v)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : InkWell(
                          onTap: () => setState(() => _showDims = true),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined,
                                    size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Target',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: muted)),
                                      const SizedBox(height: 1),
                                      Text(t.label,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.expand_more, size: 20, color: muted),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              // Forecast readout ABOVE the calendar (the headline outcome).
              _ForecastBlock(chosenDate: date),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Interview date (optional)',
                      style:
                          theme.textTheme.labelLarge?.copyWith(color: muted)),
                  const Spacer(),
                  if (date != null)
                    TextButton(
                      onPressed: () => _set(t.copyWith(interviewDate: null)),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Inline calendar with per-day readiness-zone markers (the OS picker
              // can't colour individual cells). Tapping a day sets the date.
              _ZoneCalendar(
                forecast: forecast,
                selected: date,
                roundsByDate: roundsByDate,
                onSelect: (d) => _set(t.copyWith(interviewDate: d)),
              ),
              const SizedBox(height: 8),
              const _CalendarLegend(),
              const SizedBox(height: 14),
              // Scheduled interviews (flagged above) + the entry to plan one.
              _ScheduledSection(
                goals: scheduled,
                forecast: forecast,
                today: forecast?.today ?? DateTime.now(),
                onAdd: openPlanner,
                onFocus: (d) => _set(t.copyWith(interviewDate: d)),
              ),
              const SizedBox(height: 16),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 66,
            child: Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in values)
                  ChoiceChip(
                    label: Text(labelOf(v)),
                    selected: v == selected,
                    onSelected: (_) => onSelected(v),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The readiness-forecast readout: at your recent pace, the day recall readiness
/// crosses the target, a push/ease range, and — when a date is chosen — the
/// exact pace needed to hit it. Reflects the *saved* aim
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

    final rows = <Widget>[];

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
    required this.roundsByDate,
    required this.onSelect,
  });

  final ReadinessForecast? forecast;
  final DateTime? selected;

  /// Date-only days with a scheduled interview round → the round label(s) on
  /// that day (flagged in the grid, shown in a long-press tooltip).
  final Map<DateTime, List<String>> roundsByDate;
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

  @override
  void didUpdateWidget(covariant _ZoneCalendar old) {
    super.didUpdateWidget(old);
    // When the focused/selected date changes to another month (e.g. tapping a
    // scheduled interview), jump the grid there so its flag is visible.
    final sel = widget.selected;
    if (sel != null && (sel.year != _month.year || sel.month != _month.month)) {
      _month = DateTime(sel.year, sel.month);
    }
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

    const blank = SizedBox(height: 50);
    final cells = <Widget>[
      for (var i = 0; i < grid.leading; i++) blank,
      for (var day = 1; day <= grid.days; day++)
        Builder(builder: (_) {
          final date = DateTime(_month.year, _month.month, day);
          final past = date.isBefore(today);
          return _DayCell(
            day: day,
            past: past,
            selected:
                widget.selected != null && _sameDay(date, widget.selected!),
            zoneColor: _zoneColor(date),
            roundLabels: widget.roundsByDate[date] ?? const [],
            onTap: past ? null : () => widget.onSelect(date),
          );
        }),
    ];
    while (cells.length % 7 != 0) {
      cells.add(blank);
    }
    final weeks = <TableRow>[
      for (var i = 0; i < cells.length; i += 7)
        TableRow(children: cells.sublist(i, i + 7)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: a prominent month title with well-spaced navigation arrows.
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 34),
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
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 34),
              tooltip: 'Next month',
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 6),
        Table(
          border: TableBorder.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            width: 0.8,
            borderRadius: BorderRadius.circular(10),
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: weeks,
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
    required this.zoneColor,
    required this.roundLabels,
    required this.onTap,
  });

  final int day;
  final bool past;
  final bool selected;
  final Color? zoneColor;

  /// Round label(s) scheduled on this day (empty = none). Non-empty → the cell
  /// carries an interview flag + a long-press tooltip naming the round(s).
  final List<String> roundLabels;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasInterview = roundLabels.isNotEmpty;
    final showZone = zoneColor != null && !past;
    // The zone is a soft cell BACKGROUND (a heatmap now that cells are outlined).
    // Selected = solid primary; the number stays neutral to read.
    final cellBg = selected
        ? theme.colorScheme.primary
        : showZone
            ? zoneColor!.withValues(alpha: 0.22)
            : null;
    final numberColor = past
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface;
    final cell = InkWell(
      onTap: onTap,
      canRequestFocus: false,
      focusColor: Colors.transparent,
      child: SizedBox(
        height: 50,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                alignment: Alignment.center,
                color: cellBg,
                child: Text('$day',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: numberColor,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400)),
              ),
            ),
            // A scheduled interview on this day — a bold accent bar along the
            // bottom of the cell, clearly distinct from the zone background.
            if (hasInterview)
              Positioned(
                left: 7,
                right: 7,
                bottom: 5,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (!hasInterview) return cell;
    return Tooltip(
      message: roundLabels.join('\n'),
      triggerMode: TooltipTriggerMode.longPress,
      preferBelow: false,
      child: cell,
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
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.55),
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
        item(statusGood, 'Ready at your pace'),
        item(statusWarn, 'Needs a faster pace'),
        item(statusBad, 'Too soon to be ready'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 5),
            Text('interview',
                style: theme.textTheme.labelSmall?.copyWith(color: muted)),
          ],
        ),
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

/// Scheduled interviews listed under the calendar. Each interview is a loop of
/// rounds (screen, system-design, …), each with its own date, pace status, and
/// outcome; rounds can be added/edited/removed inline. The section header
/// carries the 'Add' entry (plan a new interview); the list shows the 3 soonest
/// interviews with a 'show all' expander so many never blow up the sheet.
class _ScheduledSection extends ConsumerStatefulWidget {
  const _ScheduledSection({
    required this.goals,
    required this.forecast,
    required this.today,
    required this.onAdd,
    required this.onFocus,
  });

  final List<PrepGoal> goals; // sorted by soonest round first
  final ReadinessForecast? forecast;
  final DateTime today;
  final VoidCallback onAdd;
  final void Function(DateTime) onFocus;

  @override
  ConsumerState<_ScheduledSection> createState() => _ScheduledSectionState();
}

class _ScheduledSectionState extends ConsumerState<_ScheduledSection> {
  static const _cap = 3;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final goals = widget.goals;
    final capped = goals.length > _cap;
    final visible = (_showAll || !capped) ? goals : goals.take(_cap).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with the add action on the right.
        Row(
          children: [
            Text('Interviews',
                style: theme.textTheme.labelLarge?.copyWith(color: muted)),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ],
        ),
        if (goals.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Text('None scheduled — add one to flag it on the calendar.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ),
        for (final g in visible) _interviewTile(context, g),
        if (capped)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(_showAll ? 'Show fewer' : 'Show all ${goals.length}'),
            ),
          ),
      ],
    );
  }

  /// One interview: its label + an overflow menu, then its rounds, then a
  /// compact '+ round' entry.
  Widget _interviewTile(BuildContext context, PrepGoal g) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final rounds = g.effectiveRounds;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
            child: Row(
              children: [
                Icon(Icons.flag, size: 15, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    g.companyName.isEmpty ? g.label : g.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Interview options',
                  onPressed: () => _interviewMenu(context, g),
                ),
              ],
            ),
          ),
          for (final r in rounds) _roundRow(context, g, r),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addRound(context, g),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add round'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.fromLTRB(10, 0, 12, 2),
                foregroundColor: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundRow(BuildContext context, PrepGoal g, InterviewRound r) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final d = r.date;
    final sub = d == null ? 'No date yet' : '${_fmtDate(d)} · ${_daysAway(d)}';
    return InkWell(
      onTap: d == null ? null : () => widget.onFocus(d),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            _outcomeDot(context, r.outcome),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium),
                  Text(sub,
                      style:
                          theme.textTheme.labelSmall?.copyWith(color: muted)),
                ],
              ),
            ),
            if (d != null && r.outcome == GoalOutcome.pending)
              _statusChip(context, d),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 16),
              visualDensity: VisualDensity.compact,
              tooltip: 'Round options',
              onPressed: () => _roundMenu(context, g, r),
            ),
          ],
        ),
      ),
    );
  }

  /// A small dot conveying the round's outcome (pending/passed/failed).
  Widget _outcomeDot(BuildContext context, GoalOutcome o) {
    final (IconData icon, Color color) = switch (o) {
      GoalOutcome.passed => (Icons.check_circle, statusGood),
      GoalOutcome.failed => (Icons.cancel, statusBad),
      GoalOutcome.pending => (
          Icons.radio_button_unchecked,
          Theme.of(context).colorScheme.primary
        ),
    };
    return Icon(icon, size: 15, color: color);
  }

  Future<void> _interviewMenu(BuildContext context, PrepGoal g) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add round'),
              onTap: () => Navigator.pop(ctx, 'add'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove interview'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'add') {
      await _addRound(context, g);
    } else if (choice == 'remove') {
      await ref.read(prepGoalsProvider.notifier).remove(g.id);
    }
  }

  Future<void> _roundMenu(
      BuildContext context, PrepGoal g, InterviewRound r) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit round'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove round'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'edit') {
      final edited =
          await showRoundDialog(context, today: widget.today, existing: r);
      if (edited != null) await _saveRound(g, edited);
    } else if (choice == 'remove') {
      await _removeRound(g, r);
    }
  }

  Future<void> _addRound(BuildContext context, PrepGoal g) async {
    final n = g.effectiveRounds.length + 1;
    final draft = InterviewRound(
      id: '${g.id}-r$n-${widget.today.millisecondsSinceEpoch}',
      number: n,
      type: n == 1 ? InterviewRoundType.screen : InterviewRoundType.onsite,
    );
    final added =
        await showRoundDialog(context, today: widget.today, existing: draft);
    if (added != null) await _saveRound(g, added);
  }

  Future<void> _saveRound(PrepGoal g, InterviewRound round) async {
    final rounds = [...g.effectiveRounds];
    final i = rounds.indexWhere((r) => r.id == round.id);
    if (i >= 0) {
      rounds[i] = round;
    } else {
      rounds.add(round);
    }
    await ref.read(prepGoalsProvider.notifier).upsert(_synced(g, rounds));
  }

  Future<void> _removeRound(PrepGoal g, InterviewRound round) async {
    final rounds = [...g.effectiveRounds]..removeWhere((r) => r.id == round.id);
    if (rounds.isEmpty) {
      // A loop with no rounds isn't an interview any more — drop it.
      await ref.read(prepGoalsProvider.notifier).remove(g.id);
      return;
    }
    await ref.read(prepGoalsProvider.notifier).upsert(_synced(g, rounds));
  }

  /// Re-order rounds by date (dated ascending, undated last), renumber 1..n, and
  /// mirror the soonest dated round into the denormalized [PrepGoal.date] that
  /// legacy targeting still reads.
  PrepGoal _synced(PrepGoal g, List<InterviewRound> rounds) {
    final sorted = [...rounds]..sort((a, b) {
        if (a.date == null && b.date == null) {
          return a.number.compareTo(b.number);
        }
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return a.date!.compareTo(b.date!);
      });
    final renum = [
      for (var i = 0; i < sorted.length; i++) sorted[i].copyWith(number: i + 1),
    ];
    DateTime? earliest;
    for (final r in renum) {
      final d = r.date;
      if (d != null && (earliest == null || d.isBefore(earliest))) earliest = d;
    }
    return g.copyWith(rounds: renum, date: earliest);
  }

  String _daysAway(DateTime d) {
    final days =
        DateTime(d.year, d.month, d.day).difference(widget.today).inDays;
    if (days < 0) return 'past';
    if (days == 0) return 'today';
    if (days < 14) return 'in $days days';
    return 'in ${(days / 7).round()} wks';
  }

  Widget _statusChip(BuildContext context, DateTime d) {
    final f = widget.forecast;
    if (f == null) return const SizedBox.shrink();
    final days =
        DateTime(d.year, d.month, d.day).difference(widget.today).inDays;
    final String text;
    final Color color;
    if (f.alreadyReady) {
      text = 'ready';
      color = statusGood;
    } else {
      final req = f.requiredPerDayFor(days);
      if (req == null) {
        text = 'too soon';
        color = statusBad;
      } else if (req <= f.currentPerDay) {
        text = 'on track';
        color = statusGood;
      } else {
        text = '~$req/day';
        color = statusWarn;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

/// A dialog to add or edit one interview round: its type, date (optional), and
/// outcome. Returns the edited round, or null on cancel.
Future<InterviewRound?> showRoundDialog(
  BuildContext context, {
  required DateTime today,
  required InterviewRound existing,
}) =>
    showDialog<InterviewRound>(
      context: context,
      builder: (_) => _RoundDialog(today: today, existing: existing),
    );

class _RoundDialog extends StatefulWidget {
  const _RoundDialog({required this.today, required this.existing});

  final DateTime today;
  final InterviewRound existing;

  @override
  State<_RoundDialog> createState() => _RoundDialogState();
}

class _RoundDialogState extends State<_RoundDialog> {
  late InterviewRoundType _type = widget.existing.type;
  late DateTime? _date = widget.existing.date;
  late GoalOutcome _outcome = widget.existing.outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AlertDialog(
      title: Text('Round ${widget.existing.number}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Type',
              style: theme.textTheme.labelMedium?.copyWith(color: muted)),
          const SizedBox(height: 4),
          DropdownButtonFormField<InterviewRoundType>(
            initialValue: _type,
            isExpanded: true,
            items: [
              for (final t in InterviewRoundType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 14),
          Text('Date',
              style: theme.textTheme.labelMedium?.copyWith(color: muted)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(_date == null ? 'Set a date' : _fmtDate(_date!)),
                  onPressed: _pickDate,
                ),
              ),
              if (_date != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Clear date',
                  onPressed: () => setState(() => _date = null),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Outcome',
              style: theme.textTheme.labelMedium?.copyWith(color: muted)),
          const SizedBox(height: 4),
          SegmentedButton<GoalOutcome>(
            segments: const [
              ButtonSegment(value: GoalOutcome.pending, label: Text('Pending')),
              ButtonSegment(value: GoalOutcome.passed, label: Text('Passed')),
              ButtonSegment(value: GoalOutcome.failed, label: Text('Failed')),
            ],
            selected: {_outcome},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _outcome = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.existing
                .copyWith(type: _type, date: _date, outcome: _outcome),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final base =
        DateTime(widget.today.year, widget.today.month, widget.today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? base.add(const Duration(days: 14)),
      firstDate: base,
      lastDate: base.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }
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
