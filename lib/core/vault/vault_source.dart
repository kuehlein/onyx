/// Abstraction over vault file access.
///
/// The production app reads the vault through an iOS security-scoped bookmark;
/// development on Linux/macOS reads a plain directory. Both sit behind this one
/// interface so the rest of the app (indexer, quiz, browse) is agnostic to how
/// files are reached. See docs/architecture.md.
abstract class VaultSource {
  /// Human-readable identifier of the vault root (a path, or a bookmark label).
  String get rootLabel;

  /// Relative POSIX paths of every markdown file eligible for indexing: all
  /// `.md` files under the root except those inside a `_meta/` folder or a
  /// hidden (`.`-prefixed) folder such as `.obsidian/`. Sorted for determinism.
  Future<List<String>> listCardPaths();

  /// Reads the UTF-8 content of the card at [relativePath].
  Future<String> readCard(String relativePath);
}
