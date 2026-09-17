import 'package:flutter/material.dart';

import '_palette.dart';

/// Semantic status colors carried on the theme, *outside* the M3 [ColorScheme]
/// (they encode meaning, not brand). Every status pairs color + shape + label
/// upstream — see design-system §2.1/§4.1. Access via `context.onyx`.
///
/// Values are sourced from the primitive palette so raw hex lives in exactly one
/// place. Dark-locked: only [dark] is registered today; [lerp] is implemented so
/// a future accent tweak animates smoothly.
@immutable
class OnyxColors extends ThemeExtension<OnyxColors> {
  const OnyxColors({
    required this.good,
    required this.warn,
    required this.bad,
    required this.info,
    required this.muted,
  });

  final Color good;
  final Color warn;
  final Color bad;
  final Color info;
  final Color muted;

  static const dark = OnyxColors(
    good: PaletteColor.good,
    warn: PaletteColor.warn,
    bad: PaletteColor.bad,
    info: PaletteColor.info,
    muted: PaletteColor.muted,
  );

  /// FSRS grade → status color: 1 Again→bad, 2 Hard→warn, 3 Good→good,
  /// 4 Easy→info; anything else → muted. The one place grade coloring is defined.
  Color grade(int rating) => switch (rating) {
        1 => bad,
        2 => warn,
        3 => good,
        4 => info,
        _ => muted,
      };

  @override
  OnyxColors copyWith({
    Color? good,
    Color? warn,
    Color? bad,
    Color? info,
    Color? muted,
  }) =>
      OnyxColors(
        good: good ?? this.good,
        warn: warn ?? this.warn,
        bad: bad ?? this.bad,
        info: info ?? this.info,
        muted: muted ?? this.muted,
      );

  @override
  OnyxColors lerp(ThemeExtension<OnyxColors>? other, double t) {
    if (other is! OnyxColors) return this;
    return OnyxColors(
      good: Color.lerp(good, other.good, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      info: Color.lerp(info, other.info, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}
