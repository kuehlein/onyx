import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/coach/coach_update.dart';
import '../../shared/coach_settings.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/settings.dart';

/// The opt-in weekly load check-in. Step 1: how's it feeling? Step 2 (optional):
/// a matching one-tap load adjustment. Recording the answer also feeds the
/// coach's future suggestions (a "too much" suppresses increase nudges).
Future<void> showLoadCheckInSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
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

  Future<void> _adjust(int delta) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final r = await applyCoachSetting(ref, CoachSetting.newCardsPerDay, delta);
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text('New cards/day: ${r.before} → ${r.after}'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () =>
            setCoachSetting(ref, CoachSetting.newCardsPerDay, r.before),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
            const SizedBox(width: 10),
            Expanded(
              child: Text("How's the study load feeling this week?",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Only you know if it’s sustainable. I’ll factor your answer into what '
          'I suggest next.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        for (final o in _options) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _record(o.feel),
              icon: Icon(o.icon, size: 20),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(o.label),
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
          'Fewer new cards each day shrinks your future review load — the '
              'fastest way to lighten things. Want me to trim new cards/day by 3?',
          'Reduce new cards/day by 3',
          -3,
        ),
      LoadFeel.couldDoMore => (
          'Room to grow',
          'Nice. A small bump keeps it sustainable — I’d add just a few new '
              'cards/day and see how next week feels. (If recall dips, we ease '
              'back.)',
          'Add 3 new cards/day',
          3,
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
      const SizedBox(height: 8),
      Text(body,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurface, height: 1.4)),
      const SizedBox(height: 20),
      if (applyLabel != null)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _adjust(delta),
            icon: const Icon(Icons.check, size: 18),
            label: Text(applyLabel),
          ),
        ),
      const SizedBox(height: 8),
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
