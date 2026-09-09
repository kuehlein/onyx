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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _t.interviewDate ?? today.add(const Duration(days: 30)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
      helpText: 'Interview date',
    );
    if (picked != null) {
      _set(_t.copyWith(
          interviewDate: DateTime(picked.year, picked.month, picked.day)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = _t;
    final date = t.interviewDate;

    return SafeArea(
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
            Text('Interview date',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(date == null ? 'Set a date' : _fmtDate(date)),
                ),
                if (date != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _set(t.copyWith(interviewDate: null)),
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // Projected "ready date" at the recent pace (recall maturation only),
            // with a chill/push range + a feasibility note vs. the chosen date.
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

      rows.add(const SizedBox(height: 10));
      rows.add(_ForecastTimeline(forecast: f, chosenDate: chosenDate));

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

/// A compact colour-zoned timeline from today: red = not reachable even at the
/// fastest sampled pace, amber = reachable but faster than your current pace,
/// green = comfortable at your pace. A dark marker shows the chosen date.
class _ForecastTimeline extends StatelessWidget {
  const _ForecastTimeline({required this.forecast, this.chosenDate});

  final ReadinessForecast forecast;
  final DateTime? chosenDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = forecast;
    final amberStart = f.earliestReadyDay; // fastest pace reaches here
    final greenStart = f.currentReadyDay; // current pace reaches here
    final chosenDay = chosenDate?.difference(f.today).inDays;

    var end = (greenStart ?? amberStart ?? 365).toDouble();
    if (chosenDay != null && chosenDay > end) end = chosenDay.toDouble();
    end = (end * 1.25).clamp(30, 366);

    return LayoutBuilder(builder: (context, cns) {
      final w = cns.maxWidth;
      double px(num day) => (day / end).clamp(0.0, 1.0) * w;
      final amberX = px(amberStart ?? end.toInt());
      final greenX = px(greenStart ?? end.toInt());

      Widget seg(double left, double right, Color c) => right - left <= 0.5
          ? const SizedBox.shrink()
          : Positioned(
              left: left,
              top: 0,
              child: Container(width: right - left, height: 8, color: c));

      return SizedBox(
        height: 30,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: w,
                height: 8,
                child: Stack(children: [
                  Container(color: theme.colorScheme.surfaceContainerHighest),
                  seg(0, amberX, statusBad.withValues(alpha: 0.45)),
                  seg(amberX, greenX, statusWarn.withValues(alpha: 0.55)),
                  seg(greenX, w, statusGood.withValues(alpha: 0.55)),
                ]),
              ),
            ),
            // "now" tick
            Positioned(
                left: 0,
                top: 11,
                child: Text('now',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            // ready (current pace) tick
            if (greenStart != null && f.currentReadyDate != null)
              Positioned(
                left: (px(greenStart) - 14).clamp(0.0, w - 40),
                top: 11,
                child: Text(_fmtMonthShort(f.currentReadyDate!),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: statusGood)),
              ),
            // chosen-date marker
            if (chosenDay != null)
              Positioned(
                left: (px(chosenDay) - 1).clamp(0.0, w - 2),
                top: -2,
                child: Container(
                    width: 2, height: 12, color: theme.colorScheme.onSurface),
              ),
          ],
        ),
      );
    });
  }
}

String _fmtMonthShort(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
  ];
  return months[d.month - 1];
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
