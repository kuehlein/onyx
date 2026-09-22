import 'package:flutter/material.dart';
import '../../shared/widgets/loading_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deck/deck.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/daily_plan.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/decks.dart';
import 'deck_editor_sheet.dart';

/// The "Today's mix" lanes hub (task #30d, G5): one lane per concurrent study
/// goal, showing its share of today's shared budget, readiness, and deadline.
/// Tapping a lane enters that goal (its own Home). Shown only when ≥2 goals live;
/// a single goal renders today's Home directly (the degradation rule).
class LanesHub extends ConsumerWidget {
  const LanesHub({super.key, required this.onEnter});

  /// Called with a goal id when the user taps into a lane.
  final void Function(String deckId) onEnter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goalsAsync = ref.watch(decksProvider);

    return goalsAsync.when(
      loading: () => const LoadingView(),
      error: (_, __) => const Center(child: Text('—')),
      data: (goals) {
        final live = [
          for (final g in goals)
            if (g.state != DeckState.graduated) g,
        ];
        final active = [
          for (final g in live)
            if (g.isActive) g
        ];
        final paused = [
          for (final g in live)
            if (g.state == DeckState.paused) g,
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(
              Dim.space4, Dim.space3, Dim.space4, Dim.space5),
          children: [
            Text("Today's mix", style: theme.textTheme.headlineSmall),
            const SizedBox(height: Dim.space1),
            Text(
              'Your decks share the day. Tap one to study it.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Dim.space4),
            for (final g in active) ...[
              _DeckLane(goal: g, onEnter: onEnter),
              const SizedBox(height: Dim.space3),
            ],
            for (final g in paused) ...[
              _PausedRow(goal: g),
              const SizedBox(height: Dim.space2),
            ],
            const SizedBox(height: Dim.space2),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New deck'),
              onPressed: () => showDeckEditor(context),
            ),
          ],
        );
      },
    );
  }
}

class _DeckLane extends ConsumerWidget {
  const _DeckLane({required this.goal, required this.onEnter});

  final Deck goal;
  final void Function(String deckId) onEnter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final minutes = ref.watch(deckBudgetsProvider).asData?.value[goal.id];
    final r = ref.watch(deckReadinessProvider(goal.id)).asData?.value;
    final clock = ref.watch(clockProvider).asData?.value;

    final subParts = <String>[
      if (r != null) '${(r.overall * 100).round()}% ready',
      if (goal.deadline case final d? when clock != null)
        _countdown(d, clock.today()),
    ];

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: Dim.brCard,
      child: InkWell(
        onTap: () => onEnter(goal.id),
        onLongPress: () => showDeckEditor(context, goal: goal),
        borderRadius: Dim.brCard,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Dim.space4, Dim.space4, Dim.space2, Dim.space4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (subParts.isNotEmpty) ...[
                      const SizedBox(height: Dim.space1),
                      Text(subParts.join('  ·  '),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              if (minutes != null && minutes >= 1) ...[
                const SizedBox(width: Dim.space2),
                Text('~${minutes.round()}m',
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.w700)),
              ],
              IconButton(
                tooltip: 'Pause',
                icon: const Icon(Icons.pause_circle_outline, size: Dim.iconMd),
                color: cs.onSurfaceVariant,
                onPressed: () => ref
                    .read(decksProvider.notifier)
                    .upsert(goal.copyWith(state: DeckState.paused)),
              ),
              Icon(Icons.chevron_right,
                  size: Dim.iconMd, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _PausedRow extends ConsumerWidget {
  const _PausedRow({required this.goal});

  final Deck goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dim.space1),
      child: Row(
        children: [
          Icon(Icons.pause_circle_filled,
              size: Dim.iconMd, color: cs.onSurfaceVariant),
          const SizedBox(width: Dim.space3),
          Expanded(
            child: Text('${goal.name} · paused',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => ref
                .read(decksProvider.notifier)
                .upsert(goal.copyWith(state: DeckState.active)),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }
}

String _countdown(DateTime deadline, DateTime today) {
  final days = DateTime(deadline.year, deadline.month, deadline.day)
      .difference(today)
      .inDays;
  if (days < 0) return 'past due';
  if (days == 0) return 'due today';
  return '${days}d left';
}
