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
  OnyxTokens get tokens => Theme.of(this).extension<OnyxTokens>()!;

  /// The M3 [ColorScheme] (brand + surface roles).
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// The chrome [TextTheme].
  TextTheme get text => Theme.of(this).textTheme;
}
