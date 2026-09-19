import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/shared/models/card.dart';

const _parser = CardParser();

const _conceptCard = '''
---
id: 11111111-1111-4111-8111-111111111111
type: flashcard
tags:
  - ds-a
  - binary-search
  - searching
tiers:
  ds-a: 1
  system-design: 2
created: 2026-08-19
confidence: high
priority: high
---

# Binary Search

Halve the search space each step.

## When to Use

Sorted input, or a monotone predicate.

## Time & Space Complexity

O(log n) — each step discards half the range.

## Resources

- https://example.com/binary-search

## Related

- [[two-pointers]]
- [[sorting]]
- [[two-pointers]]
''';

const _interviewCard = '''
---
id: 22222222-2222-4222-8222-222222222222
type: interview-question
category: coding
difficulty: easy
frequency: high
domains: [ds-a]
concepts:
  - hash-map
  - array
source: blind-75
practice_url: https://neetcode.io/problems/two-integer-sum
created: 2026-08-20
confidence: high
---

# Two Sum

Given nums and target, return indices of the two numbers adding to target.

## Approach

Hash map complement lookup.

## Complexity

Time: O(n). Space: O(n).

## Follow-up Questions

- Sorted? Two pointers.

## Related Concepts

- [[hash-map]]
''';

const _systemDesignCard = '''
---
id: design-rate-limiter
type: system-design
tags:
  - system-design
  - rate-limiting
tiers:
  system-design: 2
created: 2026-09-11
confidence: high
---

# Design a Rate Limiter

Cap request rate fairly without becoming a bottleneck.

## Problem & Requirements

Functional and non-functional requirements.

## Estimation

Back-of-envelope QPS and storage.

## Deep Dives

Token bucket vs sliding window.

## Related

- [[rate-limiting]]
- [[caching]]
''';

// A fenced code block containing a line that looks like an H2 must NOT be
// parsed as a new section.
const _fenceCard = '''
---
id: 33333333-3333-4333-8333-333333333333
type: flashcard
tags: [ds-a]
created: 2026-08-19
---

# Fence Test

Overview line.

## Implementation Notes

```js
function f() {
  // ## not a heading — this is inside a fence
  return 1;
}
```

## Key Properties

A real section after the fence.
''';

const _overrideCard = '''
---
id: 55555555-5555-4555-8555-555555555555
type: flashcard
tags: [ds-a]
quiz:
  - when-to-use
created: 2026-08-19
---

# Override Test

o

## When to Use

a

## Key Properties

b
''';

void main() {
  group('CardParser.slugify', () {
    test('collapses non-alphanumerics to single hyphens', () {
      expect(CardParser.slugify('When to Use'), 'when-to-use');
      expect(CardParser.slugify('Time & Space Complexity'),
          'time-space-complexity');
      expect(CardParser.slugify('Follow-up Questions'), 'follow-up-questions');
      expect(CardParser.slugify('vs Alternative'), 'vs-alternative');
      expect(CardParser.slugify('Approach'), 'approach');
    });
  });

  group('concept card (type: flashcard)', () {
    late final Card card;
    setUpAll(() => card = _parser.parse(_conceptCard, filePath: 'x.md')!);

    test('parses frontmatter', () {
      expect(card.id, '11111111-1111-4111-8111-111111111111');
      expect(card.type, 'flashcard');
      expect(card.title, 'Binary Search');
      expect(card.tags, ['ds-a', 'binary-search', 'searching']);
      expect(card.tiers, {'ds-a': 1, 'system-design': 2});
      expect(card.confidence, Confidence.high);
      expect(card.priority, Priority.high);
      expect(card.created, DateTime(2026, 8, 19));
      expect(card.domain, 'ds-a');
    });

    test('captures pre-H2 overview', () {
      expect(card.overview, 'Halve the search space each step.');
    });

    test('splits H2 sections with slugs', () {
      expect(
        card.sections.map((s) => s.slug),
        ['when-to-use', 'time-space-complexity', 'resources', 'related'],
      );
      expect(card.sections.first.content,
          'Sorted input, or a monotone predicate.');
    });

    test('applies the blocklist to quizzable', () {
      bool quizzable(String slug) =>
          card.sections.firstWhere((s) => s.slug == slug).quizzable;
      expect(quizzable('when-to-use'), isTrue);
      expect(quizzable('time-space-complexity'), isTrue);
      expect(quizzable('resources'), isFalse);
      expect(quizzable('related'), isFalse);
      expect(card.quizzableSections.length, 2);
    });

    test('extracts de-duplicated wikilinks in order', () {
      expect(card.wikilinks, ['two-pointers', 'sorting']);
    });
  });

  group('interview-question card', () {
    late final Card card;
    setUpAll(() => card = _parser.parse(_interviewCard, filePath: 'q.md')!);

    test('parses question-specific frontmatter', () {
      expect(card.type, 'interview-question');
      expect(card.category, 'coding');
      expect(card.difficulty, 'easy');
      expect(card.frequency, 'high');
      expect(card.domains, ['ds-a']);
      expect(card.concepts, ['hash-map', 'array']);
      expect(card.source, 'blind-75');
      expect(card.practiceUrl, 'https://neetcode.io/problems/two-integer-sum');
    });

    test('problem statement lands in overview', () {
      expect(card.overview, contains('Given nums and target'));
    });

    test('quizzes only the Approach section by default', () {
      expect(card.quizzableSections.map((s) => s.slug), ['approach']);
    });
  });

  group('system-design card', () {
    late final Card card;
    setUpAll(() => card = _parser.parse(_systemDesignCard, filePath: 'sd.md')!);

    test('parses as a system-design card', () {
      expect(card.type, 'system-design');
      expect(card.isPracticeTrack, isTrue);
      expect(card.title, 'Design a Rate Limiter');
    });

    test('no section is quizzable (the whole problem is the practice unit)',
        () {
      expect(card.quizzableSections, isEmpty);
      expect(card.sections.map((s) => s.heading),
          containsAll(<String>['Problem & Requirements', 'Estimation']));
    });
  });

  group('section splitting is fence-aware', () {
    late final Card card;
    setUpAll(() => card = _parser.parse(_fenceCard, filePath: 'f.md')!);

    test('ignores ## lines inside fenced code blocks', () {
      expect(card.sections.map((s) => s.heading),
          ['Implementation Notes', 'Key Properties']);
    });

    test('keeps the fenced pseudo-heading as section content', () {
      final impl = card.sections.first;
      expect(impl.content, contains('## not a heading'));
    });
  });

  group('quiz frontmatter override', () {
    test('restricts quizzable sections to the listed slugs', () {
      final card = _parser.parse(_overrideCard, filePath: 'o.md')!;
      expect(card.quizOverride, ['when-to-use']);
      expect(card.quizzableSections.map((s) => s.slug), ['when-to-use']);
    });
  });

  group('non-cards return null', () {
    test('no frontmatter', () {
      expect(_parser.parse('# Just a note\n\nbody', filePath: 'n.md'), isNull);
    });

    test('frontmatter without a type', () {
      const md = '---\ntitle: Meta\n---\n\n# Tags Index\n';
      expect(_parser.parse(md, filePath: '_meta/tags.md'), isNull);
    });

    test('unrecognized type', () {
      const md = '---\ntype: kanban\n---\n\n# Board\n';
      expect(_parser.parse(md, filePath: 'board.md'), isNull);
    });
  });

  group('invalid cards throw', () {
    test('valid type but missing id → MissingCardIdException', () {
      const md =
          '---\ntype: flashcard\ntags: [ds-a]\n---\n\n# X\n\n## When to Use\n\ny\n';
      expect(
        () => _parser.parse(md, filePath: 'noid.md'),
        throwsA(isA<MissingCardIdException>()),
      );
    });

    test('card without an H1 → MalformedCardException', () {
      const md = '---\nid: 44444444-4444-4444-8444-444444444444\n'
          'type: flashcard\n---\n\nBody with no heading.\n\n## When to Use\n\ny\n';
      expect(
        () => _parser.parse(md, filePath: 'notitle.md'),
        throwsA(isA<MalformedCardException>()),
      );
    });
  });

  // Real Obsidian vaults are messy; a parse crash aborts indexing for the WHOLE
  // vault, so the parser must degrade gracefully (null/typed-throw), never throw
  // a raw error. These pin that contract on the ugly inputs the fixtures miss.
  group('adversarial / messy inputs', () {
    test('CRLF line endings parse the same as LF', () {
      const md = '---\r\nid: crlf-1\r\ntype: flashcard\r\ntags: [x]\r\n---\r\n'
          '\r\n# Title\r\n\r\n## When to Use\r\n\r\nBody.\r\n';
      final card = _parser.parse(md, filePath: 'crlf.md')!;
      expect(card.id, 'crlf-1');
      expect(card.title, 'Title');
      expect(card.tags, ['x']);
      expect(card.sections.map((s) => s.heading), ['When to Use']);
    });

    test('malformed frontmatter YAML is skipped (null), not a crash', () {
      // An unterminated flow sequence → loadYaml throws → the parser returns
      // null (skip this file) rather than aborting the whole index.
      const md = '---\nid: bad\ntype: flashcard\ntags: [x, y\n'
          '---\n\n# T\n\n## S\n\ny\n';
      expect(_parser.parse(md, filePath: 'bad.md'), isNull);
    });

    test('an H2 before the H1 is malformed (missing title) → typed throw', () {
      const md = '---\nid: h2first\ntype: flashcard\n---\n\n'
          '## Section First\n\nbody\n\n# Title\n';
      expect(
        () => _parser.parse(md, filePath: 'h2first.md'),
        throwsA(isA<MalformedCardException>()),
      );
    });

    test('an unterminated code fence after the H1 does not crash', () {
      // The fence opens and never closes; everything after is swallowed as
      // fenced content, so the card keeps its title and simply has no sections.
      const md = '---\nid: fence\ntype: flashcard\n---\n\n# Title\n\n'
          '```\nnot closed\n## Not A Heading\n';
      final card = _parser.parse(md, filePath: 'fence.md')!;
      expect(card.title, 'Title');
      expect(card.sections, isEmpty);
    });

    test('duplicate section headings parse without crashing (both kept)', () {
      const md = '---\nid: dup\ntype: flashcard\n---\n\n# T\n\n'
          '## Same\n\nfirst\n\n## Same\n\nsecond\n';
      final card = _parser.parse(md, filePath: 'dup.md')!;
      expect(card.sections.length, 2);
      expect(card.sections.map((s) => s.slug), ['same', 'same']);
    });
  });

  // While the staged cards still exist in the repo, parse every one to catch
  // real-world formatting the fixtures miss. Skipped automatically once the
  // cards are promoted to the vault and staging/ is removed.
  group('real staged cards smoke test', () {
    final dir = Directory('staging/flashcards');
    final files = dir.existsSync()
        ? dir.listSync().whereType<File>().where((f) => f.path.endsWith('.md'))
        : <File>[];

    for (final file in files) {
      test('parses ${file.uri.pathSegments.last}', () {
        final card =
            _parser.parse(file.readAsStringSync(), filePath: file.path);
        expect(card, isNotNull, reason: '${file.path} should be a valid card');
        expect(card!.id, isNotEmpty);
        expect(card.title, isNotEmpty);
        final slugs = card.sections.map((s) => s.slug).toList();
        expect(slugs.toSet().length, slugs.length,
            reason: 'section slugs must be unique within a card');
      });
    }
  }, skip: !Directory('staging/flashcards').existsSync());

  group('behavioral cards', () {
    final card = _parser.parse('''
---
id: behavioral-conflict-and-backbone
type: behavioral
tags: [behavioral, conflict]
---

# Conflict & Backbone

Disagree, then commit.

## Prompts

- Tell me about a disagreement with your manager.

## What strong looks like

Real stakes, upward influence, commitment.
''', filePath: 'b.md')!;

    test('parses the behavioral type and is a practice track', () {
      expect(card.type, 'behavioral');
      expect(card.isPracticeTrack, isTrue);
      expect(card.domain, 'behavioral');
    });

    test('sections are non-quizzable (prompt bank / grader ground truth)', () {
      expect(card.sections.map((s) => s.slug),
          containsAll(['prompts', 'what-strong-looks-like']));
      expect(card.quizzableSections, isEmpty);
    });
  });

  group('est_minutes override', () {
    Card parse(String fm) => _parser.parse('''
---
id: 22222222-2222-4222-8222-222222222222
type: flashcard
tags: [ds-a]
$fm---

# T

## When to Use

a
''', filePath: 't.md')!;

    test('is null when absent', () {
      expect(parse('').estMinutes, isNull);
    });
    test('parses a positive number', () {
      expect(parse('est_minutes: 12\n').estMinutes, 12);
      expect(parse('est_minutes: 7.5\n').estMinutes, 7.5);
    });
    test('rejects zero, negatives and junk', () {
      expect(parse('est_minutes: 0\n').estMinutes, isNull);
      expect(parse('est_minutes: -5\n').estMinutes, isNull);
      expect(parse('est_minutes: soon\n').estMinutes, isNull);
    });
  });
}
