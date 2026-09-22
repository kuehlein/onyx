import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/goal/study_goal.dart';
import '../../core/readiness/projection.dart';
import '../../core/readiness/target.dart';
import '../../core/template/active_template.dart';
import '../../core/template/deck_template.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/study_goals.dart';
import '../../shared/providers/template.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/widgets/sheet_header.dart';
import '../interview/interview_card.dart';
import '../interview/interview_planner_sheet.dart';

// Max width of the target sheet — a touch wider than the chat sheets since it
// holds a calendar, but no wider than it needs to be.
const _sheetMaxWidth = 560.0;

// Horizontal inset kept from the screen edges so the sheet reads as a layered
// card rather than a full-width page on a narrow window.
const _sheetEdgeInset = 80.0;

/// The date-field label for [vocab] — the SWE reference (`assessmentNoun:
/// 'interview'`) reads "Interview date (optional)" byte-identically; a subject
/// with no assessment reads "Target date (optional)". Pure → unit-tested (#88/G7c).
@visibleForTesting
String targetDateLabel(Vocabulary vocab) =>
    '${vocab.assessmentNounTitle ?? 'Target'} date (optional)';

/// Opens the target-selection sheet. Lets the user pick the target they're aiming
/// at (level × context × track) and an optional date; both re-shape the readiness
/// roll-up and drive the pace readout. Assessment subjects (SWE) additionally see
/// the scheduled-interviews loop; all copy reads from the goal's [Vocabulary].
Future<void> showTargetSheet(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return showOnyxSheet<void>(
    context,
    // Open tall (up to 92% of the screen) so the calendar + forecast aren't
    // clipped below the fold; the body scrolls within if it's still taller.
    // Inset from the edges so it reads as a layered card (like the shorter
    // sheets), not a full-width page — and capped so it doesn't balloon on a
    // wide (desktop) window.
    constraints: BoxConstraints(
      maxHeight: size.height * 0.92,
      maxWidth: size.width - _sheetEdgeInset < _sheetMaxWidth
          ? size.width - _sheetEdgeInset
          : _sheetMaxWidth,
    ),
    builder: (_) => const _TargetSheet(),
  );
}

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
      ref.read(activeTargetProvider).asData?.value ??
      ReadinessTarget.fallback;

  void _set(ReadinessTarget next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = _t;
    final date = t.interviewDate;
    // The forecast follows the DRAFT dims so the calendar + readout update the
    // instant you change level/company/track (memoised per role, so flipping
    // between a few roles is cached).
    final dims = (level: t.level, company: t.company, track: t.track);
    final forecast =
        ref.watch(readinessForecastForProvider(dims)).asData?.value;
    final today = ref.watch(clockProvider).asData?.value.today() ??
        forecast?.today ??
        DateTime.now();
    final muted = theme.colorScheme.onSurfaceVariant;
    // Open the dimension pickers by default until a target has been configured
    // (the goal's slots are null until the user sets one; activeTarget always
    // fills fallbacks, so it can't be the signal).
    final saved = ref.watch(activeTargetProvider).asData?.value;
    final unconfigured = saved == null ||
        ref.watch(activeTargetIsSetProvider).asData?.value != true;
    final showDims = _showDims ?? unconfigured;
    // The active study goal owns the interviews (Phase B) + the level/track/
    // deadline slots the Save maps into.
    final goal = ref.watch(activeStudyGoalProvider).asData?.value;
    // The active goal's assessment terminology — SWE reads "interview" (chrome
    // shown); a neutral subject reads neutrally and hides the interview loop (G7).
    final goalSubject = ref.watch(activeGoalTemplateProvider).asData?.value;
    final vocab = goalSubject?.vocabulary ?? activeTemplate.vocabulary;
    final interviews = goal?.interviews ?? const <Aim>[];
    // Active interviews with an upcoming round — ended/archived loops drop out
    // of the target list + calendar (they live on the Interviews screen).
    final scheduled = goal == null
        ? const <Aim>[]
        : ([
            for (final iv in interviews)
              if (!iv.status.isEnded && _hasUpcomingRound(iv, goal, today)) iv,
          ]..sort((a, b) => a
            .nextRoundDate(goal.id, goal.deadline, today)!
            .compareTo(b.nextRoundDate(goal.id, goal.deadline, today)!)));
    // Every round date → the labels of the round(s) on that day (for the
    // calendar flags + their long-press tooltip).
    final roundsByDate = <DateTime, List<String>>{};
    if (goal != null) {
      for (final iv in scheduled) {
        for (final r in iv.effectiveRounds(goal.id, goal.deadline)) {
          final rd = r.date;
          if (rd == null) continue;
          final d = DateTime(rd.year, rd.month, rd.day);
          final who = iv.companyName.isEmpty ? '' : '${iv.companyName} · ';
          roundsByDate.putIfAbsent(d, () => []).add('$who${r.label}');
        }
      }
    }
    Future<void> openPlanner() async {
      // A slide-up planner (consistent with the other AI chats). The accepted
      // plan already writes its round + date onto the active goal, so refreshing
      // the sheet picks it up; focus the calendar on its date if it set one.
      final added = await showInterviewPlannerSheet(context);
      if (!mounted) return;
      final d = added?.nextRoundDate(goal?.id ?? '', null);
      if (d != null) {
        _set(_t.copyWith(interviewDate: d));
      }
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeader(title: 'Your target'),
          SheetScrollBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Target dimensions: a form-field-style panel that expands to
                // the level/company/track pickers. Open by default until
                // configured; AnimatedSize gives a drawer-like open/close.
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: Dim.brCard,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AnimatedSize(
                    duration: context.motionBase,
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: showDims
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _showDims = false),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(Dim.space4,
                                      Dim.space3, Dim.space3, Dim.space1),
                                  child: Row(children: [
                                    Text('Target',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(color: muted)),
                                    const Spacer(),
                                    Icon(Icons.expand_less,
                                        size: Dim.iconMd, color: muted),
                                  ]),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    Dim.space4, 0, Dim.space4, Dim.space2),
                                child: Column(
                                  children: [
                                    _ChipGroup<LevelValue>(
                                      label: 'Level',
                                      values: activeTemplate.target.levels,
                                      selected: activeTemplate.target
                                          .levelById(t.levelId),
                                      labelOf: (v) => v.label,
                                      onSelected: (v) =>
                                          _set(t.copyWith(levelId: v.id)),
                                    ),
                                    // NOTE (G7 defer): the axis LABELS
                                    // (Level/Company/Track) are still the SWE
                                    // names — a non-SWE assessment subject would
                                    // read "Company" for its context axis.
                                    // Generalizing them needs per-axis labels on
                                    // TargetSpec/Vocabulary (a later G7c-tail);
                                    // the chip VALUES already come from config.
                                    _ChipGroup<ContextValue>(
                                      label: 'Company',
                                      values: activeTemplate.target.contexts,
                                      selected: activeTemplate.target
                                          .contextById(t.contextId),
                                      labelOf: (v) => v.label,
                                      onSelected: (v) =>
                                          _set(t.copyWith(contextId: v.id)),
                                    ),
                                    _ChipGroup<TrackValue>(
                                      label: 'Track',
                                      values: activeTemplate.target.tracks,
                                      selected: activeTemplate.target
                                          .trackById(t.trackId),
                                      labelOf: (v) => v.label,
                                      onSelected: (v) =>
                                          _set(t.copyWith(trackId: v.id)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : InkWell(
                            onTap: () => setState(() => _showDims = true),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(Dim.space4,
                                  Dim.space3, Dim.space3, Dim.space3),
                              child: Row(
                                children: [
                                  Icon(Icons.flag_outlined,
                                      size: Dim.iconMd,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: Dim.space3),
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
                                                    fontWeight:
                                                        FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.expand_more,
                                      size: Dim.iconMd, color: muted),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: Dim.space3),
                // Forecast readout ABOVE the calendar (the headline outcome).
                _ForecastBlock(chosenDate: date, dims: dims),
                const SizedBox(height: Dim.space4),
                Row(
                  children: [
                    Text(targetDateLabel(vocab),
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
                const SizedBox(height: Dim.space1),
                // Inline calendar with per-day readiness-zone markers (the OS picker
                // can't color individual cells). Tapping a day sets the date.
                _ZoneCalendar(
                  forecast: forecast,
                  selected: date,
                  roundsByDate: roundsByDate,
                  onSelect: (d) => _set(t.copyWith(interviewDate: d)),
                ),
                const SizedBox(height: Dim.space2),
                _CalendarLegend(assessmentNoun: vocab.assessmentNoun),
                const SizedBox(height: Dim.space3),
                // Scheduled interviews (flagged above) + the entry to plan one —
                // only for a subject that has the interview loop (G7).
                if (goal != null && vocab.hasAssessment)
                  _ScheduledSection(
                    interviews: scheduled,
                    goal: goal,
                    today: today,
                    onAdd: openPlanner,
                  ),
                const SizedBox(height: Dim.space3),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: goal == null
                        ? null
                        : () async {
                            // Map the draft target's slots onto the active goal
                            // (Phase B cutover — the goal persists to
                            // study-goals.json, bypassing the legacy bridge).
                            await ref.read(studyGoalsProvider.notifier).upsert(
                                  goal.copyWith(
                                    levelId: t.levelId,
                                    contextId: t.contextId,
                                    trackId: t.trackId,
                                    deadline: t.interviewDate,
                                  ),
                                );
                            if (context.mounted) Navigator.of(context).pop();
                          },
                    child: const Text('Save target'),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  // Fixed label column so the Level/Company/Track chip rows align.
  static const _labelWidth = 66.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Dim.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: Dim.space2,
              runSpacing: Dim.space2,
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
  const _ForecastBlock({required this.dims, this.chosenDate});

  final ForecastDims dims;
  final DateTime? chosenDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final async = ref.watch(readinessForecastForProvider(dims));

    Widget shell(Widget child) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Dim.space3),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: Dim.brCard,
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
          style: theme.textTheme.bodyMedium?.copyWith(
              color: StatusColor.good, fontWeight: FontWeight.w600)));
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
        rows.add(const SizedBox(height: Dim.space1));
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
        rows.add(const SizedBox(height: Dim.space2));
        if (req == null) {
          final earliest = f.earliestReadyDate;
          rows.add(_note(
              Icons.block,
              'Even at ~${f.maxSampledPerDay}/day you can’t be ready by '
              '${_fmtDate(chosenDate!)} — earliest is '
              '${earliest == null ? "over a year out" : _fmtDate(earliest)}.',
              StatusColor.bad,
              theme));
        } else if (req <= f.currentPerDay) {
          rows.add(_note(
              Icons.check_circle_outline,
              'On track — your pace reaches ${_fmtDate(chosenDate!)}.',
              StatusColor.good,
              theme));
        } else {
          rows.add(_note(
              Icons.bolt,
              'To be ready by ${_fmtDate(chosenDate!)}, study ~$req/day '
              '(up from ~${f.currentPerDay}).',
              StatusColor.warn,
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
          Icon(icon, size: Dim.iconSm, color: color),
          const SizedBox(width: Dim.space2),
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
/// interview date. Replaces the OS date picker (whose theme colors are per-state,
/// not per-date, so it can't zone-color cells) — plain widgets, no runtime jank.
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
  // Height of a single day cell (also used for the leading/trailing blanks).
  static const _cellHeight = 50.0;

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
    if (current != null && off >= current) return StatusColor.good;
    if (earliest != null && off >= earliest) return StatusColor.warn;
    if (earliest == null && current == null) return null;
    return StatusColor.bad;
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

    const blank = SizedBox(height: _cellHeight);
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
              iconSize: Dim.iconMd,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
              iconSize: Dim.iconMd,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: 'Next month',
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: Dim.space2),
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
        const SizedBox(height: Dim.space2),
        Table(
          border: TableBorder.all(
            color: theme.colorScheme.outlineVariant
                .withValues(alpha: Dim.emphasisMed),
            width: 0.8,
            borderRadius: Dim.brCard,
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

  // Day-cell height (matches the calendar's blank cells).
  static const _cellHeight = 50.0;

  // Subtle rounding on the accent interview bar along the cell's bottom.
  static const _interviewBarRadius = 2.0;

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
            ? zoneColor!.withValues(alpha: Dim.fill)
            : null;
    final numberColor = past
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: Dim.hairline)
        : selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface;
    final cell = InkWell(
      onTap: onTap,
      canRequestFocus: false,
      focusColor: Colors.transparent,
      child: SizedBox(
        height: _cellHeight,
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
                left: Dim.space2,
                right: Dim.space2,
                bottom: Dim.space1,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(_interviewBarRadius),
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

/// Legend for the zone-colored calendar cells.
class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({this.assessmentNoun});

  /// The assessment-event noun (e.g. "interview") labelling the scheduled-round
  /// swatch, or null to omit that swatch for a subject with no assessment (G7).
  final String? assessmentNoun;

  // Subtle rounding on the small legend swatches (zone squares + interview bar).
  static const _swatchRadius = 3.0;
  static const _barRadius = 2.0;

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
                    color: c.withValues(alpha: Dim.emphasisMed),
                    borderRadius: BorderRadius.circular(_swatchRadius))),
            const SizedBox(width: Dim.space1),
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(color: muted)),
          ],
        );
    return Wrap(
      spacing: Dim.space3,
      runSpacing: Dim.space1,
      children: [
        item(StatusColor.good, 'Ready at your pace'),
        item(StatusColor.warn, 'Needs a faster pace'),
        item(StatusColor.bad, 'Too soon to be ready'),
        if (assessmentNoun != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 12,
                  height: 3,
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(_barRadius))),
              const SizedBox(width: Dim.space1),
              Text(assessmentNoun!,
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
/// Whether [a] has any round on or after [today] — i.e. the loop isn't fully in
/// the past. Fully-past interviews drop out of the sheet's list + calendar.
bool _hasUpcomingRound(Aim a, StudyGoal goal, DateTime today) {
  final dates = a.roundDates(goal.id, goal.deadline);
  if (dates.isEmpty) return false;
  final t = DateTime(today.year, today.month, today.day);
  return dates.any((d) => !d.isBefore(t));
}

({int leading, int days}) monthGrid(int year, int month,
    {int firstDayOfWeek = 0}) {
  final firstWeekday = DateTime(year, month, 1).weekday % 7; // 0=Sun … 6=Sat
  return (
    leading: (firstWeekday - firstDayOfWeek + 7) % 7,
    days: DateTime(year, month + 1, 0).day,
  );
}

/// Scheduled interviews listed under the calendar — one compact row per
/// interview, showing its NEXT upcoming round (companies schedule one at a time)
/// and a pace status judged against THAT interview's own role. Swipe a row or
/// use its menu to manage it; full round-by-round management lives on the
/// Upcoming-interviews screen. The header's 'Add' plans a new interview; the
/// list shows the 3 soonest with a 'show all' expander.
class _ScheduledSection extends ConsumerStatefulWidget {
  const _ScheduledSection({
    required this.interviews,
    required this.goal,
    required this.today,
    required this.onAdd,
  });

  final List<Aim> interviews; // sorted by soonest round first
  final StudyGoal goal;
  final DateTime today;
  final VoidCallback onAdd;

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
    final interviews = widget.interviews;
    final capped = interviews.length > _cap;
    final visible =
        (_showAll || !capped) ? interviews : interviews.take(_cap).toList();

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
              icon: const Icon(Icons.add, size: Dim.iconMd),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: Dim.space2)),
            ),
          ],
        ),
        if (interviews.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Dim.space1, bottom: Dim.space1),
            child: Text('None scheduled — add one to flag it on the calendar.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ),
        for (final iv in visible)
          InterviewCard(aim: iv, goal: widget.goal, today: widget.today),
        if (capped)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                  _showAll ? 'Show fewer' : 'Show all ${interviews.length}'),
            ),
          ),
      ],
    );
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
