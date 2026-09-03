/// Small pure helpers shared across core modules.
library;

/// A whole-number percentage (0–100) from a 0..1 fraction; clamps out-of-range.
int pct(double v) => (v.clamp(0, 1) * 100).round();

/// Look up an enum value by its `.name`, or null if [name] isn't a matching
/// String — the tolerant decoder used when reading enums back from JSON.
T? enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
