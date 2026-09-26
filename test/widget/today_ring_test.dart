import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/features/home/today_ring.dart';

/// The Home hero ring eases its fill in via `context.motionBase` (design-system
/// "bar-fill"), which is pre-gated on reduce-motion → an instant jump. A bare
/// MediaQuery + Theme (not MaterialApp, which injects its own MediaQuery and
/// clobbers `disableAnimations`).
void main() {
  Widget ring({required bool disableAnimations}) => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Theme(
            data: OnyxTheme.dark(),
            child: const TodayRing(
                fraction: 1.0, centerLine: '2 / 4', subLine: '~10 min left'),
          ),
        ),
      );

  testWidgets('eases its fill in when motion is enabled', (tester) async {
    await tester.pumpWidget(ring(disableAnimations: false));
    // The fill is mid-animation, so there are still frames to settle.
    final frames = await tester.pumpAndSettle();
    expect(frames, greaterThan(1));
    // Content is unaffected by the fill animation.
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('~10 min left'), findsOneWidget);
  });

  testWidgets('jumps instantly under reduce-motion (nothing to settle)',
      (tester) async {
    await tester.pumpWidget(ring(disableAnimations: true));
    // Zero-duration tween → already settled on the first frame.
    expect(await tester.pumpAndSettle(), 1);
    expect(find.text('2 / 4'), findsOneWidget);
  });
}
