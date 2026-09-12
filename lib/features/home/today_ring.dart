import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/status_colors.dart';

/// The Home hero: a single radial ring for today's progress. One glanceable,
/// motivating "close the ring" metric (the day's small wins), with the details
/// (per-domain, forecasts) deliberately left to the Insights page.
class TodayRing extends StatelessWidget {
  const TodayRing({
    super.key,
    required this.fraction,
    required this.centerLine,
    required this.subLine,
    this.done = false,
    this.size = 168,
  });

  /// 0..1 fill.
  final double fraction;

  /// Big center text (e.g. "2 / 4"), or empty when [done] shows a check instead.
  final String centerLine;

  /// Small caption under the center line (e.g. "~48 min left").
  final String subLine;

  /// When true, the ring reads as complete (full, warm colour, check mark).
  final bool done;

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ringColor = done ? statusGood : cs.primary;

    return Semantics(
      label: 'Today’s progress: $centerLine, $subLine',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: done ? 1 : fraction.clamp(0.0, 1.0),
            color: ringColor,
            track: cs.surfaceContainerHighest,
            stroke: size * 0.075,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (done)
                  Icon(Icons.check_rounded, size: size * 0.3, color: ringColor)
                else
                  Text(centerLine,
                      style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(subLine,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (fraction <= 0) return;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    const start = -math.pi / 2; // 12 o'clock
    canvas.drawArc(rect, start, 2 * math.pi * fraction, false, progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
