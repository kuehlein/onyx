import 'package:flutter/material.dart';
import '../../shared/widgets/loading_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/template/active_template.dart';
import '../../core/template/deck_template.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/backup.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/drafts.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/decks.dart';
import '../../shared/providers/template.dart';
import '../../shared/providers/today_progress.dart';
import '../../shared/providers/vault.dart';
import 'coach_badge.dart';
import 'deck_editor_sheet.dart';
import 'deck_settings_sheet.dart';
import 'lanes_hub.dart';
import 'today_flows.dart';
import 'today_ring.dart';

/// Home: with a single study goal it shows today's Home directly (the degradation
/// rule). With two or more concurrent goals it shows the "Today's mix" lanes hub;
/// tapping a lane enters that goal's Home, with a back arrow to the hub (#30d G5).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _enter(String deckId) =>
      ref.read(focusedDeckProvider.notifier).focus(deckId);

  @override
  Widget build(BuildContext context) {
    // Kick off the one-time restore-from-vault-if-empty on app start.
    ref.watch(startupRestoreProvider);
    final goals = ref.watch(decksProvider).asData?.value ?? const [];
    // Degradation is driven by ACTIVE goals only (paused/graduated excluded), so
    // "1 active + N paused" behaves like a single-goal app (ADR-0005).
    final activeGoals = [
      for (final g in goals)
        if (g.isActive) g,
    ];
    final focusedRaw = ref.watch(focusedDeckProvider);
    // Ignore a stale focus (the focused goal was paused/removed/graduated), so the
    // title and body never disagree with what's actually active.
    final focusedId =
        (focusedRaw != null && activeGoals.any((g) => g.id == focusedRaw))
            ? focusedRaw
            : null;
    final showHub = activeGoals.length >= 2 && focusedId == null;

    if (showHub) {
      return Scaffold(
        appBar: AppBar(title: const Text('Onyx')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Dim.maxNarrowWidth),
            child: LanesHub(onEnter: _enter),
          ),
        ),
      );
    }

    // Single-goal Home: the only goal, or the lane we entered.
    final focused = focusedId == null
        ? null
        : activeGoals.firstWhere((g) => g.id == focusedId);

    return Scaffold(
      appBar: AppBar(
        title: Text(focused?.name ?? 'Onyx'),
        // The persistent "Decks" escape hatch (deck_selection.md) — always present
        // (even single-deck, so you can add/switch/resume), a secondary action
        // rather than a prominent back arrow that reads as "leaving".
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Deck settings',
            onPressed: () => showDeckSettingsSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Decks',
            onPressed: () => context.push('/decks'),
          ),
          const _ReadinessChip(),
          const SizedBox(width: Dim.space2),
        ],
      ),
      body: const _DeckHomeBody(),
    );
  }
}

/// The single-goal Home body: today's small wins first (the motivating metric),
/// then the day's flows in priority order — detailed charts live on Insights.
class _DeckHomeBody extends ConsumerWidget {
  const _DeckHomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(vaultIndexProvider);
    final noVault = index.asData?.value.cardCount == 0;
    final apiKey = ref.watch(apiKeyProvider);
    final needsKey =
        apiKey.hasValue && (apiKey.value == null || apiKey.value!.isEmpty);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Dim.maxNarrowWidth),
        // Distribute the (short) content down the viewport so it breathes
        // instead of clustering at the top, while still scrolling on small
        // screens (minHeight = viewport; see the column note below).
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Dim.space5, Dim.space4, Dim.space5, Dim.space5),
                // mainAxisSize.min → the column sizes to its real content
                // (clamped up to the viewport by the ConstrainedBox), so
                // spaceBetween spreads the slack when there's room and it
                // simply scrolls when there isn't — no IntrinsicHeight
                // (which mis-measures ListTile/markdown and overflows).
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top: the date + the interview target card (glanceable,
                    // taps to edit — resurfaces the "Your target" sheet).
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DateHeader(
                            clock: ref.watch(clockProvider).asData?.value),
                        const SizedBox(height: Dim.space3),
                        const _TargetCard(),
                        const _DraftReviewPrompt(),
                      ],
                    ),
                    // Middle: today's ring hero + the priority flow stack.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: _TodayHero()),
                        const SizedBox(height: Dim.space6),
                        if (noVault)
                          _Prompt(
                            icon: Icons.folder_open_outlined,
                            title: 'No vault configured yet',
                            subtitle:
                                'Point Onyx at your Obsidian vault in Settings.',
                            onTap: () => context.go('/settings'),
                          )
                        else
                          const TodayFlows(),
                      ],
                    ),
                    // Bottom: the coach nudge (+ the key prompt when needed).
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CoachBadge(),
                        if (needsKey) ...[
                          const SizedBox(height: Dim.space4),
                          _Prompt(
                            icon: Icons.auto_awesome_outlined,
                            title: 'Enable AI features',
                            subtitle: 'Add your Anthropic API key in Settings.',
                            onTap: () => context.go('/settings'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Home target-card copy for a subject's [vocab]. The SWE reference
/// (`assessmentNoun: 'interview'`) reads byte-identically to before ("Set your
/// interview target" / "interview is today"); a neutral subject (no
/// `assessmentNoun`) gets neutral wording and never says "interview" (task #88 /
/// G7). Pure so it's unit-tested directly. [daysToGo] null = no date; [setLabel]
/// is the chosen target's label when set.
@visibleForTesting
({String title, String? countdown}) targetCardCopy({
  required Vocabulary vocab,
  required bool unset,
  required String setLabel,
  required int? daysToGo,
}) {
  final a = vocab.assessmentNoun;
  if (unset) {
    return (
      title: a == null ? 'Set your target' : 'Set your $a target',
      countdown: null,
    );
  }
  String? countdown;
  if (daysToGo != null) {
    countdown = daysToGo <= 0
        ? (a == null ? 'target is today' : '$a is today')
        : '$daysToGo day${daysToGo == 1 ? '' : 's'} to go';
  }
  return (title: setLabel, countdown: countdown);
}

/// The target as a contained, tappable card — the aim the readiness ring is
/// measured against. A subject with an assessment (SWE) opens the prep hub and
/// its label names that assessment; a neutral subject opens the goal editor and
/// reads a plain "Set your target" — no SWE interview chrome for a subject that
/// has none (task #88 / G7). Shows a set-it prompt when unset.
class _TargetCard extends ConsumerWidget {
  const _TargetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final target = ref.watch(activeTargetProvider).asData?.value;
    final clock = ref.watch(clockProvider).asData?.value;
    // Read the ACTIVE GOAL's template vocabulary (fall back to the primary while
    // it loads) so a non-SWE goal is never told to "set your interview target".
    final deckTemplate = ref.watch(activeDeckTemplateProvider).asData?.value;
    final vocab = deckTemplate?.vocabulary ?? activeTemplate.vocabulary;
    final goal = ref.watch(activeDeckProvider).asData?.value;
    // "Unset" = the goal has no explicitly-chosen target (activeTarget always
    // fills template fallbacks, so it can't be the signal).
    final unset = target == null ||
        ref.watch(activeTargetIsSetProvider).asData?.value != true;

    // Countdown from the soonest upcoming aim round (S5 — dates live on aims now;
    // the old `target.interviewDate` is structurally always null post-reframe).
    int? daysToGo;
    if (goal != null && clock != null) {
      final d = goal.soonestAimDate(clock.today());
      if (d != null) {
        daysToGo =
            DateTime(d.year, d.month, d.day).difference(clock.today()).inDays;
      }
    }
    final copy = targetCardCopy(
      vocab: vocab,
      unset: unset,
      setLabel: target?.label ?? '',
      daysToGo: daysToGo,
    );

    // Assessment subjects (SWE) open the prep hub; a neutral subject edits its
    // goal instead — no SWE interview-prep chrome for a subject that has none.
    final VoidCallback? onTap = vocab.hasAssessment
        ? () => context.push('/interview-prep')
        : (goal == null ? null : () => showDeckEditor(context, goal: goal));

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: Dim.brCard,
      child: InkWell(
        onTap: onTap,
        borderRadius: Dim.brCard,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Dim.space4, vertical: Dim.space3),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: Dim.iconMd, color: cs.primary),
              const SizedBox(width: Dim.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unset ? 'Target' : 'Your target',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 1),
                    Text(copy.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (copy.countdown != null) ...[
                const SizedBox(width: Dim.space3),
                Text(copy.countdown!,
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(width: Dim.space1),
              Icon(Icons.chevron_right,
                  size: Dim.iconMd, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet, low-key row surfacing pending drafts — "N cards to review before
/// they count" → the draft-review gate. Renders nothing while loading or when
/// there are no drafts. Deliberately not an alert hue (a draft is a normal,
/// expected state, docs/content-creation.md §3.3), just an unobtrusive nudge.
class _DraftReviewPrompt extends ConsumerWidget {
  const _DraftReviewPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(draftCardsProvider).asData?.value.length ?? 0;
    if (n == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Dim.space2),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: Dim.brCard,
        child: InkWell(
          onTap: () => context.push('/draft-review'),
          borderRadius: Dim.brCard,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Dim.space4, vertical: Dim.space3),
            child: Row(
              children: [
                Icon(Icons.inbox_outlined,
                    size: Dim.iconMd, color: cs.onSurfaceVariant),
                const SizedBox(width: Dim.space3),
                Expanded(
                  child: Text(
                    '$n card${n == 1 ? '' : 's'} to review before they count',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: Dim.space2),
                Icon(Icons.chevron_right,
                    size: Dim.iconMd, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet, factual date header — replaces the old time-of-day greeting, which
/// wasn't grounded in anything and misread late-night hours as "morning".
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.clock});
  final Clock? clock;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  Widget build(BuildContext context) {
    final now = clock?.now();
    final text = now == null
        ? 'Today'
        : '${_weekdays[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day}';
    return Text(text, style: Theme.of(context).textTheme.headlineSmall);
  }
}

/// The today-progress ring, driven by [todayProgressProvider].
class _TodayHero extends ConsumerWidget {
  const _TodayHero();

  // Diameter of the today-completion ring hero (matches TodayRing's own size),
  // reserved during load/error so the layout doesn't jump when data lands.
  static const _ringDiameter = 168.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayProgressProvider);
    return async.when(
      loading: () => const SizedBox(
        height: _ringDiameter,
        width: _ringDiameter,
        child: LoadingView(),
      ),
      // Compact, honest error in the reserved ring slot — not a full EmptyState
      // (too heavy for the hero) and not a silent/cryptic dash.
      error: (_, __) => SizedBox(
        height: _ringDiameter,
        child: Center(
          child: Text(
            "Couldn't load today",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
      data: (p) {
        final ring = p.nothingScheduled
            ? const TodayRing(
                fraction: 0, centerLine: '—', subLine: 'All caught up')
            : TodayRing(
                fraction: p.fraction,
                done: p.allDone,
                centerLine: p.allDone ? '' : '${p.percent}%',
                subLine: p.allDone
                    ? 'Done for today'
                    : '~${p.remainingMinutes} min left',
              );
        // Tap the ring to see the habit trend behind it (Insights → Habits).
        return InkResponse(
          onTap: () => context.go('/insights?focus=habits'),
          radius: 100,
          child: ring,
        );
      },
    );
  }
}

/// The interview-readiness readout — a small, glanceable chip in the app bar
/// (not a dominating gauge). Taps through to the Insights readiness breakdown
/// (which itself links on to the heavier AI report).
class _ReadinessChip extends ConsumerWidget {
  const _ReadinessChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(readinessProvider).asData?.value;
    if (r == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final pct = (r.overall * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dim.space2),
      child: ActionChip(
        onPressed: () => context.go('/insights?focus=readiness'),
        avatar: Icon(Icons.flag_outlined,
            size: Dim.iconMd, color: theme.colorScheme.primary),
        label: Text('Ready $pct%'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
