import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/card_promotion.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:path/path.dart' as p;

const _parser = CardParser();

/// A draft card in the shape imported decks write (import_deck.dart): a `---`
/// block with id/type/deck/status/tags, an H1, then a `## ` section.
const _draftCard = '''---
id: capitals-france
type: flashcard
deck: world-capitals
status: draft
tags: ["geography", "capitals"]
---

# France

## Capital

Paris.
''';

void main() {
  late Directory root;
  late DesktopVaultSource source;

  setUp(() {
    root = Directory.systemTemp.createTempSync('onyx_promote_');
    source = DesktopVaultSource(root.path);
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('promoteCard', () {
    test('removes status: draft so the card re-parses as active, rest intact',
        () async {
      const path = 'world-capitals/capitals-france.md';
      await source.writeFile(path, _draftCard);

      // Sanity: it parses as a draft before promotion.
      final before =
          _parser.parse(await source.readCard(path), filePath: path)!;
      expect(before.isDraft, isTrue);

      await promoteCard(source, path);

      final raw = await source.readCard(path);
      // The status line is gone, no blank line left behind…
      expect(raw.contains('status:'), isFalse);
      expect(raw.contains('\n\n---'), isFalse,
          reason: 'no dangling blank line where status: was');

      // …and it now parses as active with everything else intact.
      final after = _parser.parse(raw, filePath: path)!;
      expect(after.isDraft, isFalse);
      expect(after.status, CardStatus.active);
      expect(after.id, 'capitals-france');
      expect(after.type, 'flashcard');
      expect(after.deckId, 'world-capitals');
      expect(after.title, 'France');
      expect(after.tags, ['geography', 'capitals']);
      expect(after.sections.single.heading, 'Capital');
      expect(after.sections.single.content, 'Paris.');
    });

    test('matches a quoted draft value too', () async {
      const path = 'q.md';
      await source.writeFile(
        path,
        '---\nid: q\ntype: flashcard\nstatus: "draft"\n---\n\n# Q\n\n## A\n\nb.\n',
      );
      await promoteCard(source, path);
      final after = _parser.parse(await source.readCard(path), filePath: path)!;
      expect(after.isDraft, isFalse);
      expect(after.id, 'q');
    });

    test('no-op on an already-active card (no status line)', () async {
      const path = 'active.md';
      const content =
          '---\nid: a\ntype: flashcard\n---\n\n# A\n\n## S\n\nbody.\n';
      await source.writeFile(path, content);
      await promoteCard(source, path);
      // Byte-for-byte unchanged.
      expect(await source.readCard(path), content);
    });
  });

  group('discardCard / deleteFile', () {
    test('discardCard removes the file', () async {
      const path = 'world-capitals/capitals-france.md';
      await source.writeFile(path, _draftCard);
      expect(
          File(p.join(root.path, 'world-capitals/capitals-france.md'))
              .existsSync(),
          isTrue);

      await discardCard(source, path);

      expect(
          File(p.join(root.path, 'world-capitals/capitals-france.md'))
              .existsSync(),
          isFalse);
    });

    test('deleteFile no-ops on a missing file', () async {
      // Must not throw.
      await source.deleteFile('does/not/exist.md');
      expect(
          File(p.join(root.path, 'does/not/exist.md')).existsSync(), isFalse);
    });
  });
}
