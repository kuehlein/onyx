import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/shared/models/card.dart';

/// Characterization tests written BEFORE the #30c Phase 4 `CardType` removal
/// (adversarial safeguard). They lock the current type-driven behavior the audit
/// flagged as highest-risk — card-ness, the hyphenated type strings, the
/// isPracticeTrack truth table (the readiness recall-coverage denominator), and
/// quizzability-by-type. These EXPECTED VALUES must survive the flip to a
/// String-typed `Card.type`; only the query expressions change with it.
Card? _parse(String type, {List<String> sections = const []}) {
  final body = StringBuffer('''
---
id: c-$type
type: $type
tags:
  - ds-a
---

# Title

Overview line.
''');
  for (final s in sections) {
    body.writeln('\n## $s\n\nBody of $s.');
  }
  return const CardParser().parse(body.toString(), filePath: 'c.md');
}

const _validTypes = [
  'flashcard',
  'interview-question',
  'algorithm',
  'system-design',
  'behavioral',
];

void main() {
  group('card-ness', () {
    test('every configured type parses to a card', () {
      for (final t in _validTypes) {
        expect(_parse(t), isNotNull, reason: t);
      }
    });

    test('an unrecognized type is NOT a card (skipped)', () {
      expect(_parse('journal'), isNull);
    });

    test('a note with no type: is not a card', () {
      expect(
          const CardParser()
              .parse('# Just a note\n\nno frontmatter type', filePath: 'n.md'),
          isNull);
    });
  });

  test('type value strings are the exact hyphenated frontmatter forms', () {
    for (final t in _validTypes) {
      expect(_parse(t)!.type, t, reason: t);
    }
  });

  group('isPracticeTrack truth table (readiness denominator guard)', () {
    const expected = {
      'flashcard': false,
      'interview-question': false,
      'algorithm': true,
      'system-design': true,
      'behavioral': true,
    };
    test('each type', () {
      expected.forEach((t, isPractice) {
        expect(_parse(t)!.isPracticeTrack, isPractice, reason: t);
      });
    });

    test('recall-coverage population = the two concept types only', () {
      final cards = [for (final t in _validTypes) _parse(t)!];
      final concept = cards.where((c) => !c.isPracticeTrack).toList();
      expect(concept.map((c) => c.type), ['flashcard', 'interview-question']);
    });
  });

  group('isApproachCard truth table (config-driven, invariant #2)', () {
    // The approach-only policy that used to be a hardcoded
    // `type == 'interview-question'` UI branch (quiz/practice/detail/coach) — now
    // derived from the flow's QuizzabilityPolicy.approachOnly.
    const expected = {
      'flashcard': false,
      'interview-question': true,
      'algorithm': false,
      'system-design': false,
      'behavioral': false,
    };
    test('each type', () {
      expected.forEach((t, isApproach) {
        expect(_parse(t)!.isApproachCard, isApproach, reason: t);
      });
    });
  });

  group('quizzability by type', () {
    test('flashcard: normal section quizzable, blocklist heading not', () {
      final c = _parse('flashcard', sections: ['Detail', 'Related'])!;
      expect(c.sections.firstWhere((s) => s.heading == 'Detail').quizzable,
          isTrue);
      expect(c.sections.firstWhere((s) => s.heading == 'Related').quizzable,
          isFalse);
    });

    test('interview-question: only Approach quizzable', () {
      final c = _parse('interview-question', sections: ['Approach', 'Detail'])!;
      expect(c.sections.firstWhere((s) => s.heading == 'Approach').quizzable,
          isTrue);
      expect(c.sections.firstWhere((s) => s.heading == 'Detail').quizzable,
          isFalse);
    });

    test('algorithm: every section quizzable', () {
      final c = _parse('algorithm', sections: ['Problem A', 'Problem B'])!;
      expect(c.sections.every((s) => s.quizzable), isTrue);
    });

    test('system-design / behavioral: no section quizzable', () {
      for (final t in ['system-design', 'behavioral']) {
        final c = _parse(t, sections: ['Phase 1', 'Phase 2'])!;
        expect(c.sections.any((s) => s.quizzable), isFalse, reason: t);
      }
    });
  });
}
