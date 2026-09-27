import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deck/deck.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/daily_plan.dart';
import '../../shared/providers/decks.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/priority_tier_picker.dart';
import '../../shared/widgets/sheet_header.dart';

/// The vault-level **cross-deck allocation** view (ADR-0018 / #137): every active
/// deck with the engine-derived minutes/day today's split gives it, a proportion
/// bar, its soonest deadline, and its priority tier to adjust. The split is an
/// OUTPUT the user *reads* (minutes rebalance live as tiers change) — never a
/// percentage the user *types*. A per-deck engagement floor keeps any deck from
/// starving. Reached from the lanes hub; shown only with ≥2 active decks.
Future<void> showDeckAllocationSheet(BuildContext context) =>
    showOnyxSheet<void>(context, builder: (_) => const _DeckAllocationSheet());

class _DeckAllocationSheet extends ConsumerWidget {
  const _DeckAllocationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // valueOrNull (not asData): keep the last split on screen while a tier change
    // re-derives it, so the bars rebalance smoothly instead of flashing empty.
    final decks = ref.watch(decksProvider).value ?? const <Deck>[];
    final budgets =
        ref.watch(deckBudgetsProvider).value ?? const <String, double>{};
    final total = ref.watch(dailyBudgetMinutesProvider).value;
    final today = ref.watch(clockProvider).value?.today();

    if (total == null || today == null) {
      return const SafeArea(
        child:
            Padding(padding: EdgeInsets.all(Dim.space6), child: LoadingView()),
      );
    }

    final active = [
      for (final g in decks)
        if (g.isActive) g,
    ];
    // Biggest share first — the split reads top-to-bottom like a ranking.
    active.sort((a, b) => (budgets[b.id] ?? 0).compareTo(budgets[a.id] ?? 0));

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeader(
              title: 'Balance study time', subtitle: 'Across your decks'),
          SheetScrollBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The engine splits your ${total.round()}-min day by each deck\'s '
                  'priority and how soon its aims are due. Set a priority below; the '
                  'minutes rebalance live. Every deck keeps a small floor so none '
                  'stalls.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: Dim.space4),
                for (final g in active) ...[
                  _AllocationRow(
                    goal: g,
                    minutes: budgets[g.id] ?? 0,
                    total: total,
                    today: today,
                  ),
                  const SizedBox(height: Dim.space4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationRow extends ConsumerWidget {
  const _AllocationRow({
    required this.goal,
    required this.minutes,
    required this.total,
    required this.today,
  });

  final Deck goal;
  final double minutes;
  final double total;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurfaceVariant;
    final frac = total <= 0 ? 0.0 : (minutes / total).clamp(0.0, 1.0);

    final soonest = goal.soonestAimDate(today);
    final due = soonest == null ? null : _countdown(soonest, today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: Dim.space2),
            Text('~${minutes.round()} min/day',
                style: theme.textTheme.labelMedium?.copyWith(color: muted)),
          ],
        ),
        const SizedBox(height: Dim.space2),
        ClipRRect(
          borderRadius: Dim.brChip,
          child: LinearProgressIndicator(
            value: frac,
            minHeight: Dim.space2,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        if (due != null) ...[
          const SizedBox(height: Dim.space1),
          Text('soonest deadline · $due',
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
        const SizedBox(height: Dim.space2),
        PriorityTierPicker(
          value: goal.priority,
          onChanged: (v) => ref
              .read(decksProvider.notifier)
              .upsert(goal.copyWith(priority: v)),
        ),
      ],
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
