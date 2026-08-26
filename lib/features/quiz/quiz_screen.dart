import 'package:flutter/material.dart';

/// Study session. Placeholder until the FSRS scheduler and section-level review
/// flow are wired in (task: study loop).
class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Study loop coming soon'),
          ],
        ),
      ),
    );
  }
}
