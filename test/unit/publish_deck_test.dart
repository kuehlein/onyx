import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/registry/import_deck.dart';
import 'package:onyx/core/registry/publish_deck.dart';
import 'package:onyx/core/registry/registry_client.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';

/// The publish (push) side of the registry (task #30 / registry-and-sync.md §4),
/// client-side against the fake. `buildDeckManifest` is the inverse of
/// `importDeck`; together they prove a deck round-trips as CONTENT while
/// scheduling never travels.
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

void main() {
  final card = const CardParser().parse(_localCard, filePath: 'my-note.md')!;

  test('buildDeckManifest carries content only (no status/deck/schedule)', () {
    final m = buildDeckManifest(
      deckId: 'geo',
      name: 'Geography',
      author: 'Me',
      license: 'CC0-1.0',
      cards: [card],
    );
    expect(m.deckId, 'geo');
    expect(m.cards.single.id, 'my-note');
    expect(m.cards.single.title, 'Canberra');
    expect(m.cards.single.type, 'flashcard');
    expect(m.cards.single.tags, ['geography']);
    // Body reconstructs the overview + every section (incl. reference sections).
    expect(m.cards.single.body, contains('## Why it surprises'));
    expect(m.cards.single.body, contains('## Resources'));
    // The type carries no schedule/status field at all — structural guarantee.
  });

  test('publish → import round-trips as content, re-entering as a fresh draft',
      () async {
    final dir = await Directory.systemTemp.createTemp('onyx_publish_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final source = DesktopVaultSource(dir.path);

    final manifest = buildDeckManifest(
        deckId: 'geo', name: 'Geography', author: 'Me', cards: [card]);
    await importDeck(source, manifest);

    final imported = [
      for (final p in await source.listCardPaths())
        if (const CardParser().parse(await source.readCard(p), filePath: p)
            case final c?)
          c,
    ];
    final back = imported.single;
    // Content survived…
    expect(back.title, 'Canberra');
    expect(back.type, 'flashcard');
    expect(
        back.sections.map((s) => s.heading), ['Why it surprises', 'Resources']);
    // …with the same quizzable rules (Resources stays reference-only)…
    final quiz = {for (final s in back.sections) s.heading: s.quizzable};
    expect(quiz['Why it surprises'], isTrue);
    expect(quiz['Resources'], isFalse);
    // …but scheduling never travels: it lands as a fresh draft, deck-namespaced.
    expect(back.isDraft, isTrue);
    expect(back.deckId, 'geo');
  });

  test('FakeRegistryClient: publish then pull sees the deck', () async {
    final client = FakeRegistryClient();
    final manifest = buildDeckManifest(
        deckId: 'geo', name: 'Geography', author: 'Me', cards: [card]);

    await client.publishDeck(manifest);

    final listed = await client.listDecks();
    expect(listed.map((d) => d.deckId), contains('geo'));
    expect(listed.firstWhere((d) => d.deckId == 'geo').cardCount, 1);
    final pulled = await client.getDeck('geo');
    expect(pulled.cards.single.title, 'Canberra');

    // Re-publishing the same id replaces (idempotent), never duplicates.
    await client.publishDeck(manifest);
    final again = await client.listDecks();
    expect(again.where((d) => d.deckId == 'geo').length, 1);
  });
}
