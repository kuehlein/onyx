import 'package:flutter/material.dart';

/// The chrome (scannable UI) type scale → M3 [TextTheme] (design-system §2.2).
/// Only the roles Onyx uses; heights snapped to the 4pt grid; weight tops out at
/// 600 (bold-on-dark blooms for astigmatic readers). **Tabular figures on every
/// role** so counters / minutes / percentages don't jitter as they change.
///
/// Long-form *reading* styles live on `OnyxTokens` (`readTerm`/`readBody`), kept
/// out of the chrome theme so nobody reaches for `bodyLarge` inside a study
/// passage. Family is the platform sans (SF on iOS) — size/leading/measure are
/// what the spec names, never a bundled family.
final TextTheme onyxTextTheme = _chrome();

TextTheme _chrome() {
  const tab = [FontFeature.tabularFigures()];
  TextStyle s(double size, FontWeight weight, double height, double spacing) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        fontFeatures: tab,
      );

  const w600 = FontWeight.w600;
  const w400 = FontWeight.w400;

  return TextTheme(
    displaySmall:
        s(32, w600, 1.25, -0.5), // ring center %, big readiness number
    headlineSmall: s(24, w600, 1.33, -0.25), // sheet titles, hub heading
    titleLarge: s(20, w600, 1.40, 0), // AppBar title, goal name
    titleMedium: s(16, w600, 1.50, 0.1), // lane row name, group headers
    titleSmall: s(14, w600, 1.43, 0.1), // flow-row name, section labels
    bodyLarge: s(16, w400, 1.50, 0.15), // default body, sheet copy
    bodyMedium: s(14, w400, 1.43, 0.2), // secondary text, "~N min left"
    bodySmall: s(12, w400, 1.33, 0.3), // timestamps, "not enough data yet"
    labelLarge: s(14, w600, 1.43, 0.1), // button labels
    labelMedium: s(12, w600, 1.33, 0.5), // chips, badge text, KPI caption
    labelSmall: s(11, w600, 1.45, 0.5), // state-dot caption, tiny metadata
  );
}
