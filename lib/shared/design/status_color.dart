import 'dart:ui' show Color;

import '_palette.dart';

/// Semantic **status** colors as compile-time constants (design-system §2/§6):
/// the one const surface for the four-tone status ramp — positive / attention /
/// danger / info — plus a muted null-state, each sourced from the primitive
/// [PaletteColor] so raw hex still lives in exactly one place.
///
/// Use these at **`const` call sites**: top-level `const` data tables (the grade
/// scale, callout specs, outcome lists), static maps, and pure color helpers
/// with no `BuildContext`. Where a widget is building *with* a context and wants
/// the lerp-able, theme-swappable form, prefer the `OnyxColors` ThemeExtension
/// via `context.onyx.good` — both resolve to the same palette entry today (the
/// app is dark-locked, so the distinction is future-proofing, not a live diff).
///
/// Like the two extensions, this is a sanctioned importer of `_palette`: it
/// lives in `design/`, so the primitive table stays encapsulated from features.
/// (Replaces the old `shared/status_colors.dart` migration shim — §7 Step 7.)
abstract final class StatusColor {
  /// Positive / on-track (green).
  static const Color good = PaletteColor.good;

  /// Attention / caution (amber).
  static const Color warn = PaletteColor.warn;

  /// Danger / failing (red).
  static const Color bad = PaletteColor.bad;

  /// Informational / neutral-positive (blue).
  static const Color info = PaletteColor.info;

  /// Muted / not-enough-data (grey).
  static const Color muted = PaletteColor.muted;

  /// Modal / overlay scrim — black at ~0.45 (design-system §4.9). A chrome
  /// constant, not a status; here so no widget hardcodes the hex.
  static const Color scrim = PaletteColor.scrim;

  /// Admonition-only callout accents (violet / cyan) — outside the
  /// one-accent-hue rule pending a design call. Not statuses.
  static const Color calloutViolet = PaletteColor.calloutViolet;
  static const Color calloutCyan = PaletteColor.calloutCyan;
}
