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

  test('writeMeta/readMeta round-trip a NESTED config subpath (ADR-0019)',
      () async {
    await source.writeMeta('decks/swe/deck.json', '{"id":"swe"}');
    expect(await source.readMeta('decks/swe/deck.json'), '{"id":"swe"}');
    // Lands physically under the visible config dir _onyx/, parents auto-created.
    expect(
      File(p.join(root.path, '_onyx', 'decks', 'swe', 'deck.json'))
          .existsSync(),
      isTrue,
    );
  });

  test('readMeta falls back to a legacy _meta/ file; writeMeta lands in _onyx/',
      () async {
    write('_meta/glossary.md', '# Glossary\n'); // an un-migrated legacy file
    expect(await source.readMeta('glossary.md'), '# Glossary\n'); // read-compat
    // A write of the same name lands in _onyx/ and then wins over the legacy copy.
    await source.writeMeta('glossary.md', '# New\n');
    expect(await source.readMeta('glossary.md'), '# New\n');
    expect(
        File(p.join(root.path, '_onyx', 'glossary.md')).existsSync(), isTrue);
  });

  test('listMeta enumerates files under a config subdir, sorted (ADR-0019)',
      () async {
    await source.writeMeta('decks/korean/deck.json', '{}');
    await source.writeMeta('decks/korean/aims.json', '[]');
    await source.writeMeta('decks/swe/deck.json', '{}');
    expect(await source.listMeta('decks'), [
      'decks/korean/aims.json',
      'decks/korean/deck.json',
      'decks/swe/deck.json',
    ]);
    // A subdir that doesn't exist → empty (callers degrade to the flat layout).
    expect(await source.listMeta('subjects'), isEmpty);
    // listMeta reads only _onyx/, never the flat legacy _meta/.
    write('_meta/decks/legacy/deck.json', '{}');
    expect(await source.listMeta('decks'),
        isNot(contains('decks/legacy/deck.json')));
  });

  test('deleteMeta removes a config file or a whole dir; no-op if absent',
      () async {
    await source.writeMeta('decks/gone/deck.json', '{}');
    await source.writeMeta('decks/gone/aims.json', '[]');
    await source.writeMeta('decks/keep/deck.json', '{}');
    // Delete the whole per-deck dir (recursively).
    await source.deleteMeta('decks/gone');
    expect(Directory(p.join(root.path, '_onyx', 'decks', 'gone')).existsSync(),
        isFalse);
    expect(await source.readMeta('decks/keep/deck.json'), '{}');
    // A single file, and a missing path (no throw).
    await source.deleteMeta('decks/keep/deck.json');
    expect(await source.readMeta('decks/keep/deck.json'), isNull);
    await source.deleteMeta('decks/never-existed');
  });
}
