import 'vault_source.dart';

/// A vault **skeleton** — relative POSIX path → file content — that, written into
/// a fresh study folder, produces a complete, self-documenting Onyx vault (task
/// #30, G5b). It carries three things: a `CLAUDE.md` so an AI opening the folder
/// is oriented and can author cards, a `_meta/onyx-subject.yaml` so the folder is
/// a defined subject, and a small **subject-neutral** starter deck so first-run
/// lands on real cards instead of the empty state (never a SWE sample — see
/// docs/content-creation.md §2.3).
///
/// Modelled as data (not hardcoded writes) so the onboarding "what are you
/// studying for?" picker can later supply a different template; only the neutral
/// [neutralStarterTemplate] ships today.
class VaultTemplate {
  const VaultTemplate({
    required this.id,
    required this.label,
    required this.files,
  });

  final String id;
  final String label;

  /// Relative POSIX path → file content. `_meta/…` and nested paths are fine;
  /// [VaultSource.writeFile] creates parent directories.
  final Map<String, String> files;
}

/// Writes [template] into [source], creating any parent directories.
Future<void> scaffoldVault(VaultSource source, VaultTemplate template) async {
  for (final entry in template.files.entries) {
    await source.writeFile(entry.key, entry.value);
  }
}

/// Scaffold a freshly-created study folder with the neutral starter skeleton —
/// the entry point the "Create a study folder" flow calls.
Future<void> scaffoldStudyFolder(VaultSource source) =>
    scaffoldVault(source, neutralStarterTemplate);

/// The default, subject-neutral skeleton: orientation + a minimal general-study
/// subject + three intro cards that double as a gentle tour of how Onyx works.
final VaultTemplate neutralStarterTemplate = VaultTemplate(
  id: 'starter',
  label: 'General study',
  files: {
    'CLAUDE.md': _neutralClaudeMd,
    '_meta/onyx-subject.yaml': _neutralSubjectYaml,
    for (final c in _starterCards) '${c.slug}.md': c.markdown,
  },
);

/// A concise, **domain-neutral** orientation for an AI (or a curious human)
/// opening a freshly-created vault. Self-contained enough to author decent cards
/// immediately; the full authoring kit (method + conventions) is installed by the
/// app's "Update authoring tools" action (task #30, G5c).
const _neutralClaudeMd = '''# Your Onyx study vault

This folder is an **Onyx study vault**: plain Markdown files that Onyx turns into
spaced-repetition cards. The folder is the source of truth — Onyx reads it, never
owns it. You can edit these files in any editor.

## What Onyx is for

Onyx **reviews**; it doesn't cram. The loop is: see a cue, recall the answer from
memory, reveal it, grade yourself honestly. A card exists to make that retrieval
effective — so author cards you can be *tested* on, not notes to re-read.

## What makes a good card

- **One idea per card.** If it tests two things, split it.
- **Lead with the trigger.** The most valuable knowledge is *when* to use an idea
  — the observable signal that says "this applies here." Put it first.
- **Encode the principle, not the fact.** Write it so you can reconstruct the
  specifics from a rule you understand, not memorize a string.
- **Make it self-testable.** If you can't recall and grade the answer on its own,
  it's a note, not a card — cut it or reshape it.

## The card format

One card = one `.md` file:

```
---
id: a-unique-slug
type: flashcard
tags: [your-topic]
---

# Card title

A one-line, principle-first overview.

## A section you can be quizzed on

The answer, written so you can reconstruct it from the idea.

## Resources
Reference links — not quizzed.
```

Each `## section` is quizzed on its own, so write each to stand alone. Sections
named Resources, Related, and Variants are reference-only (never quizzed).

## How this vault is configured

`_meta/onyx-subject.yaml` declares this subject — its card types (flows) and,
optionally, its parse rules and terminology. Onyx skips everything in `_meta/`.
Edit it to shape what this vault studies.

> Want the full authoring method + conventions in this vault? Install them from
> Onyx (Settings -> "Update authoring tools").
''';

/// A minimal, neutral subject: one of each target slot + a single concept-recall
/// flow. Enough to be a defined subject without importing any SWE specifics.
const _neutralSubjectYaml = '''# What this vault studies (edit freely).
# A subject is config, not code: readiness, flows, and parsing run off this file.
id: my-studies
target:
  # One simple slot each — grow these as your material deepens.
  levels: [{id: all, label: All, tierCurve: [1.0]}]
  contexts: [{id: standard, label: Standard, stabilityTargetDays: 90}]
  tracks: [{id: everything, label: Everything}]
  fallback: {level: all, context: standard, track: everything}
flows:
  # The spaced concept deck. Add more card types here as you add flows.
  - {cardType: flashcard, scheduling: recall, quizzability: blocklist, label: Cards}
''';

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
