import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';

/// The draft/active lifecycle seam + the reserved deckId (ADR-0003).

const _parser = CardParser();

String _card({
  String id = '33333333-3333-4333-8333-333333333333',
  String? status,
  String? deck,
}) =>
    '''
---
id: $id
type: flashcard
tags:
  - ds-a
${status == null ? '' : 'status: $status'}
${deck == null ? '' : 'deck: $deck'}
---

# A Card

Overview.

## When to Use

The cue.
''';

void main() {
  group('CardStatus / draft seam (ADR-0003)', () {
    test('absent status defaults to active (existing cards unaffected)', () {
      final card = _parser.parse(_card(), filePath: 'a.md')!;
      expect(card.status, CardStatus.active);
      expect(card.isDraft, isFalse);
      expect(card.deckId, ''); // deckId seam defaults to the local deck
    });

    test('status: draft parses to a draft card', () {
      final card = _parser.parse(_card(status: 'draft'), filePath: 'a.md')!;
      expect(card.status, CardStatus.draft);
      expect(card.isDraft, isTrue);
    });

    test('unknown status falls back to active (never silently draft)', () {
      final card = _parser.parse(_card(status: 'bogus'), filePath: 'a.md')!;
      expect(card.status, CardStatus.active);
    });

    test('deck: sets the reserved deckId seam', () {
      final card = _parser.parse(_card(deck: 'my-deck'), filePath: 'a.md')!;
      expect(card.deckId, 'my-deck');
    });

    test('IndexResult.studyCards excludes drafts, keeps active', () {
      final active = _parser.parse(_card(), filePath: 'a.md')!;
      final draft = _parser.parse(
        _card(id: '44444444-4444-4444-8444-444444444444', status: 'draft'),
        filePath: 'b.md',
      )!;
      final index = IndexResult(
        cards: [active, draft],
        idless: 0,
        malformed: 0,
        skipped: 0,
      );
      expect(index.cards.length, 2); // Browse sees both
      expect(
          index.studyCards.map((c) => c.id), [active.id]); // schedulers don't
    });
  });
}
