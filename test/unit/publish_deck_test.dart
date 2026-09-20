import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/registry/deck.dart';
import 'package:onyx/core/registry/import_deck.dart';
import 'package:onyx/core/registry/publish_deck.dart';
import 'package:onyx/core/registry/registry_client.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';

/// The publish (push) side of the registry (task #30 / registry-and-sync.md §4),
/// client-side against the fake. `buildDeckManifest` is the inverse of
/// `importDeck`; together they prove a deck round-trips as a structure-preserving
/// FILE TREE while scheduling never travels.
const _localCard = '''---
id: my-note
type: flashcard
tags: [geography]
status: active
---

# Canberra

The capital of Australia.

## Why it surprises

People assume Sydney or Melbourne.

## Resources

- https://example.com
''';

Future<DesktopVaultSource> _sourceWith(String path, String content) async {
  final dir = await Directory.systemTemp.createTemp('onyx_pub_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final source = DesktopVaultSource(dir.path);
  await source.writeFile(path, content);
  return source;
}

void main() {
  test('reads raw files verbatim, preserving path (content-only)', () async {
    final source = await _sourceWith('places/canberra.md', _localCard);

    final m = await buildDeckManifest(
      source: source,
      deckId: 'geo',
      name: 'Geography',
      author: 'Me',
      license: 'CC0-1.0',
      cardPaths: ['places/canberra.md'],
    );

    expect(m.deckId, 'geo');
    final f = m.files.single;
    expect(f.path, 'places/canberra.md'); // structure preserved
    expect(f.content, _localCard); // verbatim (status: active and all)
    // Content-only: the payload type has no schedule field to carry.
    expect(m.toJson().containsKey('srs_state'), isFalse);
  });

  test('rootPrefix makes deck paths relative to the exported folder', () async {
    final source = await _sourceWith('people/caesar.md', _localCard);
    final m = await buildDeckManifest(
      source: source,
      deckId: 'd',
      name: 'D',
      author: 'x',
      cardPaths: ['people/caesar.md'],
      rootPrefix: 'people',
    );
    expect(m.files.single.path, 'caesar.md');
  });

  test('publish → import round-trips as a fresh draft, structure preserved',
      () async {
    final a = await _sourceWith('places/canberra.md', _localCard);
    final bDir = await Directory.systemTemp.createTemp('onyx_pub_import_');
    addTearDown(() => bDir.deleteSync(recursive: true));
    final b = DesktopVaultSource(bDir.path);

    final m = await buildDeckManifest(
      source: a,
      deckId: 'geo',
      name: 'Geography',
      author: 'Me',
      cardPaths: ['places/canberra.md'],
    );
    await importDeck(b, m);

    final path = (await b.listCardPaths()).single;
    expect(path, 'geo/places/canberra.md'); // deck folder + preserved structure
    final back =
        const CardParser().parse(await b.readCard(path), filePath: path)!;
    expect(back.title, 'Canberra');
    expect(
        back.sections.map((s) => s.heading), ['Why it surprises', 'Resources']);
    final quiz = {for (final s in back.sections) s.heading: s.quizzable};
    expect(quiz['Why it surprises'], isTrue);
    expect(quiz['Resources'], isFalse);
    // Scheduling never travels: locally active → re-enters as a fresh draft.
    expect(back.isDraft, isTrue);
    expect(back.deckId, 'geo');
  });

  test('deckPayloadIssue flags oversized files, else null', () {
    const ok = DeckManifest(
      deckId: 'd',
      name: 'D',
      author: 'x',
      files: [DeckFile(path: 'a.md', content: 'small')],
    );
    expect(deckPayloadIssue(ok), isNull);

    final big = DeckManifest(
      deckId: 'd',
      name: 'D',
      author: 'x',
      files: [DeckFile(path: 'big.md', content: 'x' * (kMaxDeckFileBytes + 1))],
    );
    expect(deckPayloadIssue(big), contains('too large'));
  });

  test('FakeRegistryClient: publish then pull sees the deck', () async {
    final source = await _sourceWith('places/canberra.md', _localCard);
    final client = FakeRegistryClient();
    final m = await buildDeckManifest(
      source: source,
      deckId: 'geo',
      name: 'Geography',
      author: 'Me',
      cardPaths: ['places/canberra.md'],
    );

    await client.publishDeck(m);

    final listed = await client.listDecks();
    expect(listed.map((d) => d.deckId), contains('geo'));
    expect(listed.firstWhere((d) => d.deckId == 'geo').cardCount, 1);
    final pulled = await client.getDeck('geo');
    expect(pulled.files.single.path, 'places/canberra.md');

    // Re-publishing the same id replaces (idempotent), never duplicates.
    await client.publishDeck(m);
    final again = await client.listDecks();
    expect(again.where((d) => d.deckId == 'geo').length, 1);
  });
}
