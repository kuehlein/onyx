import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/srs.dart';
import '../../shared/providers/vault.dart';

/// Landing screen: how many sections are ready to review, and the way into a
/// session.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final index = ref.watch(vaultIndexProvider);
    final queue = ref.watch(reviewQueueProvider);
    final dueCount = queue.asData?.value.queue.length;

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
                        : dueCount == null
                            ? '${r.cardCount} cards indexed'
                            : dueCount == 0
                                ? 'All caught up — nothing due'
                                : '$dueCount section${dueCount == 1 ? '' : 's'} to review',
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
                        ? 'Nothing to study'
                        : 'Start a session',
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
}
