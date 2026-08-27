import 'package:flutter/material.dart';

/// Wraps a scrollable and overlays a soft fade at the top/bottom edge whenever
/// there is more content in that direction. The fade makes it obvious that a
/// view scrolls — and stops a table (or any block) sitting at the viewport edge
/// from looking like the whole thing is in view.
///
/// The fade blends to the scaffold background, so content appears to dissolve
/// off the edge. Overlays ignore pointers, so scrolling/taps pass through.
class FadingScrollEdges extends StatefulWidget {
  const FadingScrollEdges({super.key, required this.child, this.extent = 36});

  final Widget child;

  /// Height of each fade gradient.
  final double extent;

  @override
  State<FadingScrollEdges> createState() => _FadingScrollEdgesState();
}

class _FadingScrollEdgesState extends State<FadingScrollEdges> {
  // Start hidden; the first scroll-metrics notification (fired on layout)
  // reveals whichever edge actually has overflow.
  bool _atTop = true;
  bool _atBottom = true;

  bool _onNotification(ScrollNotification notification) {
    final m = notification.metrics;
    if (!m.hasContentDimensions || m.axis != Axis.vertical) return false;
    final atTop = m.extentBefore <= 0.5;
    final atBottom = m.extentAfter <= 0.5;
    if (atTop != _atTop || atBottom != _atBottom) {
      setState(() {
        _atTop = atTop;
        _atBottom = atBottom;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onNotification,
          child: widget.child,
        ),
        _edge(top: true, visible: !_atTop, color: color),
        _edge(top: false, visible: !_atBottom, color: color),
      ],
    );
  }

  Widget _edge({
    required bool top,
    required bool visible,
    required Color color,
  }) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: visible ? 1 : 0,
          child: Container(
            height: widget.extent,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
