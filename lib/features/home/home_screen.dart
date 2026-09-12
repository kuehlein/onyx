import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/ai.dart';
import '../../shared/providers/backup.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/vault.dart';
import 'coach_badge.dart';
import 'readiness_panel.dart';
import 'today_plan.dart';

/// Landing screen: what's ready to review, what's new to learn, and the ways in.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Kick off the one-time restore-from-vault-if-empty on app start.
    ref.watch(startupRestoreProvider);
    final index = ref.watch(vaultIndexProvider);
    final weakest = ref.watch(readinessProvider).asData?.value.weakestDomain;
    final apiKey = ref.watch(apiKeyProvider);
    final needsKey =
        apiKey.hasValue && (apiKey.value == null || apiKey.value!.isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Onyx')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const ReadinessPanel(),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // No vault yet is the one blocking state the Today card can't
                  // speak to — surface it (and index errors) inline; otherwise the
                  // Today queue is the day's whole story.
                  ...index.when(
                    loading: () => const <Widget>[],
                    error: (e, _) => [
                      Text('Index error: $e',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 14),
                    ],
                    data: (r) {
                      if (r.cardCount != 0) return const <Widget>[];
                      return [
                        Text('No vault configured yet — open Settings.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 14),
                      ];
                    },
                  ),
                  const TodayPlan(),
                  const SizedBox(height: 16),
                  // Secondary actions as a compact pair (Browse lives in the
                  // bottom-nav, so it isn't duplicated here). Mock interview is
                  // applied/transfer practice, independent of the FSRS due queue
                  // (never competes with reviews); it targets the weakest domain.
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: weakest == null
                              ? null
                              : () => context.push('/practice/$weakest'),
                          icon: const Icon(Icons.psychology_outlined),
                          label: const Text('Mock'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/interviews'),
                          icon: const Icon(Icons.event_note_outlined),
                          label: const Text('Interviews'),
                        ),
                      ),
                    ],
                  ),
                  if (needsKey) ...[
                    const SizedBox(height: 24),
                    Card(
                      margin: EdgeInsets.zero,
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: ListTile(
                        leading: Icon(Icons.auto_awesome_outlined,
                            color: theme.colorScheme.primary),
                        title: const Text('Enable AI features'),
                        subtitle: const Text(
                            'Add your Anthropic API key in Settings'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/settings'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // Ambient coach nudge — one prioritized, task-level line.
              const CoachBadge(),
            ],
          ),
        ),
      ),
    );
  }
}
