import 'package:flutter/material.dart';

import 'onyx_colors.dart';
import 'onyx_tokens.dart';

/// Ergonomic access to the design system from a [BuildContext]. Call sites use
/// `context.onyx` / `context.tokens` / `context.colors` / `context.text` — never
/// `Theme.of(context).extension<...>()!` noise, and never a hardcoded
/// hex / radius / gap / duration (design-system §3.4/§6).
extension OnyxContext on BuildContext {
  /// Semantic status colors ([OnyxColors]).
  OnyxColors get onyx => Theme.of(this).extension<OnyxColors>()!;

  /// Spacing / radius / opacity / motion / reading styles ([OnyxTokens]).
  /// Falls back to [OnyxTokens.standard] if the extension is somehow absent —
  /// the tokens are dark-locked constants (the same value the theme installs),
  /// so this can't be wrong, and it keeps `context.tokens` from throwing under a
  /// bare test theme.
  OnyxTokens get tokens =>
      Theme.of(this).extension<OnyxTokens>() ?? OnyxTokens.standard;

  /// Whether the OS "reduce motion" accessibility setting is on. When true,
  /// discretionary animations should collapse to [Duration.zero] — the motion
  /// getters below already do this, so prefer them at animation call sites.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// Motion durations from [OnyxTokens], pre-gated on [reduceMotion] (→ zero).
  /// Use these instead of raw `tokens.motionX` so the OS reduce-motion setting
  /// is always honored (a11y; design-system §6). `animateTo`/`ensureVisible`
  /// treat a zero duration as an instant jump, so these are safe there too.
  Duration get motionFast => reduceMotion ? Duration.zero : tokens.motionFast;
  Duration get motionBase => reduceMotion ? Duration.zero : tokens.motionBase;
  Duration get motionSlow => reduceMotion ? Duration.zero : tokens.motionSlow;

  /// The M3 [ColorScheme] (brand + surface roles).
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// The chrome [TextTheme].
  TextTheme get text => Theme.of(this).textTheme;
}
