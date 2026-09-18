import 'package:flutter/material.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/behavioral.dart';
import 'behavioral_mock_screen.dart';

/// The Behavioral track entry. Like the System-design and Algorithms sessions,
/// there's no buffer/list page — spaced recurrence picks the competency due next
/// and drops you straight into the mock. (All competencies are browsable in
/// Browse; level/support are adjustable from the mock's tune action.)
///
/// It fixes the chosen competency **once** (on first load): grading a mock
/// invalidates the queue, and we must NOT swap the screen mid-session.
class BehavioralEntryScreen extends ConsumerStatefulWidget {
  const BehavioralEntryScreen({super.key});

  @override
  ConsumerState<BehavioralEntryScreen> createState() =>
      _BehavioralEntryScreenState();
}

class _BehavioralEntryScreenState extends ConsumerState<BehavioralEntryScreen> {
  String? _competencyId;

  @override
  Widget build(BuildContext context) {
    if (_competencyId != null) {
      return BehavioralMockScreen(competencyId: _competencyId!);
    }

    final competencies = ref.watch(behavioralCompetenciesProvider);
    return competencies.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Behavioral')),
        body: EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load competencies',
            message: '$e'),
      ),
      data: (cards) {
        if (cards.isEmpty) return const _EmptyBehavioral();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _competencyId = cards.first.id);
        });
        return const Scaffold(body: LoadingView());
      },
    );
  }
}

class _EmptyBehavioral extends StatelessWidget {
  const _EmptyBehavioral();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Behavioral')),
        body: const EmptyState(
          icon: Icons.forum_outlined,
          title: 'Nothing to practice yet',
          message: 'No behavioral competencies in the vault yet.',
        ),
      );
}
