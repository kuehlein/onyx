import 'package:flutter/material.dart';

/// Onyx's Material 3 theme. Seeded from a deep violet so the palette reads as
/// "onyx" — near-black surfaces with a cool accent. Dark is the primary target
/// (study-at-night); light is derived from the same seed for system switches.
abstract final class OnyxTheme {
  static const _seed = Color(0xFF6B46C1);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
