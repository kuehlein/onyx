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

  /// Relative POSIX paths of EVERY file under the root (any extension), with the
  /// same `_meta/` + hidden-folder exclusions as [listCardPaths]. Used to resolve
  /// `[[wikilinks]]`: a link is only "dangling" when no file of ANY type shares
  /// its name, so resolution follows file-type support instead of assuming `.md`.
  /// Defaults to [listCardPaths] (the `.md`-only set) for sources that don't yet
  /// enumerate other files.
  Future<List<String>> listAllPaths() => listCardPaths();

  /// Reads the UTF-8 content of the card at [relativePath].
  Future<String> readCard(String relativePath);

  /// Relative POSIX paths of every subject-config file in the vault — files named
  /// `onyx-subject.yaml`, anywhere (including inside `_meta/` folders, which
  /// [listCardPaths] excludes). Each declares a subject rooted at its enclosing
  /// directory (see `subjectRootDir`). A vault with one (or zero) is the
  /// single-subject case; multiple make it a multi-subject vault (task #30d).
  Future<List<String>> listConfigPaths();

  /// Reads app-managed metadata at `_meta/[name]` (e.g. the SRS backup
  /// snapshot), or null if it doesn't exist. `_meta/` is excluded from indexing.
  Future<String?> readMeta(String name);

  /// Atomically writes [content] to `_meta/[name]`, creating `_meta/` if needed.
  Future<void> writeMeta(String name, String content);

  /// Atomically writes [content] to the vault file at [relativePath] (POSIX,
  /// relative to the root), creating parent folders as needed. Used for
  /// app-authored notes that live IN the vault as first-class markdown — e.g. the
  /// behavioral story bank under `stories/`.
  Future<void> writeFile(String relativePath, String content);

  /// Deletes the vault file at [relativePath] (POSIX, relative to the root).
  /// A no-op if the file does not exist. Used by the draft-review gate's DISCARD
  /// action to remove an unwanted draft card entirely.
  Future<void> deleteFile(String relativePath);
}
