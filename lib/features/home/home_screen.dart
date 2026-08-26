import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/vault.dart';

/// Landing screen. For now it surfaces the index status (how many cards were
/// parsed, and any diagnostics) and links into study. The daily-review queue
/// lands here once the scheduler exists.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final index = ref.watch(vaultIndexProvider);

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
                        : '${r.cardCount} cards indexed',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/quiz'),
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Start a session'),
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
