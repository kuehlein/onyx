/// The set of study subjects live in one vault at once — the spine of the
/// multi-subject *concurrent* platform (task #30d, see docs/multi-subject-plan.md).
///
/// Where [DeckTemplate] defines one subject, the registry maps the vault's
/// per-directory configs to their subtrees so each card resolves to *its own*
/// subject by path. A vault with a single config (the legacy
/// `_meta/onyx-subject.yaml`, or none → the SWE default) collapses to a one-entry
/// registry, which is byte-identical to the pre-#30d single-subject behavior.
library;

import 'deck_template.dart';

/// The subject subtree root (POSIX, relative to the vault root) for a discovered
/// config file [configPath]. A config in a `_meta/` folder — the vault root's or a
/// subtree's own — roots the subject at the enclosing directory; otherwise the
/// config's own directory is the root. The vault root maps to `''` (a whole-vault
/// subject).
///
///  * `_meta/onyx-subject.yaml`        → `''`        (legacy whole-vault subject)
///  * `onyx-subject.yaml`              → `''`        (config at the vault root)
///  * `korean/onyx-subject.yaml`       → `korean`    (subtree subject)
///  * `korean/_meta/onyx-subject.yaml` → `korean`    (subtree subject, meta form)
String templateRootDir(String configPath) {
  final parts = configPath.split('/')..removeLast(); // drop the filename
  if (parts.isNotEmpty && parts.last == '_meta') parts.removeLast();
  return parts.join('/');
}

/// Whether a card at [path] falls under a subject rooted at [rootDir]. The empty
/// root (whole-vault subject) covers everything.
bool _covers(String rootDir, String path) =>
    rootDir.isEmpty || path == rootDir || path.startsWith('$rootDir/');

/// One subject and the vault subtree it owns.
class TemplateEntry {
  const TemplateEntry({required this.rootDir, required this.config});

  /// POSIX path of the subtree root, relative to the vault root; `''` = the whole
  /// vault.
  final String rootDir;
  final DeckTemplate config;
}

/// All subjects discovered in a vault, resolvable by card path or id.
class TemplateRegistry {
  TemplateRegistry({required this.entries, String? primaryId})
      : assert(entries.isNotEmpty, 'a registry needs at least one subject'),
        primaryId = primaryId ?? entries.first.config.id;

  final List<TemplateEntry> entries;

  /// The default subject — the whole-vault (root) subject when one exists, else
  /// the first discovered. Pure core that still reads a single `activeTemplate`
  /// (pre-M2) uses this.
  final String primaryId;

  /// A one-subject registry spanning the whole vault (the single-subject case).
  factory TemplateRegistry.single(DeckTemplate config) =>
      TemplateRegistry(entries: [TemplateEntry(rootDir: '', config: config)]);

  /// Builds a registry from discovered `(configPath, config)` pairs, or a single
  /// [fallback] subject when none were found (matching the pre-#30d fallback to
  /// the built-in SWE reference). The whole-vault (root) subject, if any, is
  /// primary; otherwise the first discovered subject.
  factory TemplateRegistry.fromConfigs(
    List<(String path, DeckTemplate config)> discovered, {
    required DeckTemplate fallback,
  }) {
    if (discovered.isEmpty) return TemplateRegistry.single(fallback);
    // Ids must be unique: a card stores only its subject *id*, and behavior later
    // re-resolves by id (byId). Two configs sharing an id (a copy-paste authoring
    // slip) would let path-resolution and id-resolution disagree, silently
    // misrouting a card's flows/quizzability. Keep the first per id (discovery is
    // path-sorted, so this is deterministic).
    final entries = <TemplateEntry>[];
    final seenIds = <String>{};
    for (final (path, config) in discovered) {
      if (!seenIds.add(config.id)) continue;
      entries
          .add(TemplateEntry(rootDir: templateRootDir(path), config: config));
    }
    final root = entries.where((e) => e.rootDir.isEmpty);
    return TemplateRegistry(
      entries: entries,
      primaryId: (root.isNotEmpty ? root.first : entries.first).config.id,
    );
  }

  List<DeckTemplate> get templates => [for (final e in entries) e.config];

  bool get isSingle => entries.length == 1;

  DeckTemplate get primary => byId(primaryId) ?? entries.first.config;

  DeckTemplate? byId(String id) {
    for (final e in entries) {
      if (e.config.id == id) return e.config;
    }
    return null;
  }

  /// The subject that owns the card at [cardPath] — the nearest-ancestor subtree
  /// (longest matching root), falling back to the [primary] subject when the card
  /// sits under no configured subtree.
  DeckTemplate templateForPath(String cardPath) {
    TemplateEntry? best;
    for (final e in entries) {
      if (!_covers(e.rootDir, cardPath)) continue;
      if (best == null || e.rootDir.length > best.rootDir.length) best = e;
    }
    return (best ?? _primaryEntry).config;
  }

  String templateIdForPath(String cardPath) => templateForPath(cardPath).id;

  TemplateEntry get _primaryEntry => entries.firstWhere(
        (e) => e.config.id == primaryId,
        orElse: () => entries.first,
      );
}
