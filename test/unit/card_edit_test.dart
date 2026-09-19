import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/vault/card_edit.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/models/card.dart';

/// Round-trip safety for the in-app editor (task #28). The crux: editing a card
/// must never lose or corrupt its frontmatter. These use a real temp
/// [DesktopVaultSource] + [CardParser] so what we assert is what the app reads.

const _parser = CardParser();

/// A card with rich frontmatter — id, type, deck, status: draft, confidence,
/// priority, a `tiers:` block, and a FLOW tag list — to prove every non-tag
/// field survives a title/body rewrite byte-for-byte.
const _richFlow = '''---
id: rich-card
type: flashcard
deck: world-capitals
status: draft
confidence: high
priority: high
tiers:
  ds-a: 2
  system-design: 1
tags: [geography, europe]
created: 2024-01-02
---

# Old Title

Old overview.

## Old Section

Old content.
''';

/// Same card, but with a BLOCK tag list AND a top-level key right after it, to
/// prove the tags span-replace stops at the next key (doesn't eat `created:`).
const _richBlock = '''---
id: rich-card
type: flashcard
deck: world-capitals
status: draft
confidence: high
priority: high
tiers:
  ds-a: 2
  system-design: 1
tags:
  - geography
  - europe
created: 2024-01-02
---

# Old Title

Old overview.

## Old Section

Old content.
''';

void main() {
  group('rebuildCardMarkdown — frontmatter preservation', () {
    test('rewrites title+body, preserves every non-tag field (flow tags)', () {
      final out = rebuildCardMarkdown(
        _richFlow,
        title: 'New Title',
        body: 'New overview.\n\n## New Section\n\nNew content.',
        tags: null, // leave frontmatter entirely verbatim
      );

      // The frontmatter block is byte-for-byte identical to the source's.
      final srcFm = _richFlow.split('---')[1];
      final outFm = out.split('---')[1];
      expect(outFm, srcFm, reason: 'frontmatter must be preserved verbatim');

      // Re-parses to the new title/section with all metadata intact.
      final card = _parser.parse(out, filePath: 'rich.md')!;
      expect(card.title, 'New Title');
      expect(card.id, 'rich-card');
      expect(card.deckId, 'world-capitals');
      expect(card.status, CardStatus.draft);
      expect(card.isDraft, isTrue);
      expect(card.confidence, Confidence.high);
      expect(card.priority, Priority.high);
      expect(card.tiers, {'ds-a': 2, 'system-design': 1});
      expect(card.tags, ['geography', 'europe']);
      expect(card.sections.map((s) => s.heading), ['New Section']);
      expect(card.sections.single.content, 'New content.');
      expect(card.overview, 'New overview.');
    });

    test('tags:null leaves the frontmatter verbatim (block form too)', () {
      final out = rebuildCardMarkdown(
        _richBlock,
        title: 'X',
        body: '## S\n\nc',
        tags: null,
      );
      expect(out.split('---')[1], _richBlock.split('---')[1]);
    });

    test('FLOW tags: edit replaces only the tags line, neighbors intact', () {
      final out = rebuildCardMarkdown(
        _richFlow,
        title: 'New Title',
        body: '## New Section\n\nc',
        tags: ['tcp', 'networking'],
      );
      final card = _parser.parse(out, filePath: 'rich.md')!;
      expect(card.tags, ['tcp', 'networking']);
      // Neighbors survived (the line above/below the flow tags line).
      expect(card.priority, Priority.high);
      expect(card.tiers, {'ds-a': 2, 'system-design': 1});
      expect(card.created, DateTime(2024, 1, 2));
      expect(card.deckId, 'world-capitals');
      // Exactly one tags line remains (no duplicate/leftover).
      expect('tags:'.allMatches(out).length, 1);
    });

    test('BLOCK tags: edit replaces the whole span, stops at next key', () {
      final out = rebuildCardMarkdown(
        _richBlock,
        title: 'New Title',
        body: '## New Section\n\nc',
        tags: ['tcp', 'networking'],
      );
      final card = _parser.parse(out, filePath: 'rich.md')!;
      expect(card.tags, ['tcp', 'networking']);
      // The block list's old items are gone…
      expect(out.contains('- geography'), isFalse);
      expect(out.contains('- europe'), isFalse);
      // …but `created:` right after the block is untouched, and tiers survived.
      expect(card.created, DateTime(2024, 1, 2));
      expect(card.tiers, {'ds-a': 2, 'system-design': 1});
      expect(card.confidence, Confidence.high);
      expect('tags:'.allMatches(out).length, 1);
    });

    test('empty tags list writes an empty flow list the parser reads as []',
        () {
      final out = rebuildCardMarkdown(
        _richBlock,
        title: 'T',
        body: '## S\n\nc',
        tags: const [],
      );
      final card = _parser.parse(out, filePath: 'rich.md')!;
      expect(card.tags, isEmpty);
      expect(card.tiers, {'ds-a': 2, 'system-design': 1});
    });

    test('throws when the source has no frontmatter', () {
      expect(
        () => rebuildCardMarkdown('# Just a title\n\nbody',
            title: 'x', body: 'y'),
        throwsA(isA<FormatException>()),
      );
    });

    test('output has exactly one trailing newline', () {
      final out = rebuildCardMarkdown(_richFlow,
          title: 'T', body: '## S\n\nc', tags: null);
      expect(out.endsWith('\n'), isTrue);
      expect(out.endsWith('\n\n'), isFalse);
    });
  });

  group('newCardMarkdown', () {
    test('parses as an ACTIVE card with the right id/type/title/tags/sections',
        () {
      final out = newCardMarkdown(
        id: 'my-card',
        title: 'My Card',
        body: 'An overview.\n\n## Answer\n\nThe answer.',
        tags: ['ds-a', 'trees'],
      );
      final card = _parser.parse(out, filePath: 'my-card.md')!;
      expect(card.isDraft, isFalse,
          reason: 'hand-authored → active, not draft');
      expect(card.status, CardStatus.active);
      expect(card.id, 'my-card');
      expect(card.type, 'flashcard');
      expect(card.title, 'My Card');
      expect(card.tags, ['ds-a', 'trees']);
      expect(card.deckId, '', reason: 'no deck: written for local content');
      expect(card.overview, 'An overview.');
      expect(card.sections.map((s) => s.heading), ['Answer']);
      expect(card.sections.single.content, 'The answer.');
      expect(card.quizzableSections, isNotEmpty);
    });

    test('writes a deck: line only when deckId is non-empty', () {
      final withDeck = newCardMarkdown(
        id: 'x',
        title: 'X',
        body: '## S\n\nc',
        deckId: 'pulled-deck',
      );
      expect(withDeck.contains('deck: "pulled-deck"'), isTrue);
      expect(_parser.parse(withDeck, filePath: 'x.md')!.deckId, 'pulled-deck');

      final noDeck = newCardMarkdown(id: 'y', title: 'Y', body: '## S\n\nc');
      expect(noDeck.contains('deck:'), isFalse);
    });
  });

  group('createCard / saveCardEdit / deleteCardFile (temp source)', () {
    late Directory root;
    late DesktopVaultSource source;

    setUp(() {
      root = Directory.systemTemp.createTempSync('onyx_card_edit_');
      source = DesktopVaultSource(root.path);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('createCard writes <slug>.md at root; the file parses', () async {
      final path = await createCard(
        source,
        title: 'Binary Search',
        body: '## Answer\n\nDivide and conquer.',
        tags: ['ds-a'],
      );
      expect(path, 'binary-search.md');
      final card = _parser.parse(await source.readCard(path), filePath: path)!;
      expect(card.id, 'binary-search');
      expect(card.title, 'Binary Search');
      expect(card.isDraft, isFalse);
      expect(card.tags, ['ds-a']);
    });

    test('createCard de-dups the slug when <slug>.md exists (-2, -3)',
        () async {
      final p1 = await createCard(source, title: 'Dup', body: '## A\n\nx');
      final p2 = await createCard(source, title: 'Dup', body: '## A\n\ny');
      final p3 = await createCard(source, title: 'Dup', body: '## A\n\nz');
      expect(p1, 'dup.md');
      expect(p2, 'dup-2.md');
      expect(p3, 'dup-3.md');
      // Ids follow the deduped slug, so they stay unique.
      final ids = <String>{};
      for (final p in [p1, p2, p3]) {
        final c = _parser.parse(await source.readCard(p), filePath: p)!;
        expect(ids.add(c.id), isTrue);
      }
    });

    test('createCard falls back to "card" when the title slugifies to nothing',
        () async {
      final path = await createCard(source, title: '???', body: '## A\n\nx');
      expect(path, 'card.md');
    });

    test(
        'saveCardEdit rewrites in place, preserving status (draft stays draft)',
        () async {
      // Seed a draft with rich frontmatter on disk.
      File('${root.path}/seed.md').writeAsStringSync(_richFlow);
      await saveCardEdit(
        source,
        'seed.md',
        title: 'Edited Title',
        body: '## Edited\n\nnew body',
        tags: null,
      );
      final card =
          _parser.parse(await source.readCard('seed.md'), filePath: 'seed.md')!;
      expect(card.title, 'Edited Title');
      expect(card.status, CardStatus.draft, reason: 'edit preserves status');
      expect(card.deckId, 'world-capitals');
      expect(card.sections.map((s) => s.heading), ['Edited']);
    });

    test('deleteCardFile removes the file', () async {
      final path = await createCard(source, title: 'Doomed', body: '## A\n\nx');
      expect(File('${root.path}/$path').existsSync(), isTrue);
      await deleteCardFile(source, path);
      expect(File('${root.path}/$path').existsSync(), isFalse);
    });
  });
}
