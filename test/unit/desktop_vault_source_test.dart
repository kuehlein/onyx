import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late DesktopVaultSource source;

  void write(String relative, String content) {
    final file = File(p.join(root.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('onyx_vault_');
    source = DesktopVaultSource(root.path);
    write('binary-search.md', '# Binary Search\n');
    write('ds-a/two-sum.md', '# Two Sum\n');
    write('_meta/tags.md', '# Tags\n'); // excluded: _meta/
    write('.obsidian/workspace.md', 'x'); // excluded: hidden folder
    write('notes.txt', 'not markdown'); // excluded: not .md
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('lists .md files recursively, excluding _meta/, hidden, and non-md',
      () async {
    expect(
        await source.listCardPaths(), ['binary-search.md', 'ds-a/two-sum.md']);
  });

  test('reads card content by relative path', () async {
    expect(await source.readCard('ds-a/two-sum.md'), '# Two Sum\n');
  });

  test('returns empty for a non-existent root', () async {
    final missing = DesktopVaultSource(p.join(root.path, 'nope'));
    expect(await missing.listCardPaths(), isEmpty);
  });

  test('rootLabel is the path', () {
    expect(source.rootLabel, root.path);
  });
}
