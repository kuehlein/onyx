import 'package:path/path.dart' as p;

/// The vault's app-managed config/state directory (ADR-0019): **visible** (a leading
/// underscore, not a dot) so it syncs on iOS + iCloud and shows in Obsidian, clearly
/// app-owned, excluded from the card index. Meta names ([VaultSource.readMeta] etc.)
/// are POSIX paths *relative to this dir* — e.g. `decks/<id>/deck.json`.
const String kConfigDir = '_onyx';

/// The pre-ADR-0019 config dir. Read-compat only: [readMeta] falls back to a legacy
/// `_meta/` file when no `_onyx/` one exists, but never renames on disk (reads must be
/// safe for read-only committed fixtures) — writes always land in `_onyx/`, and Wave B's
/// migration sweeps any lingering legacy files. Kept in the index exclusion so a stray
/// legacy dir never leaks into the card set.
const String kLegacyConfigDir = '_meta';

/// True when [relativePath]'s filename matches a folder-syncer **conflict-copy**
/// pattern — the duplicate a sync tool (Syncthing / Dropbox / iCloud desktop) spawns
/// when two devices edit the same file. A conflict copy carries the original's
/// frontmatter *verbatim*, so ingesting one as a card mints a **duplicate card id**
/// and corrupts the index (ADR-0019/0021). The indexer skips + reports these instead.
///
/// Matches only **unambiguous machine patterns** — deliberately NOT a numbered suffix
/// like `notes 2.md`, which is a legitimate user filename.
bool isConflictCopy(String relativePath) {
  final name = p.posix.basename(relativePath).toLowerCase();
  return name.contains('.sync-conflict-') || name.contains('conflicted copy');
}

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
  /// `.md` files under the root except those inside the config dir ([kConfigDir],
  /// or the legacy [kLegacyConfigDir]) or a hidden (`.`-prefixed) folder such as
  /// `.obsidian/`. Sorted for determinism.
  Future<List<String>> listCardPaths();

  /// Relative POSIX paths of EVERY file under the root (any extension), with the
  /// same config-dir + hidden-folder exclusions as [listCardPaths]. Used to resolve
  /// `[[wikilinks]]`: a link is only "dangling" when no file of ANY type shares
  /// its name, so resolution follows file-type support instead of assuming `.md`.
  /// Defaults to [listCardPaths] (the `.md`-only set) for sources that don't yet
  /// enumerate other files.
  Future<List<String>> listAllPaths() => listCardPaths();

  /// Reads the UTF-8 content of the card at [relativePath].
  Future<String> readCard(String relativePath);

  /// Relative POSIX paths of every subject-config file in the vault — files named
  /// `onyx-subject.yaml`, anywhere (including inside the visible config dir, which
  /// [listCardPaths] excludes). Each declares a subject rooted at its enclosing
  /// directory (see `templateRootDir`). A vault with one (or zero) is the
  /// single-subject case; multiple make it a multi-subject vault (task #30d).
  Future<List<String>> listConfigPaths();

  /// Reads app-managed config/state under the config dir at `[kConfigDir]/[name]`
  /// (e.g. the SRS backup snapshot), or null if it doesn't exist. [name] is a POSIX
  /// path relative to the config dir and MAY be nested (`decks/<id>/deck.json`). The
  /// config dir is excluded from indexing.
  Future<String?> readMeta(String name);

  /// Atomically writes [content] to `[kConfigDir]/[name]`, creating the config dir
  /// and any parent folders of [name] as needed (so a nested `decks/<id>/deck.json`
  /// works). [name] is a POSIX path relative to the config dir.
  Future<void> writeMeta(String name, String content);

  /// POSIX paths (relative to [kConfigDir]) of every FILE under
  /// `[kConfigDir]/[subdir]`, recursively — e.g. `listMeta('decks')` →
  /// `['decks/korean/aims.json', 'decks/korean/deck.json', …]`. Sorted. Empty when
  /// the subdir is absent. Reads the CURRENT config dir only: the legacy
  /// [kLegacyConfigDir] was always flat, so it has no nested subdir to fall back to.
  ///
  /// Config-dir enumeration is a per-source capability; a source that doesn't manage
  /// a config dir should return `const []`, so callers degrade to the single-file
  /// layout (e.g. [readMeta]'s legacy blob) rather than break.
  Future<List<String>> listMeta(String subdir);

  /// Deletes `[kConfigDir]/[name]` — a file, or a directory (recursively). A no-op if
  /// it doesn't exist. [name] is a POSIX path relative to the config dir. Used to drop
  /// a removed deck's per-deck dir so it can't be re-read into the deck list. Only the
  /// CURRENT config dir is touched. A source without a config dir should no-op.
  Future<void> deleteMeta(String name);

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
