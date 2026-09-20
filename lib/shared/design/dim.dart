import 'package:flutter/painting.dart' show BorderRadius, Radius;

import '_palette.dart';

/// Const dimension tokens — the compile-time twin of [OnyxTokens]
/// (`context.tokens`), for the many spacing / radius / opacity call sites that
/// are (and should stay) `const`. Mirrors the StatusColor ↔ `context.onyx`
/// split: use **`Dim`** at const call sites (the common case for a fixed grid);
/// use **`context.tokens`** where you genuinely need the lerp-able / theme form
/// (or the motion + reading-text tokens, which only live there).
///
/// Single-sourced from [PaletteDim] / [PaletteOpacity] — exactly like
/// `OnyxTokens.standard` — so a grid change in the primitive table propagates to
/// both surfaces (a guard test asserts they stay equal). Dimensions are
/// dark-locked and fixed by design, so a const surface loses nothing
/// (design-system §2; theme/text-scale accessibility lives on the color scheme
/// and MediaQuery, never on these).
abstract final class Dim {
  // Spacing — the 8pt grid (4pt half-step).
  static const double space1 = PaletteDim.space1; // 4
  static const double space2 = PaletteDim.space2; // 8
  static const double space3 = PaletteDim.space3; // 12
  static const double space4 = PaletteDim.space4; // 16
  static const double space5 = PaletteDim.space5; // 24
  static const double space6 = PaletteDim.space6; // 32
  static const double space7 = PaletteDim.space7; // 48

  // Radius — raw scalars…
  static const double radiusChip = PaletteDim.radiusChip; // 8
  static const double radiusCard = PaletteDim.radiusCard; // 12
  static const double radiusSheet = PaletteDim.radiusSheet; // 20
  static const double radiusFull = PaletteDim.radiusFull; // 999

  // …and the ready-made BorderRadius forms (the common call site).
  static const BorderRadius brChip =
      BorderRadius.all(Radius.circular(PaletteDim.radiusChip));
  static const BorderRadius brCard =
      BorderRadius.all(Radius.circular(PaletteDim.radiusCard));
  static const BorderRadius brSheet =
      BorderRadius.all(Radius.circular(PaletteDim.radiusSheet));
  static const BorderRadius brFull =
      BorderRadius.all(Radius.circular(PaletteDim.radiusFull));

  // Decoration opacities (never for real state text — see PaletteOpacity).
  static const double fill = PaletteOpacity.fill; // 0.16 — status-tint fill
  static const double hairline = PaletteOpacity.hairline; // 0.40 — tint border
  static const double emphasisHigh = PaletteOpacity.emphasisHigh; // 0.87
  static const double emphasisMed = PaletteOpacity.emphasisMed; // 0.60
  static const double emphasisLow = PaletteOpacity.emphasisLow; // 0.38

  // Content column max-widths — the reading "measure". Long-form text and forms
  // are capped rather than run full-bleed so lines stay readable on wide screens
  // (design-system: the measure is a first-class layout constraint). These are
  // Dim-only (fixed layout caps, not theme-swappable), so they have no
  // OnyxTokens twin.
  static const double maxContentWidth =
      640; // full-screen session / reading body
  static const double maxNarrowWidth = 480; // home + compact screens & sheets
  static const double maxCompactWidth =
      440; // centered complete / welcome cards
}
