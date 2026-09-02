import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/ai.dart';
import '../../shared/providers/backup.dart';
import '../../shared/providers/learn.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/srs.dart';
import '../../shared/providers/vault.dart';
import 'readiness_panel.dart';

/// Landing screen: what's ready to review, what's new to learn, and the ways in.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Kick off the one-time restore-from-vault-if-empty on app start.
    ref.watch(startupRestoreProvider);
    final index = ref.watch(vaultIndexProvider);
    final reviewData = ref.watch(reviewQueueProvider).asData?.value;
    final dueCount = reviewData?.queue.length;
    final hasProgress = reviewData?.statesByKey.isNotEmpty ?? false;
    final newCount = ref.watch(learnQueueProvider).asData?.value.length;
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
                  index.when(
                    loading: () => const Text('Indexing vault…',
                        textAlign: TextAlign.center),
                    error: (e, _) => Text('Index error: $e',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error)),
                    data: (r) => Text(
                      r.cardCount == 0
                          ? 'No vault configured yet — open Settings.'
                          : _statusLine(dueCount, newCount, r.cardCount),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    // Always tappable; the label tracks where you are in the
                    // day's loop, and /quiz guides you (learn first → review →
                    // extra practice) from its context-aware empty state.
                    onPressed: () => context.go('/quiz'),
                    icon: const Icon(Icons.school_outlined),
                    label: Text(
                      (dueCount ?? 0) > 0
                          ? 'Review — $dueCount due'
                          : (hasProgress ? 'Study more' : 'Study now'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: (newCount ?? 0) == 0
                        ? null
                        : () => context.go('/learn'),
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: Text(
                      (newCount ?? 0) == 0
                          ? 'Nothing new to learn'
                          : 'Learn — $newCount new',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Mock interview — applied/transfer practice, always available
                  // and independent of the FSRS due queue (so it never competes
                  // with gym-time reviews). Targets the weakest domain.
                  FilledButton.tonalIcon(
                    onPressed: weakest == null
                        ? null
                        : () => context.push('/practice/$weakest'),
                    icon: const Icon(Icons.psychology_outlined),
                    label: const Text('Mock interview'),
                  ),
                  const SizedBox(height: 12),
                  // AI readiness report — an honest assessment of where you
                  // stand for your target, incl. scope gaps the number can't see.
                  OutlinedButton.icon(
                    onPressed: () => context.push('/report'),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('AI readiness report'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/browse'),
                    icon: const Icon(Icons.grid_view_outlined),
                    label: const Text('Browse cards'),
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
            ],
          ),
        ),
      ),
    );
  }

  String _statusLine(int? due, int? newCount, int cardCount) {
    if (due == null && newCount == null) return '$cardCount cards indexed';
    final parts = <String>[
      if ((due ?? 0) > 0) '$due to review',
      if ((newCount ?? 0) > 0) '$newCount new to learn',
    ];
    return parts.isEmpty ? 'All caught up' : parts.join(' · ');
  }
}
