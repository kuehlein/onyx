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
  Future<String> readCard(String relativePath) =>
      File(p.join(rootPath, relativePath)).readAsString();

  /// Skip `_meta/` (vault metadata) and hidden folders like `.obsidian/`.
  bool _excluded(String relative) => p
      .split(relative)
      .any((segment) => segment == '_meta' || segment.startsWith('.'));
}
