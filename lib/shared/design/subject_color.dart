import 'dart:ui' show Color;

import '_palette.dart';

/// Categorical **subject / track** colors (design-system §2). Distinct hues are
/// the *one sanctioned exception* to the single-accent rule: they let a learner
/// tell subjects and practice tracks apart at a glance (the lanes hub, Browse
/// tiles). They are always paired with the flow's icon + label upstream, never
/// color-only, and are tuned to the dark surface (the light ~200 band).
///
/// Like [StatusColor], this is a sanctioned importer of `_palette` — it lives in
/// `design/`, so the raw hex stays in exactly one place and features never spell
/// out `Colors.indigo` / `Colors.teal` themselves.
abstract final class SubjectColor {
  /// Maps a flow's `colorKey` (`FlowSpec.colorKey`) to its subject hue; an
  /// unknown or null key falls back to a neutral slate.
  static Color forKey(String? colorKey) => switch (colorKey) {
        'indigo' => PaletteColor.subjectIndigo,
        'teal' => PaletteColor.subjectTeal,
        'deepOrange' => PaletteColor.subjectDeepOrange,
        'purple' => PaletteColor.subjectPurple,
        'green' => PaletteColor.subjectGreen,
        _ => PaletteColor.subjectSlate,
      };
}
