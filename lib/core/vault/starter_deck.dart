import 'vault_source.dart';

/// Seeds a tiny, subject-neutral starter deck into a freshly-created study
/// folder so first-run lands on real cards instead of the empty state — the
/// "zero deck-building" half of the two-taps-to-first-review promise
/// (docs/product-direction.md §10). The cards double as a gentle intro to how
/// Onyx works (recall-first review, what a good card looks like, spaced
/// repetition); they are deliberately generic, never subject-specific.
///
/// Each card is written in the same shape the real [CardParser] expects: a
/// `---` frontmatter block with `id` + `type: flashcard` (plus `tags` and a
/// `## ` recall section), then an H1 title. No `deck:` field — it defaults to
/// the local deck. Slugs are used for ids so they read cleanly in Browse.
Future<void> seedStarterDeck(VaultSource source) async {
  for (final card in _starterCards) {
    await source.writeFile('${card.slug}.md', card.markdown);
  }
}

class _StarterCard {
  const _StarterCard(this.slug, this.markdown);
  final String slug;
  final String markdown;
}

const _starterCards = <_StarterCard>[
  _StarterCard('how-reviewing-works', '''---
id: how-reviewing-works
type: flashcard
tags:
  - getting-started
confidence: high
---

# How reviewing works

Onyx shows you one card at a time. First you try to answer from memory, then
you reveal the answer and grade yourself honestly.

## The review loop

1. Read the prompt and recall the answer *before* revealing it — the effort of
   retrieving is what strengthens the memory.
2. Reveal the answer and compare it to what you thought.
3. Grade yourself honestly. "Again" if you blanked, up to "Easy" if it was
   effortless. Honest grades let the schedule work; flattering yourself only
   hurts future-you.
'''),
  _StarterCard('what-makes-a-good-flashcard', '''---
id: what-makes-a-good-flashcard
type: flashcard
tags:
  - getting-started
confidence: high
---

# What makes a good flashcard

The best cards are small and focused, so recall is quick and grading is clear.

## Three simple rules

- **One idea per card.** If a card tests two things, split it in two.
- **Ask a question.** A card that asks something specific is easier to recall
  than a wall of notes.
- **Keep the answer short.** A sentence or two you can hold in your head beats a
  paragraph you skim.
'''),
  _StarterCard('spaced-repetition', '''---
id: spaced-repetition
type: flashcard
tags:
  - getting-started
confidence: high
---

# Spaced repetition

Reviewing something right before you would have forgotten it is far more
effective than cramming it many times in one sitting.

## Why the gaps grow

Each time you successfully recall a card, Onyx waits a little longer before
showing it again — days, then weeks, then months. Stretching the interval as
the memory strengthens keeps it durable with the fewest reviews. You don't pick
the timing; Onyx schedules each card for you.
'''),
];
