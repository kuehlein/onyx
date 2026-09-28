import 'dart:io';

import 'package:path/path.dart' as p;

import '../template/active_template.dart';
import 'vault_source.dart';

/// A [VaultSource] backed by a plain filesystem directory.
///
/// This is the development path: point it at a local copy (or sync) of the
/// vault's `Flashcards/` folder and the whole app runs on Linux/macOS with no
/// iOS document picker in the loop. On device the equivalent is a
/// security-scoped-bookmark source.
class DesktopVaultSource implements VaultSource {
  DesktopVaultSource(this.rootPath);

  final String rootPath;

  /// Monotonic suffix so two overlapping writes to the same file use distinct
  /// temp files — a shared `$target.tmp` would make the second rename fail
  /// (`PathNotFoundException`) once the first renamed its tmp away.
  static int _tmpSeq = 0;

  @override
  String get rootLabel => rootPath;

  @override
  Future<List<String>> listCardPaths() async {
    final root = Directory(rootPath);
    if (!root.existsSync()) return const [];

    // Which file types are cards is the active subject's parse profile (task #30,
    // G4); the default {md} keeps this a `.md`-only walk. Case-insensitive on the
    // extension; card-ness is still decided per file by `type:` in the parser.
    final extensions = activeTemplate.parseProfile.fileExtensions;
    final paths = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase().replaceFirst('.', '');
      if (!extensions.contains(ext)) continue;
      final relative = p.relative(entity.path, from: rootPath);
      if (_excluded(relative)) continue;
      // Normalize to POSIX separators so stored paths are platform-independent.
      paths.add(p.posix.joinAll(p.split(relative)));
    }
    paths.sort();
    return paths;
  }

  @override
  Future<List<String>> listAllPaths() async {
    final root = Directory(rootPath);
    if (!root.existsSync()) return const [];

    final paths = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue; // any extension, not just `.md`
      final relative = p.relative(entity.path, from: rootPath);
      if (_excluded(relative)) continue;
      paths.add(p.posix.joinAll(p.split(relative)));
    }
    paths.sort();
    return paths;
  }

  @override
  Future<List<String>> listConfigPaths() async {
    final root = Directory(rootPath);
    if (!root.existsSync()) return const [];

    final paths = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: rootPath);
      final segments = p.split(relative);
      // Skip hidden (`.`-prefixed) folders; the VISIBLE config dir (`_onyx/`) is NOT
      // skipped — a subject template can live there. (Underscore ≠ dot, so it's
      // walked; a dot-config dir would be silently skipped here — see ADR-0019.)
      if (segments.any((s) => s.startsWith('.'))) continue;
      if (segments.last != 'onyx-subject.yaml') continue;
      paths.add(p.posix.joinAll(segments));
    }
    paths.sort();
    return paths;
  }

  @override
  Future<String> readCard(String relativePath) =>
      File(p.join(rootPath, relativePath)).readAsString();

  @override
  Future<String?> readMeta(String name) async {
    final rel = p.joinAll(p.posix.split(name));
    // Prefer the current config dir; fall back to a legacy `_meta/` file so an
    // un-migrated vault still reads (ADR-0019). Non-destructive: reads never rename
    // — safe for read-only committed fixtures; writes land in `_onyx/` (below), and
    // Wave B's migration sweeps any lingering legacy files.
    final onyx = File(p.join(rootPath, kConfigDir, rel));
    if (onyx.existsSync()) return onyx.readAsString();
    final legacy = File(p.join(rootPath, kLegacyConfigDir, rel));
    return legacy.existsSync() ? legacy.readAsString() : null;
  }

  @override
  Future<void> writeMeta(String name, String content) async {
    // Always write to the current config dir. [name] may be nested (e.g.
    // decks/<id>/deck.json) — create the target's parent, not just the config root,
    // so the atomic rename lands (mirrors writeFile).
    final target = p.join(rootPath, kConfigDir, p.joinAll(p.posix.split(name)));
    final dir = Directory(p.dirname(target));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final tmp = File('$target.${_tmpSeq++}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(target);
  }

  @override
  Future<void> writeFile(String relativePath, String content) async {
    final target = p.join(rootPath, p.joinAll(p.posix.split(relativePath)));
    final dir = Directory(p.dirname(target));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    // Atomic: write to a temp file, then rename over the target.
    final tmp = File('$target.${_tmpSeq++}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(target);
  }

  @override
  Future<void> deleteFile(String relativePath) async {
    final target = p.join(rootPath, p.joinAll(p.posix.split(relativePath)));
    final file = File(target);
    if (file.existsSync()) await file.delete();
  }

  /// Skip the config dir (`_onyx/`, or a legacy `_meta/` mid-migration) and hidden
  /// folders like `.obsidian/`. Both config-dir names stay excluded so a stray legacy
  /// dir never leaks into the card set.
  bool _excluded(String relative) => p.split(relative).any((segment) =>
      segment == kConfigDir ||
      segment == kLegacyConfigDir ||
      segment.startsWith('.'));
}
