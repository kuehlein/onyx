import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '_palette.dart';

/// Non-color design tokens — spacing, radius, decoration opacities, motion, and
/// the two long-form reading text styles — carried on the theme. Values are
/// sourced from the primitive palette so raw numbers live in exactly one place
/// (design-system §2). Access via `context.tokens`.
///
/// Dark-locked: only [standard] is registered; [lerp] is implemented for smooth
/// future token tweaks. Convenience getters (`brCard`, `brChip`, …) keep call
/// sites literal-free.
@immutable
class OnyxTokens extends ThemeExtension<OnyxTokens> {
  const OnyxTokens({
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.space5,
    required this.space6,
    required this.space7,
    required this.radiusChip,
    required this.radiusCard,
    required this.radiusSheet,
    required this.radiusFull,
    required this.emphasisHigh,
    required this.emphasisMed,
    required this.emphasisLow,
    required this.fill,
    required this.hairline,
    required this.motionFast,
    required this.motionBase,
    required this.motionSlow,
    required this.easeStandard,
    required this.readTerm,
    required this.readBody,
  });

  final double space1, space2, space3, space4, space5, space6, space7;
  final double radiusChip, radiusCard, radiusSheet, radiusFull;

  /// Decoration-only opacities. Meaningful dim state text uses the `ink55` color,
  /// never [emphasisLow].
  final double emphasisHigh, emphasisMed, emphasisLow;

  /// Status-tint fill + border opacities.
  final double fill, hairline;

  final Duration motionFast, motionBase, motionSlow;

  /// The single easing curve (M3 standard already decelerates on enter).
  final Curve easeStandard;

  /// The two reading roles (kept off the chrome `TextTheme` so nobody reaches for
  /// `bodyLarge` inside a study passage).
  final TextStyle readTerm, readBody;

  static const standard = OnyxTokens(
    space1: PaletteDim.space1,
    space2: PaletteDim.space2,
    space3: PaletteDim.space3,
    space4: PaletteDim.space4,
    space5: PaletteDim.space5,
    space6: PaletteDim.space6,
    space7: PaletteDim.space7,
    radiusChip: PaletteDim.radiusChip,
    radiusCard: PaletteDim.radiusCard,
    radiusSheet: PaletteDim.radiusSheet,
    radiusFull: PaletteDim.radiusFull,
    emphasisHigh: PaletteOpacity.emphasisHigh,
    emphasisMed: PaletteOpacity.emphasisMed,
    emphasisLow: PaletteOpacity.emphasisLow,
    fill: PaletteOpacity.fill,
    hairline: PaletteOpacity.hairline,
    motionFast: Duration(milliseconds: PaletteMotion.fastMs),
    motionBase: Duration(milliseconds: PaletteMotion.baseMs),
    motionSlow: Duration(milliseconds: PaletteMotion.slowMs),
    easeStandard: Cubic(0.2, 0, 0, 1),
    readTerm: TextStyle(
      fontSize: PaletteDim.readTermSize,
      height: PaletteDim.readTermHeight,
      fontWeight: FontWeight.w600,
    ),
    readBody: TextStyle(
      fontSize: PaletteDim.readBodySize,
      height: PaletteDim.readBodyHeight,
      fontWeight: FontWeight.w400,
    ),
  );

  // ── Convenience (keep call sites literal-free) ─────────────────────────────
  BorderRadius get brChip => BorderRadius.circular(radiusChip);
  BorderRadius get brCard => BorderRadius.circular(radiusCard);
  BorderRadius get brSheet => BorderRadius.circular(radiusSheet);

  @override
  OnyxTokens copyWith({
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? space5,
    double? space6,
    double? space7,
    double? radiusChip,
    double? radiusCard,
    double? radiusSheet,
    double? radiusFull,
    double? emphasisHigh,
    double? emphasisMed,
    double? emphasisLow,
    double? fill,
    double? hairline,
    Duration? motionFast,
    Duration? motionBase,
    Duration? motionSlow,
    Curve? easeStandard,
    TextStyle? readTerm,
    TextStyle? readBody,
  }) =>
      OnyxTokens(
        space1: space1 ?? this.space1,
        space2: space2 ?? this.space2,
        space3: space3 ?? this.space3,
        space4: space4 ?? this.space4,
        space5: space5 ?? this.space5,
        space6: space6 ?? this.space6,
        space7: space7 ?? this.space7,
        radiusChip: radiusChip ?? this.radiusChip,
        radiusCard: radiusCard ?? this.radiusCard,
        radiusSheet: radiusSheet ?? this.radiusSheet,
        radiusFull: radiusFull ?? this.radiusFull,
        emphasisHigh: emphasisHigh ?? this.emphasisHigh,
        emphasisMed: emphasisMed ?? this.emphasisMed,
        emphasisLow: emphasisLow ?? this.emphasisLow,
        fill: fill ?? this.fill,
        hairline: hairline ?? this.hairline,
        motionFast: motionFast ?? this.motionFast,
        motionBase: motionBase ?? this.motionBase,
        motionSlow: motionSlow ?? this.motionSlow,
        easeStandard: easeStandard ?? this.easeStandard,
        readTerm: readTerm ?? this.readTerm,
        readBody: readBody ?? this.readBody,
      );

  @override
  OnyxTokens lerp(ThemeExtension<OnyxTokens>? other, double t) {
    if (other is! OnyxTokens) return this;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    Duration dur(Duration a, Duration b) => Duration(
        microseconds:
            lerpDouble(a.inMicroseconds, b.inMicroseconds, t)!.round());
    return OnyxTokens(
      space1: d(space1, other.space1),
      space2: d(space2, other.space2),
      space3: d(space3, other.space3),
      space4: d(space4, other.space4),
      space5: d(space5, other.space5),
      space6: d(space6, other.space6),
      space7: d(space7, other.space7),
      radiusChip: d(radiusChip, other.radiusChip),
      radiusCard: d(radiusCard, other.radiusCard),
      radiusSheet: d(radiusSheet, other.radiusSheet),
      radiusFull: d(radiusFull, other.radiusFull),
      emphasisHigh: d(emphasisHigh, other.emphasisHigh),
      emphasisMed: d(emphasisMed, other.emphasisMed),
      emphasisLow: d(emphasisLow, other.emphasisLow),
      fill: d(fill, other.fill),
      hairline: d(hairline, other.hairline),
      motionFast: dur(motionFast, other.motionFast),
      motionBase: dur(motionBase, other.motionBase),
      motionSlow: dur(motionSlow, other.motionSlow),
      easeStandard: t < 0.5 ? easeStandard : other.easeStandard,
      readTerm: TextStyle.lerp(readTerm, other.readTerm, t)!,
      readBody: TextStyle.lerp(readBody, other.readBody, t)!,
    );
  }
}
