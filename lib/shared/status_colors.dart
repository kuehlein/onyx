import 'design/_palette.dart';

/// Semantic status colors — a thin migration **shim** that forwards to the
/// design-system primitive palette, so raw hex lives in exactly one place
/// (`design/_palette.dart`). These `const` values remain for the many
/// non-`BuildContext` call sites (const contexts, static maps); prefer
/// **`context.onyx.*`** where a context is available. Migrated boy-scout, then
/// this file is deleted once unused (design-system §7). This is the one
/// sanctioned non-`design/` importer of the primitives, as a temporary bridge.
const statusGood = PaletteColor.good;
const statusWarn = PaletteColor.warn;
const statusBad = PaletteColor.bad;
const statusInfo = PaletteColor.info;
const statusMuted = PaletteColor.muted;
