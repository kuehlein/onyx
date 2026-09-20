import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/shared/design/onyx_design.dart';

/// Guards the reduce-motion a11y contract: the `context.motionX` getters return
/// the design-token durations normally, but collapse to [Duration.zero] when the
/// OS "reduce motion" setting is on. Uses a bare Theme + MediaQuery (not
/// MaterialApp, which would inject its own MediaQuery from the test view and
/// clobber `disableAnimations`).
void main() {
  Future<BuildContext> pumpUnder(WidgetTester tester,
      {required bool disableAnimations}) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Theme(
          data: OnyxTheme.dark(),
          child: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ),
      ),
    );
    return ctx;
  }

  group('context motion getters', () {
    testWidgets('return the token durations when animations are enabled',
        (tester) async {
      final ctx = await pumpUnder(tester, disableAnimations: false);
      expect(ctx.reduceMotion, isFalse);
      expect(ctx.motionFast, ctx.tokens.motionFast);
      expect(ctx.motionBase, ctx.tokens.motionBase);
      expect(ctx.motionSlow, ctx.tokens.motionSlow);
      // Sanity: the tokens are non-zero, so the assertion above has teeth.
      expect(ctx.tokens.motionFast, greaterThan(Duration.zero));
    });

    testWidgets('collapse to zero when reduce-motion is on', (tester) async {
      final ctx = await pumpUnder(tester, disableAnimations: true);
      expect(ctx.reduceMotion, isTrue);
      expect(ctx.motionFast, Duration.zero);
      expect(ctx.motionBase, Duration.zero);
      expect(ctx.motionSlow, Duration.zero);
    });
  });
}
