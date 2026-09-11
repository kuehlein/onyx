// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/card.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/system_design.dart';
import '../../shared/status_colors.dart';

/// The system-design practice track: the scheduled queue of mock interviews,
/// ordered by spaced recurrence (due re-mocks first, then never-mocked, then
/// upcoming). This is the "what to practise next" queue — the full library of
/// problems is browsable in Browse, so this isn't a second browser.
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
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (var i = 0; i < cards.length; i++)
                _ProblemTile(card: cards[i], suggested: i == 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Ordered by when each is due to re-practise. Browse the full '
                  'library of problems in Browse.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One problem row, showing its spaced-recurrence status (Due / New / in Nd).
class _ProblemTile extends ConsumerWidget {
  const _ProblemTile({required this.card, required this.suggested});

  final Card card;
  final bool suggested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final due = ref.watch(systemDesignDueProvider(card.id)).asData?.value;
    final now = ref.watch(clockProvider).asData?.value.now();

    final (String status, Color color) = _status(due, now);

    return ListTile(
      leading: const Icon(Icons.architecture_outlined),
      title: Text(card.title),
      subtitle: suggested
          ? Text('Suggested next · $status',
              style: theme.textTheme.bodySmall?.copyWith(color: color))
          : Text(status,
              style: theme.textTheme.bodySmall?.copyWith(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/system-design/mock/${card.id}'),
    );
  }

  (String, Color) _status(DateTime? due, DateTime? now) {
    if (due == null) return ('New', statusInfo);
    if (now == null) return ('Scheduled', Colors.grey);
    final diff = due.difference(now).inDays;
    if (!due.isAfter(now)) return ('Due to re-practise', statusWarn);
    if (diff == 0) return ('Due today', statusWarn);
    return ('Next in ${diff}d', Colors.grey);
  }
}
