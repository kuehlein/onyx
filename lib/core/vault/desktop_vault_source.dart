import 'dart:io';

import 'package:path/path.dart' as p;

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

    final paths = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final relative = p.relative(entity.path, from: rootPath);
      if (_excluded(relative)) continue;
      // Normalize to POSIX separators so stored paths are platform-independent.
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
      // Skip hidden folders (e.g. `.obsidian/`); `_meta/` is NOT excluded here —
      // that's where the legacy single-subject config lives.
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
    final file = File(p.join(rootPath, '_meta', name));
    return file.existsSync() ? file.readAsString() : null;
  }

  @override
  Future<void> writeMeta(String name, String content) async {
    final dir = Directory(p.join(rootPath, '_meta'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    // Atomic: write to a temp file, then rename over the target.
    final target = p.join(dir.path, name);
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

  /// Skip `_meta/` (vault metadata) and hidden folders like `.obsidian/`.
  bool _excluded(String relative) => p
      .split(relative)
      .any((segment) => segment == '_meta' || segment.startsWith('.'));
}
