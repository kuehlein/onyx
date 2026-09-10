import 'package:flutter/material.dart';

import '../../core/readiness/prep_goal.dart';

/// Shared interview-round editing used by both the target sheet and the
/// Upcoming-interviews screen: a dialog to add/edit one round, plus the pure
/// mutation helpers that keep a [PrepGoal]'s rounds ordered, renumbered, and its
/// denormalized [PrepGoal.date] in sync.

/// Re-order [rounds] by date (dated ascending, undated last), renumber 1..n, and
/// mirror the earliest dated round into the denormalized [PrepGoal.date] that
/// legacy targeting still reads.
PrepGoal syncedGoal(PrepGoal g, List<InterviewRound> rounds) {
  final sorted = [...rounds]..sort((a, b) {
      if (a.date == null && b.date == null) return a.number.compareTo(b.number);
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

/// Add or replace a round (matched by id), returning the synced goal.
PrepGoal goalWithRound(PrepGoal g, InterviewRound round) {
  final rounds = [...g.effectiveRounds];
  final i = rounds.indexWhere((r) => r.id == round.id);
  if (i >= 0) {
    rounds[i] = round;
  } else {
    rounds.add(round);
  }
  return syncedGoal(g, rounds);
}

/// Remove a round by id. Returns the synced goal, or null when that empties the
/// loop (the caller should then delete the whole interview).
PrepGoal? goalWithoutRound(PrepGoal g, String roundId) {
  final rounds = [...g.effectiveRounds]..removeWhere((r) => r.id == roundId);
  if (rounds.isEmpty) return null;
  return syncedGoal(g, rounds);
}

/// A fresh round for [g], numbered next in the loop. Defaults to the generic
/// [InterviewRoundType.other] — the learner picks the real kind if they know it,
/// rather than us presuming a screen. [seed] disambiguates the id.
InterviewRound draftRound(PrepGoal g, {required int seed}) {
  final n = g.effectiveRounds.length + 1;
  return InterviewRound(
    id: '${g.id}-r$n-$seed',
    number: n,
  );
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
    final dated = _date != null;
    return AlertDialog(
      // Roomier than the default content-sized dialog, which felt cramped.
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      title: Text('Round ${widget.existing.number}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type — a bordered dropdown with a floating label.
            DropdownButtonFormField<InterviewRoundType>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final t in InterviewRoundType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 16),
            // Date — a matching bordered field that opens the picker on tap.
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.event, size: 20),
                  suffixIcon: dated
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Clear date',
                          onPressed: () => setState(() => _date = null),
                        )
                      : null,
                ),
                child: Text(
                  dated ? _fmtDate(_date!) : 'Not set',
                  style: dated
                      ? theme.textTheme.bodyLarge
                      : theme.textTheme.bodyLarge?.copyWith(color: muted),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Outcome',
                style: theme.textTheme.labelMedium?.copyWith(color: muted)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<GoalOutcome>(
                segments: const [
                  ButtonSegment(
                      value: GoalOutcome.pending, label: Text('Pending')),
                  ButtonSegment(
                      value: GoalOutcome.passed, label: Text('Passed')),
                  ButtonSegment(
                      value: GoalOutcome.failed, label: Text('Failed')),
                ],
                selected: {_outcome},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _outcome = s.first),
              ),
            ),
          ],
        ),
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
    // An already-scheduled round may sit in the past (e.g. a completed screen);
    // allow firstDate to reach back to it so editing doesn't assert. New rounds
    // (no date) still can't be picked before today. initialDate is clamped into
    // [firstDate, lastDate] to satisfy showDatePicker's invariants.
    final first = (_date != null && _date!.isBefore(base)) ? _date! : base;
    final last = base.add(const Duration(days: 365 * 2));
    var initial = _date ?? base.add(const Duration(days: 14));
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
