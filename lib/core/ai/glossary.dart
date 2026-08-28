import '../vault/vault_source.dart';

/// GitHub/Obsidian-style heading slug: `Load Balancer` → `load-balancer`. Card
/// links use this as the anchor (`[API](_meta/glossary.md#api)`).
String glossarySlug(String heading) => heading
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Parses a glossary Markdown note (`## Term` sections) into a `slug → definition`
/// map. The vault note is the single source of truth; this is a pure read.
Map<String, String> parseGlossaryNote(String markdown) {
  final entries = <String, String>{};
  final heading = RegExp(r'^##\s+(.+?)\s*$');
  String? slug;
  final buffer = <String>[];

  void flush() {
    final key = slug;
    if (key != null) {
      final definition = buffer.join('\n').trim();
      if (definition.isNotEmpty) entries[key] = definition;
    }
    buffer.clear();
  }

  for (final line in markdown.split('\n')) {
    final match = heading.firstMatch(line);
    if (match != null) {
      flush();
      slug = glossarySlug(match.group(1)!.trim());
    } else if (slug != null) {
      buffer.add(line);
    }
  }
  flush();
  return entries;
}

/// Reads the vault glossary note at `_meta/glossary.md` — a human-authored,
/// Obsidian-editable, vault-versioned file that is the single source of truth
/// for tap-to-define. (Definitions are curated in the vault, not generated.)
class GlossaryService {
  GlossaryService({required this.source});

  final VaultSource source;

  static const fileName = 'glossary.md';

  /// The `slug → definition` map from the vault note (empty if none).
  Future<Map<String, String>> load() async {
    final raw = await source.readMeta(fileName);
    return raw == null ? const {} : parseGlossaryNote(raw);
  }
}
