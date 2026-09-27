import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deck/budget.dart';
import '../../core/deck/deck.dart';
import '../../core/plan/practice_plan.dart' show kSystemDesignMinutes;
import '../../core/template/template_registry.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/daily_plan.dart';
import '../../shared/providers/decks.dart';
import '../../shared/providers/template.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/priority_tier_picker.dart';
import '../../shared/widgets/sheet_header.dart';

/// The vault-level **cross-deck allocation** view (ADR-0018 / #137): every active
/// deck with the engine-derived minutes/day today's split gives it, a proportion
/// bar, its soonest deadline, and its priority tier to adjust. The split is an
/// OUTPUT the user *reads* (minutes rebalance live as tiers change) — never a
/// percentage the user *types*. A per-deck engagement floor keeps any deck from
/// starving; it **warns on too-little-time** two ways (deck_selection.md): once at
/// the vault level when the day can't cover every deck even at the floor
/// (over-subscribed), and per-deck when a slice can't fit that deck's longest
/// practice session. Reached from the lanes hub; shown only with ≥2 active decks.
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
    final registry = ref.watch(templateRegistryProvider).value;

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

    // Over-subscribed: the day can't give every active deck even the engagement
    // floor, so allocateBudget falls back to a sub-floor equal split
    // (deck_selection.md). Surface it ONCE here rather than as a `tooLittle` flag on
    // every row (which would all fire together in exactly this case).
    final overSubscribed =
        active.length > 1 && kEngagementFloorMinutes * active.length >= total;
    final pausedCount = decks.where((g) => g.state == DeckState.paused).length;

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
                if (overSubscribed) ...[
                  const SizedBox(height: Dim.space3),
                  _WarnBanner(
                    message: 'Your ${total.round()}-min day can\'t give '
                        '${active.length} decks even '
                        '~${kEngagementFloorMinutes.round()} min each. Pause a deck '
                        'or raise your daily budget.',
                  ),
                ],
                if (active.isNotEmpty) ...[
                  const SizedBox(height: Dim.space4),
                  // The whole day at a glance — same rank order as the rows below,
                  // which act as its legend.
                  _SplitBar(
                      minutes: [for (final g in active) budgets[g.id] ?? 0]),
                ],
                const SizedBox(height: Dim.space4),
                for (final g in active) ...[
                  _AllocationRow(
                    goal: g,
                    minutes: budgets[g.id] ?? 0,
                    total: total,
                    today: today,
                    hasLongSessions: _hasLongSessions(registry, g),
                  ),
                  const SizedBox(height: Dim.space4),
                ],
                if (pausedCount > 0)
                  Text(
                    '$pausedCount paused '
                    '${pausedCount == 1 ? 'deck gets' : 'decks get'} no study time '
                    '— resume one from the deck list to include it.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
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
    required this.hasLongSessions,
  });

  final Deck goal;
  final double minutes;
  final double total;
  final DateTime today;

  /// True when the deck declares a long practice-track flow (e.g. a ~40-min mock),
  /// used to warn when the deck's slice can't fit one (deck_selection.md).
  final bool hasLongSessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurfaceVariant;
    final frac = total <= 0 ? 0.0 : (minutes / total).clamp(0.0, 1.0);

    final soonest = goal.soonestAimDate(today);
    final due = soonest == null ? null : _countdown(soonest, today);

    // A sub-floor (`tooLittle`) slice is surfaced once at the vault level; here we
    // flag only the deck-specific "a full practice session can't fit" case (which,
    // by the warning's if-order, can't co-occur with over-subscription).
    final longWontFit = deckAllocationWarning(
          allocatedMinutes: minutes,
          hasLongSessions: hasLongSessions,
          longSessionMinutes: kSystemDesignMinutes,
        ) ==
        DeckAllocationWarning.longSessionWontFit;

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
            // The minutes text carries the number; give the bar a spoken label so a
            // screen reader conveys the share too (a11y, #80).
            semanticsLabel: '${goal.name} share of the day',
            semanticsValue: '${(frac * 100).round()}%',
          ),
        ),
        if (due != null) ...[
          const SizedBox(height: Dim.space1),
          Text('soonest deadline · $due',
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
        if (longWontFit) ...[
          const SizedBox(height: Dim.space2),
          _WarnBanner(
            message: 'A full practice session '
                '(~${kSystemDesignMinutes.round()} min) won\'t fit in '
                '~${minutes.round()} min/day, so that flow can\'t run here. Raise '
                'this deck\'s priority or your daily budget.',
          ),
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

/// The engine-derived long-session flow cost isn't user-visible per deck here; the
/// helper resolves each deck's template (registry fallback to primary) to learn
/// whether it runs a long practice-track flow at all (deck_selection.md warning).
bool _hasLongSessions(TemplateRegistry? registry, Deck deck) {
  final t = registry?.byId(deck.templateId) ?? registry?.primary;
  if (t == null) return false;
  return t.flows.any((f) => t.isPracticeTrackType(f.cardType));
}

/// A single-row overview of how the day splits across the ranked active decks: one
/// accent segment per deck, width ∝ its minutes, opacity stepped down by rank (the
/// biggest share is boldest). Tonal steps of the *one* accent keep the single-accent
/// rule (design-system §2); the rows below share the rank order and act as its legend.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.minutes});

  /// Per-deck minutes, ranked biggest-first (same order as the rows).
  final List<double> minutes;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: Dim.brChip,
      child: SizedBox(
        height: Dim.space2,
        child: Row(
          children: [
            for (var i = 0; i < minutes.length; i++)
              Expanded(
                // ×10 keeps fine proportions; clamp ≥1 so a tiny slice still shows.
                flex: (minutes[i] * 10).round().clamp(1, 100000),
                child: ColoredBox(
                  color: primary.withValues(
                      alpha: (1.0 - i * 0.18).clamp(0.4, 1.0)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A compact warn-tinted banner (icon + message) for the allocation view's
/// too-little-time cases (deck_selection.md) — mirrors the deck-settings banner so
/// both surfaces read the same. Copy lives here (the subject-neutral UI seam).
class _WarnBanner extends StatelessWidget {
  const _WarnBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Dim.space3),
      decoration: BoxDecoration(
        color: StatusColor.warn.withValues(alpha: Dim.fill),
        borderRadius: Dim.brCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: Dim.iconMd, color: StatusColor.warn),
          const SizedBox(width: Dim.space2),
          Expanded(
            child: Text(message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: StatusColor.warn)),
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
