import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/readiness/target.dart';
import '../../shared/providers/readiness.dart';

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

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
