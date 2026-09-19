import 'package:flutter/material.dart';
import '../../shared/widgets/loading_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/backup.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/study_goals.dart';
import '../../shared/providers/today_progress.dart';
import '../../shared/providers/vault.dart';
import 'coach_badge.dart';
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
  void _enter(String goalId) =>
      ref.read(focusedGoalProvider.notifier).focus(goalId);

  void _backToHub() => ref.read(focusedGoalProvider.notifier).focus(null);

  @override
  Widget build(BuildContext context) {
    // Kick off the one-time restore-from-vault-if-empty on app start.
    ref.watch(startupRestoreProvider);
    final goals = ref.watch(studyGoalsProvider).asData?.value ?? const [];
    // Degradation is driven by ACTIVE goals only (paused/graduated excluded), so
    // "1 active + N paused" behaves like a single-goal app (ADR-0005).
    final activeGoals = [
      for (final g in goals)
        if (g.isActive) g,
    ];
    final focusedRaw = ref.watch(focusedGoalProvider);
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
            constraints: const BoxConstraints(maxWidth: 480),
            child: LanesHub(onEnter: _enter),
          ),
        ),
      );
    }

    // Single-goal Home: the only goal, or the lane we entered.
    final canGoBack = activeGoals.length >= 2 && focusedId != null;
    final focused = focusedId == null
        ? null
        : activeGoals.firstWhere((g) => g.id == focusedId);

    return Scaffold(
      appBar: AppBar(
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: "Today's mix",
                onPressed: _backToHub,
              )
            : null,
        title: Text(focused?.name ?? 'Onyx'),
        actions: const [_ReadinessChip(), SizedBox(width: 8)],
      ),
      body: const _GoalHomeBody(),
    );
  }
}

/// The single-goal Home body: today's small wins first (the motivating metric),
/// then the day's flows in priority order — detailed charts live on Insights.
class _GoalHomeBody extends ConsumerWidget {
  const _GoalHomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(vaultIndexProvider);
    final noVault = index.asData?.value.cardCount == 0;
    final apiKey = ref.watch(apiKeyProvider);
    final needsKey =
        apiKey.hasValue && (apiKey.value == null || apiKey.value!.isEmpty);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        // Distribute the (short) content down the viewport so it breathes
        // instead of clustering at the top, while still scrolling on small
        // screens (minHeight = viewport; see the column note below).
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                        const SizedBox(height: 12),
                        const _TargetCard(),
                      ],
                    ),
                    // Middle: today's ring hero + the priority flow stack.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: _TodayHero()),
                        const SizedBox(height: 28),
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
                          const SizedBox(height: 16),
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

/// The interview target as a contained, tappable card — the goal the readiness
/// ring is measured against. Taps open the "Your target" sheet (its only route in
/// now that the old readiness panel is gone). Shows a set-it prompt when unset.
class _TargetCard extends ConsumerWidget {
  const _TargetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final target = ref.watch(activeTargetProvider).asData?.value;
    final clock = ref.watch(clockProvider).asData?.value;
    // "Unset" = the goal has no explicitly-chosen target (activeTarget always
    // fills template fallbacks, so it can't be the signal).
    final unset = target == null ||
        ref.watch(activeTargetIsSetProvider).asData?.value != true;

    final String title;
    String? countdown;
    if (unset) {
      title = 'Set your interview target';
    } else {
      title = target.label;
      final d = target.interviewDate;
      if (d != null && clock != null) {
        final days =
            DateTime(d.year, d.month, d.day).difference(clock.today()).inDays;
        countdown = days <= 0
            ? 'interview is today'
            : '$days day${days == 1 ? '' : 's'} to go';
      }
    }

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push('/interview-prep'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unset ? 'Target' : 'Your target',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 1),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (countdown != null) ...[
                const SizedBox(width: 10),
                Text(countdown,
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
            ],
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayProgressProvider);
    return async.when(
      loading: () => const SizedBox(
        height: 168,
        width: 168,
        child: LoadingView(),
      ),
      error: (_, __) => const SizedBox(
        height: 168,
        child: Center(child: Text('—')),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ActionChip(
        onPressed: () => context.go('/insights?focus=readiness'),
        avatar: Icon(Icons.flag_outlined,
            size: 18, color: theme.colorScheme.primary),
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
