import 'package:flutter/material.dart';

import '../../core/goal/interview_aim.dart';
import '../../shared/design/onyx_design.dart';

/// Shared interview-round editing used by both the target sheet and the
/// Upcoming-interviews screen: a dialog to add/edit one round, plus the pure
/// mutation helpers that keep an [InterviewAim]'s rounds ordered and renumbered.

/// Re-order [rounds] by date (dated ascending, undated last, ties by number),
/// renumber 1..n, and return the updated aim. The goal's single [deadline] is no
/// longer denormalized here — rounds are the source of truth.
InterviewAim syncedAim(InterviewAim a, List<InterviewRound> rounds) {
  final sorted = [...rounds]..sort((x, y) {
      if (x.date == null && y.date == null) return x.number.compareTo(y.number);
      if (x.date == null) return 1;
      if (y.date == null) return -1;
      return x.date!.compareTo(y.date!);
    });
  final renum = [
    for (var i = 0; i < sorted.length; i++) sorted[i].copyWith(number: i + 1),
  ];
  return a.copyWith(rounds: renum);
}

/// Add or replace a round (matched by id), returning the synced aim.
InterviewAim aimWithRound(InterviewAim a, InterviewRound round) {
  final rounds = [...a.rounds];
  final i = rounds.indexWhere((r) => r.id == round.id);
  if (i >= 0) {
    rounds[i] = round;
  } else {
    rounds.add(round);
  }
  return syncedAim(a, rounds);
}

/// Remove a round by id. Returns the synced aim, or null when that empties the
/// loop (the caller should then delete the whole interview).
InterviewAim? aimWithoutRound(InterviewAim a, String roundId) {
  final rounds = [...a.rounds]..removeWhere((r) => r.id == roundId);
  if (rounds.isEmpty) return null;
  return syncedAim(a, rounds);
}

/// A fresh round for [a], numbered next in the loop. Defaults to the generic
/// [InterviewRoundType.other] — the learner picks the real kind if they know it,
/// rather than us presuming a screen. [seed] disambiguates the id.
InterviewRound draftRound(InterviewAim a, {required int seed}) {
  final n = a.rounds.length + 1;
  return InterviewRound(
    id: '${a.id}-r$n-$seed',
    number: n,
  );
}

/// A dialog to schedule or reschedule one round: its type + date. The round's
/// outcome is set elsewhere (logging a result), not here. Returns the updated
/// round, or null on cancel. [title] labels the dialog (e.g. "Reschedule",
/// "Next round").
Future<InterviewRound?> showRoundDialog(
  BuildContext context, {
  required DateTime today,
  required InterviewRound existing,
  String? title,
}) =>
    showDialog<InterviewRound>(
      context: context,
      builder: (_) =>
          _RoundDialog(today: today, existing: existing, title: title),
    );

class _RoundDialog extends StatefulWidget {
  const _RoundDialog({required this.today, required this.existing, this.title});

  final DateTime today;
  final InterviewRound existing;
  final String? title;

  @override
  State<_RoundDialog> createState() => _RoundDialogState();
}

class _RoundDialogState extends State<_RoundDialog> {
  late InterviewRoundType _type = widget.existing.type;
  late DateTime? _date = widget.existing.date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dated = _date != null;
    return AlertDialog(
      // Roomier than the default content-sized dialog, which felt cramped.
      insetPadding: const EdgeInsets.symmetric(
          horizontal: Dim.space6, vertical: Dim.space5),
      contentPadding: const EdgeInsets.fromLTRB(
          Dim.space5, Dim.space5, Dim.space5, Dim.space2),
      title: Text(widget.title ?? 'Round ${widget.existing.number}'),
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
            const SizedBox(height: Dim.space4),
            // Date — a matching bordered field that opens the picker on tap.
            InkWell(
              onTap: _pickDate,
              borderRadius: Dim.brChip,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.event, size: Dim.iconMd),
                  suffixIcon: dated
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: Dim.iconMd),
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
            widget.existing.copyWith(type: _type, date: _date),
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
