import 'package:flutter/material.dart';

import '_palette.dart';

/// The dark [ColorScheme] — seeded for the long tail of M3 roles, then the ~20 we
/// control are pinned to the primitive palette (design-system §3.1). Neutral
/// surfaces (no violet tint), a single violet accent, and `secondaryContainer`
/// kept a faint violet tonal so tonal buttons stay a visible affordance (≥3:1 vs
/// card). `surfaceTint` is transparent to kill M3's automatic hue-wash on elevated
/// components — depth comes from the surface-container ladder, not a tint.
ColorScheme onyxDarkScheme() {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6B46C1),
    brightness: Brightness.dark,
  );
  return base.copyWith(
    primary: PaletteColor.v80,
    onPrimary: PaletteColor.onV,
    primaryContainer: PaletteColor.v40,
    onPrimaryContainer: PaletteColor.onVC,
    secondary: PaletteColor.ink70,
    onSecondary: PaletteColor.n10,
    secondaryContainer: PaletteColor.secondaryContainer,
    onSecondaryContainer: PaletteColor.onVC,
    surface: PaletteColor.n10,
    onSurface: PaletteColor.ink90,
    onSurfaceVariant: PaletteColor.ink70,
    surfaceContainerLowest: PaletteColor.n15,
    surfaceContainerLow: PaletteColor.n20,
    surfaceContainer: PaletteColor.n25,
    surfaceContainerHigh: PaletteColor.n30,
    surfaceContainerHighest: PaletteColor.n35,
    surfaceDim: PaletteColor.n05,
    surfaceBright: PaletteColor.n35,
    outline: PaletteColor.n60,
    outlineVariant: PaletteColor.n45,
    error: PaletteColor.bad,
    onError: PaletteColor.onError,
    errorContainer: PaletteColor.errorContainer,
    onErrorContainer: PaletteColor.onErrorContainer,
    surfaceTint: const Color(0x00000000), // transparent — no M3 hue-wash
    scrim: const Color(0xFF000000),
    inverseSurface: PaletteColor.ink90,
    onInverseSurface: PaletteColor.n15,
  );
}
