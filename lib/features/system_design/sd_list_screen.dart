// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/system_design.dart';

/// The system-design practice track: the canonical design problems, ordered
/// weakest-first (never-mocked, then longest since last mock). Tap one to run a
/// mock interview. A mock is long (~40 min), so this is a browse-and-pick list,
/// not a daily due-count.
class SdListScreen extends ConsumerWidget {
  const SdListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final problems = ref.watch(systemDesignProblemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('System design')),
      body: problems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load problems: $e')),
        data: (cards) {
          if (cards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No system-design problems in the vault yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = cards[i];
              final tier = c.tiers['system-design'];
              return ListTile(
                leading: const Icon(Icons.architecture_outlined),
                title: Text(c.title),
                subtitle: i == 0
                    ? Text('Suggested next',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary))
                    : (tier != null ? Text('Tier $tier') : null),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/system-design/mock/${c.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
