import 'package:flutter/painting.dart';

import '_palette.dart';

/// The recessed code-panel surface + its plain ink (design-system §2.5 tier 1 /
/// §5 critique F7): code renders on `surfaceContainerLow` — *below* the app's
/// resting surface, not raised — which also lifts every token's contrast above
/// AA. Exposed as named consts so `code_block.dart` reads the panel/ink from the
/// palette with no hardcoded hex fallback.
const Color onyxCodePanel = PaletteColor.n20; // surfaceContainerLow (recessed)
const Color onyxCodeInk = PaletteColor.ink90; // plain code text

/// Onyx's syntax-highlight theme for `flutter_highlight` — a **calm** map: only
/// the five categories the eye needs to parse code are colored, everything else
/// inherits the plain [onyxCodeInk]. Sourced entirely from the primitive palette
/// so a restyle stays one-place (design-system §5):
///   • **keyword** → the violet accent (echoes the app's one hue)
///   • **string** → `good` · **number/literal** → `warn` · **type/class** → `info`
///     (the meaning ramp)
///   • **comment** → the dim ink `ink55` (≈4.8:1 on the panel — clears AA)
///   • diff **addition/deletion** → `good`/`bad`
const Map<String, TextStyle> onyxCodeTheme = {
  'root': TextStyle(backgroundColor: onyxCodePanel, color: onyxCodeInk),
  'comment': TextStyle(color: PaletteColor.ink55, fontStyle: FontStyle.italic),
  'quote': TextStyle(color: PaletteColor.ink55, fontStyle: FontStyle.italic),
  'keyword': TextStyle(color: PaletteColor.v80),
  'selector-tag': TextStyle(color: PaletteColor.v80),
  'section': TextStyle(color: PaletteColor.v80),
  'string': TextStyle(color: PaletteColor.good),
  'regexp': TextStyle(color: PaletteColor.good),
  'addition': TextStyle(color: PaletteColor.good),
  'number': TextStyle(color: PaletteColor.warn),
  'literal': TextStyle(color: PaletteColor.warn),
  'built_in': TextStyle(color: PaletteColor.info),
  'type': TextStyle(color: PaletteColor.info),
  'class': TextStyle(color: PaletteColor.info),
  'attr': TextStyle(color: PaletteColor.info),
  'attribute': TextStyle(color: PaletteColor.info),
  'meta': TextStyle(color: PaletteColor.ink70),
  'deletion': TextStyle(color: PaletteColor.bad),
};
