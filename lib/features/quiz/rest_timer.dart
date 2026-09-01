import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A between-sets rest countdown for Gym mode. Tap to start after racking the
/// weight; it counts down and buzzes (haptics) at zero — "Next set". You review
/// cards while it runs. Compact, so it sits under the app bar without crowding
/// the review.
class RestTimer extends StatefulWidget {
  const RestTimer({super.key, required this.restSeconds});

  final int restSeconds;

  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> {
  Timer? _ticker;
  int _remaining = 0;
  bool _running = false;
  bool _done = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _ticker?.cancel();
    setState(() {
      _remaining = widget.restSeconds;
      _running = true;
      _done = false;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _ticker?.cancel();
        HapticFeedback.heavyImpact();
        setState(() {
          _remaining = 0;
          _running = false;
          _done = true;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _done = false;
      _remaining = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const green = Color(0xFF4CC38A);
    final scheme = theme.colorScheme;

    final (label, color, icon) = _done
        ? ('Next set', green, Icons.fitness_center)
        : _running
            ? (_fmt(_remaining), scheme.primary, Icons.timer_outlined)
            : ('Rest timer', scheme.onSurfaceVariant, Icons.timer_outlined);

    return Material(
      color: _done
          ? green.withValues(alpha: 0.15)
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _running ? _reset : _start,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label,
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: 8),
              Text(_running ? 'tap to reset' : 'tap to start',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final rem = s % 60;
    return m > 0 ? '$m:${rem.toString().padLeft(2, '0')}' : '${rem}s';
  }
}
