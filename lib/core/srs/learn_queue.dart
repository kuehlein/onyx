import 'dart:math';

import '../../shared/models/card.dart';

/// One never-studied section to learn (as opposed to review).
class LearnItem {
  const LearnItem({required this.card, required this.section});

  final Card card;
  final CardSection section;

  String get key => '${card.id}::${section.slug}';
}

/// Builds the "learn new material" queue: quizzable sections that have never
/// been seeded into FSRS (no `srs_state` row yet), ordered for first exposure.
///
/// Ordering follows the learning-science synthesis — BLOCK related material for
/// first learning (the opposite of the review path's interleaving):
///  1. keep only cards with at least one un-seeded quizzable section;
///  2. cluster them into families via the wikilink graph (connected components);
///  3. within a family, foundational-first (lowest tier, then title);
///  4. most-foundational family first;
///  5. flatten to sections and cap at [newSectionLimit] so a session doesn't
///     introduce too much at once.
List<LearnItem> buildLearnQueue({
  required List<Card> cards,
  required Set<String> seededKeys,
  required Map<String, Set<String>> adjacency,
  int newSectionLimit = 20,
}) {
  final byId = {for (final c in cards) c.id: c};

  bool hasNewSection(Card c) => c.quizzableSections
      .any((s) => !seededKeys.contains('${c.id}::${s.slug}'));

  final learnable = cards.where(hasNewSection).toList();
  final learnableIds = {for (final c in learnable) c.id};

  // Connected components over the learnable subgraph (undirected).
  final visited = <String>{};
  final components = <List<Card>>[];
  for (final start in learnable) {
    if (!visited.add(start.id)) continue;
    final component = <Card>[];
    final stack = <String>[start.id];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      component.add(byId[id]!);
      for (final neighbor in adjacency[id] ?? const <String>{}) {
        if (learnableIds.contains(neighbor) && visited.add(neighbor)) {
          stack.add(neighbor);
        }
      }
    }
    components.add(component);
  }

  int minTier(Card c) => c.tiers.isEmpty ? 99 : c.tiers.values.reduce(min);
  int familyTier(List<Card> f) => f.map(minTier).reduce(min);

  for (final family in components) {
    family.sort((a, b) {
      final byTier = minTier(a).compareTo(minTier(b));
      return byTier != 0 ? byTier : a.title.compareTo(b.title);
    });
  }
  components.sort((a, b) {
    final byTier = familyTier(a).compareTo(familyTier(b));
    return byTier != 0 ? byTier : b.length.compareTo(a.length);
  });

  final items = <LearnItem>[];
  for (final family in components) {
    for (final card in family) {
      for (final section in card.quizzableSections) {
        if (seededKeys.contains('${card.id}::${section.slug}')) continue;
        items.add(LearnItem(card: card, section: section));
        if (items.length >= newSectionLimit) return items;
      }
    }
  }
  return items;
}

/// Whether a section is best learned by attempting first (pretest → reveal) vs.
/// simply read (pre-study). Conditional "when/why" knowledge benefits from a
/// generate-then-reveal attempt; dense declarative scaffolding is better read.
bool isPretestSection(String heading) {
  final h = heading.toLowerCase();
  const cues = [
    'when to use',
    'recognition',
    'trigger',
    'pitfall',
    'trade-off',
    'tradeoff',
    'approach',
    'gotcha',
    'common mistake',
    'why',
  ];
  return cues.any(h.contains);
}
