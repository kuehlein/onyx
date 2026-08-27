import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/learn.dart';
import '../../shared/providers/srs.dart';
import '../../shared/providers/vault.dart';

/// Landing screen: what's ready to review, what's new to learn, and the ways in.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final index = ref.watch(vaultIndexProvider);
    final dueCount = ref.watch(reviewQueueProvider).asData?.value.queue.length;
    final newCount = ref.watch(learnQueueProvider).asData?.value.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Onyx')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ready to study',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
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
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      (dueCount ?? 0) == 0 ? null : () => context.go('/quiz'),
                  icon: const Icon(Icons.school_outlined),
                  label: Text(
                    (dueCount ?? 0) == 0
                        ? 'Nothing to review'
                        : 'Review — $dueCount due',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed:
                      (newCount ?? 0) == 0 ? null : () => context.go('/learn'),
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: Text(
                    (newCount ?? 0) == 0
                        ? 'Nothing new to learn'
                        : 'Learn — $newCount new',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go('/browse'),
                  icon: const Icon(Icons.grid_view_outlined),
                  label: const Text('Browse cards'),
                ),
              ],
            ),
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
