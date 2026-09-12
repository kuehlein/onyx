import '../vault/vault_source.dart';
import 'story.dart';

/// Reads and writes the behavioral **story bank** — markdown notes under the
/// vault's `stories/` folder. Stories are plain Obsidian notes (no Onyx card
/// `type`), so the card indexer skips them; this repository owns them.
class StoryRepository {
  StoryRepository(this._source);

  final VaultSource _source;

  static const dir = 'stories';

  /// Loads every parseable story under `stories/`, sorted by title.
  Future<List<Story>> loadAll() async {
    final paths = await _source.listCardPaths();
    final out = <Story>[];
    for (final path in paths) {
      if (!path.startsWith('$dir/') || !path.endsWith('.md')) continue;
      final content = await _source.readCard(path);
      final id = path.substring('$dir/'.length, path.length - '.md'.length);
      final s = Story.parse(content, id: id);
      if (s != null) out.add(s);
    }
    out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return out;
  }

  /// Writes [story] to `stories/<id>.md` (create or overwrite).
  Future<void> save(Story story) =>
      _source.writeFile('$dir/${story.id}.md', story.toMarkdown());
}

/// A filesystem-safe slug id from a story title (lowercase, hyphenated). Falls
/// back to [fallback] when the title has no alphanumerics.
String storySlug(String title, {String fallback = 'story'}) {
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? fallback : slug;
}
