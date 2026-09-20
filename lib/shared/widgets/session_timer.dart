import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/onyx_design.dart';

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
  bool _running = false; // ticker active
  bool _started = false; // count-up: has begun (distinguishes idle from paused)
  bool _done = false;

  bool get _isCountUp => widget.mode == TimerMode.countUp;
  bool get _paused => _isCountUp && _started && !_running;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
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

  void _start() {
    setState(() {
      _seconds = _isCountUp ? 0 : widget.durationSeconds;
      _running = true;
      _started = true;
      _done = false;
    });
    _startTicker();
  }

  // Count-up only: pause keeps the elapsed time; resume continues from it.
  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _resume() {
    setState(() => _running = true);
    _startTicker();
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _started = false;
      _done = false;
      _seconds = 0;
    });
    widget.onTick?.call(0);
  }

  void _onTap() {
    if (_isCountUp) {
      if (!_started) {
        _start();
      } else if (_running) {
        _pause();
      } else {
        _resume();
      }
    } else {
      _running ? _reset() : _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const green = StatusColor.good;
    final scheme = theme.colorScheme;

    final bool showElapsed = _isCountUp ? _started : _running;
    final (label, color, icon) = _done
        ? (widget.doneLabel, green, widget.doneIcon)
        : showElapsed
            ? (
                _fmt(_seconds),
                _paused ? scheme.onSurfaceVariant : scheme.primary,
                _paused ? Icons.pause_circle_outline : widget.runningIcon,
              )
            : (widget.idleLabel, scheme.onSurfaceVariant, widget.runningIcon);

    final String hint;
    if (_isCountUp) {
      hint = !_started
          ? widget.idleHint
          : _running
              ? 'tap to pause'
              : 'tap to resume';
    } else {
      hint = _running ? widget.runningHint : widget.idleHint;
    }

    return Material(
      color: _done
          ? green.withValues(alpha: Dim.fill)
          : scheme.surfaceContainerHighest,
      borderRadius: Dim.brCard,
      child: InkWell(
        borderRadius: Dim.brCard,
        onTap: _onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Dim.space3, vertical: Dim.space2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: Dim.space2),
              Text(label,
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: Dim.space2),
              Text(hint,
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
