import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/vault.dart';

/// Architecture invariant #4 (ADR-0003) regression guard: `status: draft` cards are
/// excluded from FSRS AND from EVERY readiness / coverage / analytics / daily-plan
/// denominator. The 1h audit (2026-09-25) found 0 leaks across 35+ sites; this pins
/// the two load-bearing points so a future denominator that iterates raw `.cards`
/// — even for a card that MATCHES the deck lens — is caught. (Precedent: #89.)

Card _card(String id, {required bool draft, List<String> tags = const ['x']}) =>
    Card(
      id: id,
      type: 'flashcard',
      title: id,
      overview: '',
      tags: tags,
      tiers: const {},
      sections: const [
        CardSection(heading: 'H', slug: 'h', content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
      status: draft ? CardStatus.draft : CardStatus.active,
    );

IndexResult _index(List<Card> cards) =>
    IndexResult(cards: cards, idless: 0, malformed: 0, skipped: 0);

class _FixedDecks extends Decks {
  _FixedDecks(this._decks);
  final List<Deck> _decks;
  @override
  Future<List<Deck>> build() async => _decks;
}

void main() {
  test('studyCards is the canonical draft-excluded denominator set', () {
    final index =
        _index([_card('active', draft: false), _card('draft', draft: true)]);
    expect(index.studyCards.map((c) => c.id).toList(), ['active']);
    expect(index.cards.length, 2); // the raw set still carries the draft
  });

  test('a deck lens over studyCards never yields a MATCHING draft', () {
    // Both cards satisfy TagIs('x'); the draft must still be excluded, because
    // decks select over studyCards — membership matching alone never re-admits it.
    final index =
        _index([_card('active', draft: false), _card('draft', draft: true)]);
    final deck =
        Deck(id: 'd', name: 'D', templateId: '', membership: TagIs('x'));
    expect(deck.select(index.studyCards).map((c) => c.id).toList(), ['active']);
  });

  test(
      'deckMemberCardIds (the member-set denominator) excludes a matching draft',
      () async {
    final index =
        _index([_card('active', draft: false), _card('draft', draft: true)]);
    final deck =
        Deck(id: 'd', name: 'D', templateId: '', membership: TagIs('x'));
    final container = ProviderContainer(overrides: [
      decksProvider.overrideWith(() => _FixedDecks([deck])),
      vaultIndexProvider.overrideWith((ref) async => index),
    ]);
    addTearDown(container.dispose);

    final members =
        await container.read(deckMemberCardIdsProvider(deck.id).future);
    expect(members, {'active'});
  });
}
