import 'package:flutter/material.dart';

import '../shared/design/onyx_design.dart';

/// Onyx's Material 3 theme. Seeded from a deep violet so the palette reads as
/// "onyx" — near-black surfaces with a cool accent. Dark is the primary target
/// (study-at-night); light is derived from the same seed for system switches.
///
/// Step 0 of the design-system adoption (design-system §7): the [OnyxColors] +
/// [OnyxTokens] extensions are registered here so `context.onyx`/`context.tokens`
/// resolve, but nothing consumes them yet — the app is byte-identical. Later steps
/// swap the seeded scheme for `onyxDarkScheme()`, add the chrome `TextTheme` +
/// component themes, and migrate widgets off literals.
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
      extensions: const [OnyxColors.dark, OnyxTokens.standard],
    );
  }
}
