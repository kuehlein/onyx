/// The ONE query language over the vault — behind both deck membership (a saved
/// *lens*) and Browse filtering (ADR-0013). A `CardQuery` is a boolean tree: leaf
/// predicates over card attributes, composed with `And` / `Or` / `Not`.
///
/// This is the growable IR. G1 lands the spine + the three structural leaves that
/// deck membership already uses ([Everything], [TagIs], [FolderUnder]) — folding
/// in the former `MembershipQuery` byte-for-byte. Browse's richer leaves (type /
/// tier / free-text / study-state) and the boolean combinators arrive with their
/// consumers in G2/G3, so exhaustive `switch`es over a lens only face shapes the
/// UI can already render.
///
/// Deck lenses are **structural only** (stable member set for readiness/plan/
/// analytics); dynamic study-state stays a Browse-only filter (ADR-0013).
library;

import '../../shared/models/card.dart';

sealed class CardQuery {
  const CardQuery();

  /// Whether [card] matches. Structural leaves read card attributes only.
  bool matches(Card card);

  Map<String, dynamic> toJson();

  /// The whole vault — a lens with no constraint. The canonical "match anything"
  /// node; serializes as the legacy `{'kind': 'all'}` so existing decks' JSON is
  /// unchanged on re-save.
  static const CardQuery everything = Everything();

  /// Rebuilds a query from its JSON. Back-compat: the legacy membership shapes
  /// (`{'kind': 'all' | 'tag' | 'folder'}`) still parse. Unknown/malformed →
  /// [everything] (safe: a lens falls back to the whole vault rather than
  /// silently selecting nothing).
  static CardQuery fromJson(Map<String, dynamic> json) =>
      switch (json['kind']) {
        'all' => everything,
        'tag' => TagIs((json['value'] ?? '') as String),
        'folder' => FolderUnder((json['value'] ?? '') as String),
        _ => everything,
      };
}

/// Every card in the vault (the single-deck / whole-vault case).
class Everything extends CardQuery {
  const Everything();

  @override
  bool matches(Card card) => true;

  @override
  Map<String, dynamic> toJson() => {'kind': 'all'};
}

/// Cards carrying [tag] (case-insensitive, leading `#` ignored) — the
/// cross-cutting selector that ignores folder structure entirely.
class TagIs extends CardQuery {
  TagIs(String tag) : tag = _normalize(tag);

  /// The tag to match, normalized (lowercase, no leading `#`).
  final String tag;

  static String _normalize(String raw) {
    final t = raw.trim();
    return (t.startsWith('#') ? t.substring(1) : t).toLowerCase();
  }

  @override
  bool matches(Card card) => card.tags.any((t) => _normalize(t) == tag);

  @override
  Map<String, dynamic> toJson() => {'kind': 'tag', 'value': tag};
}

/// Cards under a vault subtree [path] (POSIX, relative to the root). An empty
/// path matches everything.
class FolderUnder extends CardQuery {
  FolderUnder(String path) : path = _trim(path);

  final String path;

  static String _trim(String raw) {
    var p = raw.trim();
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  @override
  bool matches(Card card) =>
      path.isEmpty ||
      card.filePath == path ||
      card.filePath.startsWith('$path/');

  @override
  Map<String, dynamic> toJson() => {'kind': 'folder', 'value': path};
}
