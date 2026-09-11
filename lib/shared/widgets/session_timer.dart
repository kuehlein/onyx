import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../status_colors.dart';

/// Which way a [SessionTimer] runs.
enum TimerMode {
  /// Counts up from zero — a stopwatch. Used to measure how long an answer
  /// takes (e.g. a system-design mock, where the candidate talks via STT so the
  /// AI can't time them). Open-ended: no "done" state.
  countUp,

  /// Counts down from a fixed duration to zero, buzzing (haptics) at zero. Used
  /// for Gym-mode rest between sets.
  countDown,
}

/// A compact, tap-to-control session timer shared across practice tracks. It
/// sits under the app bar without crowding the content.
///
/// * [TimerMode.countDown] reproduces the Gym rest timer: tap to start the
///   countdown, it buzzes and shows [doneLabel] at zero, tap to reset.
/// * [TimerMode.countUp] is a stopwatch: tap to start, it counts up, tap to
///   reset. [onTick] reports the current elapsed/remaining seconds each second
///   (and on reset) so a parent can record how long the answer took.
class SessionTimer extends StatefulWidget {
  const SessionTimer({
    super.key,
    this.mode = TimerMode.countDown,
    this.durationSeconds = 0,
    this.idleLabel = 'Timer',
    this.idleHint = 'tap to start',
    this.runningHint = 'tap to reset',
    this.doneLabel = 'Done',
    this.doneIcon = Icons.check,
    this.runningIcon = Icons.timer_outlined,
    this.onTick,
  }) : assert(mode == TimerMode.countUp || durationSeconds > 0,
            'countDown needs a positive durationSeconds');

  final TimerMode mode;

  /// Countdown length in seconds (ignored for [TimerMode.countUp]).
  final int durationSeconds;

  final String idleLabel;
  final String idleHint;
  final String runningHint;

  /// Shown when a countdown reaches zero (unused for count-up).
  final String doneLabel;
  final IconData doneIcon;
  final IconData runningIcon;

  /// Fires each second while running, and once on reset, with the current
  /// value: elapsed seconds for count-up, remaining seconds for count-down.
  final ValueChanged<int>? onTick;

  @override
  State<SessionTimer> createState() => _SessionTimerState();
}

class _SessionTimerState extends State<SessionTimer> {
  Timer? _ticker;
  int _seconds = 0;
  bool _running = false;
  bool _done = false;

  bool get _isCountUp => widget.mode == TimerMode.countUp;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _ticker?.cancel();
    setState(() {
      _seconds = _isCountUp ? 0 : widget.durationSeconds;
      _running = true;
      _done = false;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isCountUp) {
        setState(() => _seconds++);
        widget.onTick?.call(_seconds);
      } else if (_seconds <= 1) {
        _ticker?.cancel();
        HapticFeedback.heavyImpact();
        setState(() {
          _seconds = 0;
          _running = false;
          _done = true;
        });
        widget.onTick?.call(0);
      } else {
        setState(() => _seconds--);
        widget.onTick?.call(_seconds);
      }
    });
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _done = false;
      _seconds = 0;
    });
    widget.onTick?.call(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const green = statusGood;
    final scheme = theme.colorScheme;

    final (label, color, icon) = _done
        ? (widget.doneLabel, green, widget.doneIcon)
        : _running
            ? (_fmt(_seconds), scheme.primary, widget.runningIcon)
            : (widget.idleLabel, scheme.onSurfaceVariant, widget.runningIcon);

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
              Text(_running ? widget.runningHint : widget.idleHint,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  /// `m:ss` once past a minute, else `Ns`.
  static String _fmt(int s) {
    final m = s ~/ 60;
    final rem = s % 60;
    return m > 0 ? '$m:${rem.toString().padLeft(2, '0')}' : '${rem}s';
  }
}
