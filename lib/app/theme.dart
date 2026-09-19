import 'package:flutter/material.dart';

import '../shared/design/onyx_design.dart';

/// Onyx's Material 3 theme — calm, dark-locked. Assembled from the design system:
/// [onyxDarkScheme] (the surface-container ladder + one violet accent),
/// [onyxTextTheme] (the chrome scale), component themes tuned to the token radii /
/// touch targets, and the two `ThemeExtension`s. `surfaceTint` is transparent, so
/// depth reads as a lighter surface rather than an M3 hue-wash. The app is pinned
/// to dark (`ThemeMode.dark`); [light] is a dead stub.
abstract final class OnyxTheme {
  static ThemeData dark() {
    final scheme = onyxDarkScheme();
    const t = OnyxTokens.standard;
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: onyxTextTheme,
      extensions: const [OnyxColors.dark, OnyxTokens.standard],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48), // 48dp touch target
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusCard)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusCard)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      cardTheme: CardThemeData(
        elevation: 0, // tonal elevation, no shadow
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusCard)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusChip)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        elevation: 0,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(t.radiusSheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusSheet)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(t.radiusCard)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Dim.space4, vertical: Dim.space3),
      ),
      // (Page transitions use Flutter's M3 defaults; a Cupertino-on-iOS override
      // is a later polish — it needs the cupertino import.)
    );
  }

  /// Dark-locked: the app always uses [dark] (`ThemeMode.dark`). This stub keeps
  /// `MaterialApp.theme` valid and ships no tuned light values (design-system §3.3).
  static ThemeData light() => dark();
}
