import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/backup.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/today_progress.dart';
import '../../shared/providers/vault.dart';
import 'coach_badge.dart';
import 'today_flows.dart';
import 'today_ring.dart';

/// Home: today's small wins first (the motivating metric), a glanceable readiness
/// chip for context, then the day's flows in priority order — the detailed charts
/// live on Insights. Kept deliberately calm and uncluttered.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off the one-time restore-from-vault-if-empty on app start.
    ref.watch(startupRestoreProvider);
    final index = ref.watch(vaultIndexProvider);
    final noVault = index.asData?.value.cardCount == 0;
    final apiKey = ref.watch(apiKeyProvider);
    final needsKey =
        apiKey.hasValue && (apiKey.value == null || apiKey.value!.isEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Onyx'),
        actions: const [_ReadinessChip(), SizedBox(width: 8)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _Greeting(clock: ref.watch(clockProvider).asData?.value),
              const SizedBox(height: 16),
              const Center(child: _TodayHero()),
              const SizedBox(height: 24),
              if (noVault)
                _Prompt(
                  icon: Icons.folder_open_outlined,
                  title: 'No vault configured yet',
                  subtitle: 'Point Onyx at your Obsidian vault in Settings.',
                  onTap: () => context.go('/settings'),
                )
              else
                const TodayFlows(),
              const SizedBox(height: 20),
              const CoachBadge(),
              const SizedBox(height: 16),
              // Low-emphasis extras: applied mock practice + interview planning.
              const _SecondaryActions(),
              if (needsKey) ...[
                const SizedBox(height: 20),
                _Prompt(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Enable AI features',
                  subtitle: 'Add your Anthropic API key in Settings.',
                  onTap: () => context.go('/settings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.clock});
  final Clock? clock;

  @override
  Widget build(BuildContext context) {
    final hour = clock?.now().hour;
    final word = hour == null
        ? 'Welcome back'
        : hour < 12
            ? 'Good morning'
            : hour < 18
                ? 'Good afternoon'
                : 'Good evening';
    return Text(word, style: Theme.of(context).textTheme.headlineSmall);
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
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox(
        height: 168,
        child: Center(child: Text('—')),
      ),
      data: (p) {
        if (p.nothingScheduled) {
          return const TodayRing(
              fraction: 0, centerLine: '—', subLine: 'All caught up');
        }
        return TodayRing(
          fraction: p.fraction,
          done: p.allDone,
          centerLine: p.allDone ? '' : '${p.done} / ${p.total}',
          subLine: p.allDone ? 'Done for today' : '~${p.minutesLeft} min left',
        );
      },
    );
  }
}

/// The interview-readiness readout — a small, glanceable chip in the app bar
/// (not a dominating gauge). Taps through to the full readiness report.
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
        onPressed: () => context.push('/report'),
        avatar: Icon(Icons.flag_outlined,
            size: 18, color: theme.colorScheme.primary),
        label: Text('Ready $pct%'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SecondaryActions extends ConsumerWidget {
  const _SecondaryActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weakest = ref.watch(readinessProvider).asData?.value.weakestDomain;
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            onPressed: weakest == null
                ? null
                : () => context.push('/practice/$weakest'),
            icon: const Icon(Icons.psychology_outlined, size: 18),
            label: const Text('Mock'),
          ),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: () => context.push('/interviews'),
            icon: const Icon(Icons.event_note_outlined, size: 18),
            label: const Text('Interviews'),
          ),
        ),
      ],
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
