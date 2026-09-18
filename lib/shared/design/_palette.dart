/// PRIMITIVE design tokens — the single home of every raw value (design-system
/// §2). Flat, alias-free, pure data, grouped to mirror the DTCG token types
/// (color / dimension / number / duration).
///
/// **The door-open seam (ADR / design-system §2).** This grouping is deliberate:
/// if a non-Flutter surface (a marketing site / interactive deck repository) ever
/// needs to share the brand, these entries transcribe 1:1 into a DTCG JSON source
/// that a generator turns into Dart + CSS — a mechanical migration, not a rewrite.
/// To keep that true:
///   • only literal scalars — no expressions, no arithmetic, no cross-references;
///   • nothing imports this file except the semantic layer (onyx_colors /
///     onyx_tokens / theme) and `status_color.dart` (the const status surface for
///     `const` call sites); each lives in `design/` and adds nothing but `dart:ui`.
/// All *meaning* lives one layer up, in the two `ThemeExtension`s.
library;

import 'dart:ui';

/// DTCG `$type: color` — neutral surface ramp, off-white ink, one violet accent,
/// the meaning-only status ramp, and the error family. Contrast is verified in
/// design-system §2.1.
abstract final class PaletteColor {
  // Neutral surface ramp (off-black base #121417, ~+3–5% L* per step — tonal
  // elevation without shadows). Never #000 (halation).
  static const n05 = Color(0xFF0E1013);
  static const n10 = Color(0xFF121417);
  static const n15 = Color(0xFF171A1F);
  static const n20 = Color(0xFF1C1F25);
  static const n25 = Color(0xFF22262D);
  static const n30 = Color(0xFF292E36);
  static const n35 = Color(0xFF323841);
  static const n45 = Color(0xFF3C424C);
  static const n60 = Color(0xFF565D68);

  // Off-white ink ramp — never #FFF (halation).
  static const ink90 = Color(0xFFE7E9EC); // primary text (~13.5:1 on n10)
  static const ink70 = Color(0xFFAEB4BD); // secondary text (~7.2:1)
  static const ink55 = Color(0xFF8A9099); // dim informational state (~5.7:1)

  // Violet accent — one hue, pulled to the 200–300 band, desaturated ~25%.
  static const v80 = Color(0xFFC9B8F2); // primary / accent / fills (~9.8:1)
  static const v70 = Color(0xFFB39DEB); // hover/pressed accent
  static const v40 = Color(0xFF5B4A8C); // primaryContainer / tonal fill
  static const onV = Color(0xFF231737); // text on a light-violet Filled button
  static const onVC = Color(0xFFE4DAFB); // text on a tonal button
  static const secondaryContainer =
      Color(0xFF322C46); // faint violet tonal (affordance ≥3:1 vs card)

  // Status ramp (meaning-only — always paired with shape + label upstream).
  static const good = Color(0xFF4CC38A); // good / holding / pass / high
  static const warn = Color(0xFFE3B341); // developing / shaky / medium
  static const bad = Color(0xFFF0757C); // weak / lapsing / low (also `error`)
  static const info = Color(0xFF5AA7E6); // neutral progress / FSRS "Easy"
  static const muted = Color(0xFF8A9099); // no data / untouched / paused

  // Error family (error reuses `bad` so "error" and "weak" don't diverge).
  static const onError = Color(0xFF3A0E12);
  static const errorContainer = Color(0xFF5C2126);
  static const onErrorContainer = Color(0xFFFAD6D8);
}

/// DTCG `$type: dimension` — the 8pt grid (4pt half-step) + the radius scale, in
/// logical pixels.
abstract final class PaletteDim {
  // Spacing (8pt grid, 4pt half-step).
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;
  static const space7 = 48.0;

  // Radius.
  static const radiusChip = 8.0;
  static const radiusCard = 12.0;
  static const radiusSheet = 20.0;
  static const radiusFull = 999.0;

  // Reading type (the two long-form study styles; chrome sizes live in the
  // TextTheme). Sizes/leading only — weight/family are semantic.
  static const readTermSize = 22.0;
  static const readTermHeight = 1.30;
  static const readBodySize = 16.0;
  static const readBodyHeight = 1.50;
}

/// DTCG `$type: number` — opacities. `emphasisLow`/`fill`/`hairline` are the only
/// sanctioned alpha values; dim *state text* uses `PaletteColor.ink55`, never an
/// opacity (design-system §2.1 F2).
abstract final class PaletteOpacity {
  static const emphasisHigh = 0.87; // decoration only
  static const emphasisMed = 0.60; // decoration only
  static const emphasisLow =
      0.38; // decoration only (never for real state text)
  static const fill = 0.16; // status-pill tint
  static const hairline = 0.40; // status-pill / divider border
}

/// DTCG `$type: duration` — motion, in milliseconds. Calm register: short, few.
abstract final class PaletteMotion {
  static const fastMs = 150; // micro-feedback
  static const baseMs = 200; // default (reveal, expand, bar-fill)
  static const slowMs = 300; // full-surface (page/sheet transition)
}
