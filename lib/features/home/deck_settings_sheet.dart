import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deck/budget.dart';
import '../../core/plan/practice_plan.dart' show kSystemDesignMinutes;
import '../../core/template/active_template.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/daily_plan.dart';
import '../../shared/providers/decks.dart';
import '../../shared/providers/template.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/sheet_header.dart';

/// The per-deck config surface — **"This deck only"** (settings.md deck/vault split,
/// 1d). Reached from Home. Holds the deck's **share** of the shared daily budget
/// (with a too-little-time warning, deck_selection.md) and a **config-driven flow
/// scaffold** — a flow exposes its own NON-load knobs here only when the deck's
/// template declares that flow (none today). Workload itself is engine-derived
/// (ADR-0010); this is the deck's proportion + flow config, never workload dials.
Future<void> showDeckSettingsSheet(BuildContext context) => showOnyxSheet<void>(
      context,
      builder: (_) => const _DeckSettingsSheet(),
    );

class _DeckSettingsSheet extends ConsumerStatefulWidget {
  const _DeckSettingsSheet();

  @override
  ConsumerState<_DeckSettingsSheet> createState() => _DeckSettingsSheetState();
}

class _DeckSettingsSheetState extends ConsumerState<_DeckSettingsSheet> {
  // Local drag value for the share slider; null → track the saved budgetWeight so
  // the preview follows once persisted.
  double? _weight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final deck = ref.watch(activeDeckProvider).asData?.value;
    final decks = ref.watch(decksProvider).asData?.value ?? const [];
    final total = ref.watch(dailyBudgetMinutesProvider).asData?.value;
    final template =
        ref.watch(activeDeckTemplateProvider).asData?.value ?? activeTemplate;

    if (deck == null || total == null) {
      return const SafeArea(
        child:
            Padding(padding: EdgeInsets.all(Dim.space6), child: LoadingView()),
      );
    }

    // Live share preview: this deck's minutes = budget · weight / Σ active weights.
    // Drag updates it before the write lands, so the warning tracks the slider.
    final active = [
      for (final g in decks)
        if (g.isActive && g.budgetWeight > 0) g,
    ];
    final otherSum = active
        .where((g) => g.id != deck.id)
        .fold(0.0, (a, g) => a + g.budgetWeight);
    final multiDeck = active.length > 1;
    final weight = _weight ?? deck.budgetWeight;
    final allocated = multiDeck ? total * weight / (otherSum + weight) : total;
    final pct = total <= 0 ? 0 : (allocated / total * 100).round();

    // A deck runs "long sessions" when its template declares any practice-track
    // flow (a re-solve / conversational session) — config-driven, no card-type
    // branch (invariant #2).
    final hasLongSessions =
        template.flows.any((f) => template.isPracticeTrackType(f.cardType));
    final warning = deckAllocationWarning(
      allocatedMinutes: allocated,
      hasLongSessions: hasLongSessions,
      longSessionMinutes: kSystemDesignMinutes,
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(title: deck.name, subtitle: 'This deck only'),
          SheetScrollBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Study share',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: Dim.space1),
                Text(
                  multiDeck
                      ? '~${allocated.round()} min/day · $pct% of your '
                          '${total.round()}-min budget. Decks share the day; the '
                          'engine fills each with the right mix.'
                      : '~${allocated.round()} min/day — the whole budget (your '
                          'only active deck). Split it by adding more decks.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                if (multiDeck)
                  Slider(
                    value: weight.clamp(0.5, 3.0),
                    min: 0.5,
                    max: 3.0,
                    divisions: 5,
                    label: '${weight.toStringAsFixed(1)}×',
                    onChanged: (v) => setState(() => _weight = v),
                    onChangeEnd: (v) {
                      ref
                          .read(decksProvider.notifier)
                          .upsert(deck.copyWith(budgetWeight: v));
                      setState(() => _weight = null); // follow the saved value
                    },
                  ),
                if (warning != DeckAllocationWarning.none)
                  _WarningBanner(warning: warning, minutes: allocated.round()),
                const SizedBox(height: Dim.space5),
                Text('Flows',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: Dim.space1),
                Text(
                  template.flows.isEmpty
                      ? 'This deck has no declared flows yet.'
                      : 'This deck runs: '
                          '${template.flows.map((f) => f.label).join(', ')}. '
                          'Workload is automatic; a flow shows its own settings '
                          'here when it has any (none yet).',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: Dim.space5),
                Align(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.tune, size: Dim.iconMd),
                    label: const Text('Vault settings'),
                    onPressed: () {
                      // Leave the sheet, then switch to the vault Settings tab.
                      final router = GoRouter.of(context);
                      Navigator.pop(context);
                      router.go('/settings');
                    },
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

/// The too-little-time banner for a deck's daily allocation (deck_selection.md).
class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.warning, required this.minutes});

  final DeckAllocationWarning warning;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = switch (warning) {
      DeckAllocationWarning.tooLittle =>
        '~$minutes min/day is very little — hard to learn or retain much. Raise '
            "this deck's share or your daily budget.",
      DeckAllocationWarning.longSessionWontFit =>
        'A full practice session (~${kSystemDesignMinutes.round()} min) won\'t fit '
            "in ~$minutes min/day, so that flow can't run. Raise this deck's share "
            'or your daily budget.',
      DeckAllocationWarning.none => '',
    };
    return Container(
      margin: const EdgeInsets.only(top: Dim.space3),
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
            child: Text(msg,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: StatusColor.warn)),
          ),
        ],
      ),
    );
  }
}
