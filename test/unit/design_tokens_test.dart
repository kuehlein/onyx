import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/shared/design/onyx_design.dart';

/// The design-token foundation (design-system Step 0): the theme registers the two
/// extensions, and the semantic layer resolves through them.

void main() {
  group('design tokens', () {
    test('the dark theme registers OnyxColors + OnyxTokens', () {
      final theme = OnyxTheme.dark();
      expect(theme.extension<OnyxColors>(), isNotNull);
      expect(theme.extension<OnyxTokens>(), isNotNull);
    });

    test('OnyxColors.grade maps FSRS ratings to status colors', () {
      const c = OnyxColors.dark;
      expect(c.grade(1), c.bad); // Again
      expect(c.grade(2), c.warn); // Hard
      expect(c.grade(3), c.good); // Good
      expect(c.grade(4), c.info); // Easy
      expect(c.grade(0), c.muted); // unknown → muted
    });

    test('tokens expose the 8pt grid + radius scale + convenience getters', () {
      const t = OnyxTokens.standard;
      expect(t.space4, 16);
      expect(t.radiusCard, 12);
      expect(t.brCard, BorderRadius.circular(12));
    });

    test('copyWith overrides one field, keeps the rest', () {
      final t = OnyxTokens.standard.copyWith(space4: 20);
      expect(t.space4, 20);
      expect(t.space2, OnyxTokens.standard.space2);
    });

    test('lerp to self is the identity (dark-locked)', () {
      const t = OnyxTokens.standard;
      expect(t.lerp(t, 0.5).space4, t.space4);
      expect(t.lerp(t, 0.5).motionBase, t.motionBase);
      const c = OnyxColors.dark;
      expect(c.lerp(c, 0.5).good, c.good);
    });
  });
}
