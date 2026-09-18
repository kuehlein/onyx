import 'package:flutter/material.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/system_design.dart';
import 'sd_mock_screen.dart';

/// The System-design track entry. Like the Algorithms session, there's no
/// buffer/list page — spaced recurrence picks the problem due next and drops you
/// straight into the mock. (The full library of problems is browsable in Browse;
/// level/support are adjustable from the mock's tune action.)
///
/// It fixes the chosen problem **once** (on first load): grading a mock
/// invalidates the queue, and we must NOT swap the screen to a different problem
/// mid-session — you stay on this one until you leave.
class SdEntryScreen extends ConsumerStatefulWidget {
  const SdEntryScreen({super.key});

  @override
  ConsumerState<SdEntryScreen> createState() => _SdEntryScreenState();
}

class _SdEntryScreenState extends ConsumerState<SdEntryScreen> {
  String? _problemId;

  @override
  Widget build(BuildContext context) {
    // Once we've locked onto a problem, render it and ignore later queue changes.
    if (_problemId != null) return SdMockScreen(problemId: _problemId!);

    final problems = ref.watch(systemDesignProblemsProvider);
    return problems.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('System design')),
        body: EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load problems',
            message: '$e'),
      ),
      data: (cards) {
        if (cards.isEmpty) return const _EmptySd();
        // Lock onto the next-due problem after this frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _problemId = cards.first.id);
        });
        return const Scaffold(body: LoadingView());
      },
    );
  }
}

class _EmptySd extends StatelessWidget {
  const _EmptySd();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('System design')),
        body: const EmptyState(
          icon: Icons.architecture_outlined,
          title: 'Nothing to practice yet',
          message: 'No system-design problems in the vault yet.',
        ),
      );
}
