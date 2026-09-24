import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/coach/coach_update.dart';
import '../../shared/coach_settings.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/settings.dart';
import '../../shared/widgets/sheet_header.dart';

/// The opt-in weekly load check-in. Step 1: how's it feeling? Step 2 (optional):
/// a matching one-tap load adjustment. Recording the answer also feeds the
/// coach's future suggestions (a "too much" suppresses increase nudges).
Future<void> showLoadCheckInSheet(BuildContext context, WidgetRef ref) {
  return showOnyxSheet<void>(
    context,
    isScrollControlled: false,
    builder: (_) => const _LoadCheckInSheet(),
  );
}

const _options = <({LoadFeel feel, String label, IconData icon})>[
  (
    feel: LoadFeel.tooMuch,
    label: 'Too much',
    icon: Icons.sentiment_dissatisfied_outlined
  ),
  (
    feel: LoadFeel.aboutRight,
    label: 'About right',
    icon: Icons.sentiment_satisfied_outlined
  ),
  (
    feel: LoadFeel.couldDoMore,
    label: 'I could do more',
    icon: Icons.sentiment_very_satisfied_outlined
  ),
];

class _LoadCheckInSheet extends ConsumerStatefulWidget {
  const _LoadCheckInSheet();
  @override
  ConsumerState<_LoadCheckInSheet> createState() => _LoadCheckInSheetState();
}

class _LoadCheckInSheetState extends ConsumerState<_LoadCheckInSheet> {
  LoadFeel? _answered;

  DateTime get _now =>
      (ref.read(clockProvider).asData?.value ?? Clock.real).now();

  Future<void> _record(LoadFeel feel) async {
    await ref.read(loadCheckInProvider.notifier).record(feel, _now);
    setState(() => _answered = feel);
  }

  Future<void> _adjust(int deltaMinutes) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // The user's own answer is the consent — apply the budget change they picked
    // (ADR-0011: the coach's one lever is the daily budget), with a one-tap undo.
    final r = await applyBudgetDelta(ref, deltaMinutes);
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text('Daily study time: ${r.before} → ${r.after} min'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => setBudgetMinutes(ref, r.before),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Dim.space5, Dim.space1, Dim.space5, Dim.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              _answered == null ? _ask(theme) : _followUp(theme, _answered!),
        ),
      ),
    );
  }

  List<Widget> _ask(ThemeData theme) => [
        Row(
          children: [
            Icon(Icons.favorite_outline, color: theme.colorScheme.primary),
            const SizedBox(width: Dim.space3),
            Expanded(
              child: Text("How's the study load feeling this week?",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: Dim.space2),
        Text(
          'Only you know if it’s sustainable. I’ll factor your answer into what '
          'I suggest next.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: Dim.space4),
        for (final o in _options) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _record(o.feel),
              icon: Icon(o.icon, size: Dim.iconMd),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(o.label),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: Dim.space4, vertical: Dim.space4),
              ),
            ),
          ),
          const SizedBox(height: Dim.space2),
        ],
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () {
              ref.read(loadCheckInProvider.notifier).snooze(_now);
              Navigator.of(context).pop();
            },
            child: const Text('Not now'),
          ),
        ),
      ];

  List<Widget> _followUp(ThemeData theme, LoadFeel feel) {
    final (title, body, applyLabel, delta) = switch (feel) {
      LoadFeel.tooMuch => (
          'Let’s ease off',
          'A little less time each day lightens the load — the app keeps your '
              'reviews first and eases new material automatically. Want me to trim '
              'your daily study time by 15 min?',
          'Trim 15 min/day',
          -15,
        ),
      LoadFeel.couldDoMore => (
          'Room to grow',
          'Nice. A little more time each day gives the app room to fit more in — '
              'and see how next week feels. (If recall dips, we ease back.)',
          'Add 15 min/day',
          15,
        ),
      LoadFeel.aboutRight => (
          'Steady it is',
          'Great — consistency is what compounds. I’ll keep things where they '
              'are and check in again next week.',
          null,
          0,
        ),
    };
    return [
      Text(title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: Dim.space2),
      Text(body,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurface, height: 1.4)),
      const SizedBox(height: Dim.space5),
      if (applyLabel != null)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _adjust(delta),
            icon: const Icon(Icons.check, size: Dim.iconMd),
            label: Text(applyLabel),
          ),
        ),
      const SizedBox(height: Dim.space2),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(applyLabel == null ? 'Done' : 'Not now'),
        ),
      ),
    ];
  }
}
