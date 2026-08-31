import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/search/card_filter.dart';
import 'package:onyx/shared/models/card.dart';

Card _card(
  String id, {
  CardType type = CardType.flashcard,
  String domain = 'ds-a',
  int tier = 2,
  List<String> slugs = const ['s1'],
}) =>
    Card(
      id: id,
      type: type,
      title: id,
      overview: '',
      tags: [domain],
      tiers: {domain: tier},
      sections: [
        for (final s in slugs)
          CardSection(heading: s, slug: s, content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

void main() {
  group('parseSearchQuery', () {
    test('extracts operators and keeps free text', () {
      final r = parseSearchQuery('trees tag:ds-a is:due tier:1 type:interview');
      expect(r.text, 'trees');
      expect(r.filter.domains, {'ds-a'});
      expect(r.filter.mastery, {MasteryFilter.due});
      expect(r.filter.tiers, {1});
      expect(r.filter.types, {CardType.interviewQuestion});
    });

    test('domain: is an alias for tag:', () {
      expect(parseSearchQuery('domain:graphs').filter.domains, {'graphs'});
    });

    test('unrecognised operators fall through to free text', () {
      final r = parseSearchQuery('foo:bar hello');
      expect(r.text, 'foo:bar hello');
      expect(r.filter.isEmpty, isTrue);
    });

    test('empty query yields an empty filter and text', () {
      final r = parseSearchQuery('   ');
      expect(r.filter.isEmpty, isTrue);
      expect(r.text, '');
    });
  });

  group('matchesFilter', () {
    final card =
        _card('A', type: CardType.interviewQuestion, domain: 'ds-a', tier: 2);

    test('empty filter matches everything', () {
      expect(matchesFilter(card, const CardFilter(), const {}), isTrue);
    });

    test('type / domain / tier facets are AND-ed', () {
      expect(
          matchesFilter(card,
              const CardFilter(types: {CardType.interviewQuestion}), const {}),
          isTrue);
      expect(
          matchesFilter(
              card, const CardFilter(types: {CardType.flashcard}), const {}),
          isFalse);
      expect(matchesFilter(card, const CardFilter(domains: {'ds-a'}), const {}),
          isTrue);
      expect(
          matchesFilter(card, const CardFilter(domains: {'graphs'}), const {}),
          isFalse);
      expect(
          matchesFilter(card, const CardFilter(tiers: {2}), const {}), isTrue);
      expect(
          matchesFilter(card, const CardFilter(tiers: {1}), const {}), isFalse);
    });

    test('mastery matches on set intersection', () {
      expect(
          matchesFilter(card, const CardFilter(mastery: {MasteryFilter.due}),
              {MasteryFilter.due, MasteryFilter.fresh}),
          isTrue);
      expect(
          matchesFilter(card, const CardFilter(mastery: {MasteryFilter.strong}),
              {MasteryFilter.fresh}),
          isFalse);
    });
  });

  group('cardMastery', () {
    final now = DateTime(2026, 9, 1, 12);
    final card = _card('A', slugs: ['a', 'b', 'c']);

    test('classifies sections as fresh / due / strong', () {
      final due = {
        'A::a': now.subtract(const Duration(days: 1)), // due
        'A::c': now.add(const Duration(days: 5)), // strong
        // A::b absent → fresh
      };
      final m = cardMastery(card, due, now);
      expect(m, {MasteryFilter.due, MasteryFilter.strong, MasteryFilter.fresh});
    });

    test('all unstudied → fresh only', () {
      expect(cardMastery(card, const {}, now), {MasteryFilter.fresh});
    });
  });
}
