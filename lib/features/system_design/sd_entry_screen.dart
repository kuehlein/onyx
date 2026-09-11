import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/system_design.dart';
import 'sd_mock_screen.dart';

/// The System-design track entry. Like the Algorithms session, there's no
/// buffer/list page — spaced recurrence picks the problem due next and drops you
/// straight into the mock. (The full library of problems is browsable in Browse;
/// level/support are adjustable from the mock's tune action.)
class SdEntryScreen extends ConsumerWidget {
  const SdEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final problems = ref.watch(systemDesignProblemsProvider);
    return problems.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('System design')),
        body: Center(child: Text('Could not load problems: $e')),
      ),
      data: (cards) => cards.isEmpty
          ? const _EmptySd()
          : SdMockScreen(problemId: cards.first.id),
    );
  }
}

class _EmptySd extends StatelessWidget {
  const _EmptySd();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('System design')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No system-design problems in the vault yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
