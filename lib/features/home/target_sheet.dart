import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deck/deck.dart';
import '../../core/readiness/projection.dart';
import '../../core/readiness/target.dart';
import '../../core/template/active_template.dart';
import '../../core/template/deck_template.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/decks.dart';
import '../../shared/providers/template.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/sheet_header.dart';

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

/// Opens the **per-aim editor** (S5e-2 / ADR-0009): edit ONE aim's four knobs —
/// difficulty (`levelId`) · durability (`contextId`) · emphasis (`trackId`) · date
/// (its pending round) — and **Save → `upsertAim`**, the writer flip off the deck
/// slots. [aimId] null opens a fresh aim on the active deck. The aims LIST + the
/// planner live on the Aims screen, not here (this is a focused editor sheet).
Future<void> showAimEditorSheet(BuildContext context, {String? aimId}) {
  final size = MediaQuery.of(context).size;
  return showOnyxSheet<void>(
    context,
    constraints: BoxConstraints(
      maxHeight: size.height * 0.92,
      maxWidth: size.width - _sheetEdgeInset < _sheetMaxWidth
          ? size.width - _sheetEdgeInset
          : _sheetMaxWidth,
    ),
    builder: (_) => _AimEditorSheet(aimId: aimId),
  );
}

class _AimEditorSheet extends ConsumerStatefulWidget {
  const _AimEditorSheet({this.aimId});

  /// The aim to edit, or null to create a new one on the active deck.
  final String? aimId;

  @override
  ConsumerState<_AimEditorSheet> createState() => _AimEditorSheetState();
}

class _AimEditorSheetState extends ConsumerState<_AimEditorSheet> {
  Aim? _draft;
  String? _mintedId;

  void _set(Aim next) => setState(() => _draft = next);

  /// The aim being edited: the draft once touched, else the loaded aim, else a
  /// freshly-minted empty aim (new). The id is minted once so rebuilds are stable.
  Aim _initial(Deck goal, DateTime now) {
    final id = widget.aimId;
    if (id != null) {
      for (final a in goal.aims) {
        if (a.id == id) return a;
      }
    }
    _mintedId ??= 'aim-${now.microsecondsSinceEpoch}';
    return Aim(id: _mintedId!);
  }

  /// Set (or clear) the aim's primary date on its one **pending** round, leaving
  /// any resolved history untouched — the date knob is carried by [Aim.rounds].
  Aim _withDate(Aim aim, DateTime? date) {
    final rounds = [...aim.rounds];
    final i = rounds.indexWhere((r) => r.outcome == AimOutcome.pending);
    if (date == null) {
      if (i >= 0) {
        // Clearing the date must not silently drop a REAL round's type/notes (this
        // editor can also edit a planner-made interview whose round is typed, e.g.
        // "Onsite"). Keep such a round — just clear its date (copyWith clears via
        // the _unset sentinel) so the aim reads as open-ended; only a bare
        // synthetic date-holder (default type, no notes) is removed.
        final r = rounds[i];
        final bare =
            r.type == InterviewRoundType.other && (r.notes?.isEmpty ?? true);
        if (bare) {
          rounds.removeAt(i);
        } else {
          rounds[i] = r.copyWith(date: null);
        }
      }
      return aim.copyWith(rounds: rounds);
    }
    if (i >= 0) {
      rounds[i] = rounds[i].copyWith(date: date);
    } else {
      final n = rounds.length + 1;
      rounds.add(InterviewRound(id: '${aim.id}-r$n', number: n, date: date));
    }
    return aim.copyWith(rounds: rounds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final goal = ref.watch(activeDeckProvider).asData?.value;
    final deckTemplate = ref.watch(activeDeckTemplateProvider).asData?.value;
    final template = deckTemplate ?? activeTemplate;
    final vocab = template.vocabulary;
    final now =
        ref.watch(clockProvider).asData?.value.today() ?? DateTime.now();

    if (goal == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Dim.space6),
          child: LoadingView(),
        ),
      );
    }

    final aim = _draft ?? _initial(goal, now);
    // Resolve knob ids through the template fallbacks so a new aim shows sensible
    // defaults; the forecast + calendar follow the DRAFT dims live.
    final rt =
        ReadinessTarget.forAim(aim, template, date: aim.currentRound()?.date);
    final date = rt.interviewDate;
    final dims = (level: rt.level, company: rt.company, track: rt.track);
    final forecast =
        ref.watch(readinessForecastForProvider(dims)).asData?.value;

    // This aim's own dated rounds → calendar flags.
    final roundsByDate = <DateTime, List<String>>{};
    for (final r in aim.rounds) {
      final rd = r.date;
      if (rd == null) continue;
      roundsByDate
          .putIfAbsent(DateTime(rd.year, rd.month, rd.day), () => [])
          .add(r.label);
    }

    final title = aim.companyName.isEmpty ? 'Your target' : aim.companyName;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(title: title),
          SheetScrollBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The three categorical knobs — titles are subject-neutral via the
                // Vocabulary seam (SWE overrides to Level / Company / Track).
                _ChipGroup<LevelValue>(
                  label: vocab.levelAxisTitle,
                  values: template.target.levels,
                  selected: template.target.levelById(rt.levelId),
                  labelOf: (v) => v.label,
                  onSelected: (v) => _set(aim.copyWith(levelId: v.id)),
                ),
                _ChipGroup<ContextValue>(
                  label: vocab.contextAxisTitle,
                  values: template.target.contexts,
                  selected: template.target.contextById(rt.contextId),
                  labelOf: (v) => v.label,
                  onSelected: (v) => _set(aim.copyWith(contextId: v.id)),
                ),
                _ChipGroup<TrackValue>(
                  label: vocab.trackAxisTitle,
                  values: template.target.tracks,
                  selected: template.target.trackById(rt.trackId),
                  labelOf: (v) => v.label,
                  onSelected: (v) => _set(aim.copyWith(trackId: v.id)),
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
                        onPressed: () => _set(_withDate(aim, null)),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: Dim.space1),
                _ZoneCalendar(
                  forecast: forecast,
                  selected: date,
                  roundsByDate: roundsByDate,
                  onSelect: (d) => _set(_withDate(aim, d)),
                ),
                const SizedBox(height: Dim.space2),
                _CalendarLegend(assessmentNoun: vocab.assessmentNoun),
                const SizedBox(height: Dim.space4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      // The writer flip: the knobs + date persist onto the AIM
                      // (n006 — the deck is a pure lens), not the deck slots.
                      await ref
                          .read(decksProvider.notifier)
                          .upsertAim(goal.id, aim);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Save'),
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
