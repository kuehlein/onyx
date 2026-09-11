import 'package:flutter/material.dart';

import '../../shared/widgets/session_timer.dart';

/// A between-sets rest countdown for Gym mode. Tap to start after racking the
/// weight; it counts down and buzzes (haptics) at zero — "Next set". You review
/// cards while it runs. A thin wrapper over the shared [SessionTimer]
/// (count-down mode) so the timer logic lives in one place.
class RestTimer extends StatelessWidget {
  const RestTimer({super.key, required this.restSeconds});

  final int restSeconds;

  @override
  Widget build(BuildContext context) => SessionTimer(
        mode: TimerMode.countDown,
        durationSeconds: restSeconds,
        idleLabel: 'Rest timer',
        doneLabel: 'Next set',
        doneIcon: Icons.fitness_center,
      );
}
