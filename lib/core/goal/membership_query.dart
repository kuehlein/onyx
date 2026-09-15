/// How a study goal selects its member cards — the query that makes a goal a
/// *lens* over the vault rather than a folder (task #30d, see
/// docs/multi-subject-plan.md).
///
/// Membership is orthogonal to where files live: a [TagMembership] gathers cards
/// scattered across the whole vault, while a [FolderMembership] scopes to a
/// subtree. A card can satisfy many goals at once. Near-term selectors are
/// all/tag/folder; link-neighborhood, explicit lists, and boolean combinations
/// come later.
library;

import '../../shared/models/card.dart';

sealed class MembershipQuery {
  const MembershipQuery();

  /// Whether [card] is a member of a goal using this query.
  bool matches(Card card);

  Map<String, dynamic> toJson();

  /// Rebuilds a query from its JSON; unknown/malformed → [AllCards] (safe: a goal
  /// falls back to the whole vault rather than silently selecting nothing).
  static MembershipQuery fromJson(Map<String, dynamic> json) =>
      switch (json['kind']) {
        'tag' => TagMembership((json['value'] ?? '') as String),
        'folder' => FolderMembership((json['value'] ?? '') as String),
        _ => const AllCards(),
      };
}

/// Every card in the vault (the single-goal / whole-vault case).
class AllCards extends MembershipQuery {
  const AllCards();

  @override
  bool matches(Card card) => true;

  @override
  Map<String, dynamic> toJson() => {'kind': 'all'};
}

/// Cards carrying [tag] (case-insensitive, leading `#` ignored) — the
/// cross-cutting selector that ignores folder structure entirely.
class TagMembership extends MembershipQuery {
  TagMembership(String tag) : tag = _normalize(tag);

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
class FolderMembership extends MembershipQuery {
  FolderMembership(String path) : path = _trim(path);

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
