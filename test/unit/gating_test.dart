import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/plan/gating.dart';
import 'package:onyx/core/plan/practice_plan.dart';
import 'package:onyx/core/vault/card_parser.dart';

PracticeUnit _unit(String t, String cardId, [String? slug]) => PracticeUnit(
      track: t,
      id: slug == null ? cardId : '$cardId::$slug',
      label: cardId,
      estMinutes: 20,
    );

TrackAvailability _avail(String t, List<PracticeUnit> u) =>
    TrackAvailability(track: t, label: t, units: u);

void main() {
  group('prereqsMet', () {
    test('no prerequisites is always met', () {
      expect(prereqsMet(const [], const {}), isTrue);
    });
    test('needs 60% of prerequisites comfortable', () {
      const comfort = {'a': 0.9, 'b': 0.9, 'c': 0.0};
      expect(prereqsMet(['a', 'b', 'c'], comfort), isTrue); // 2/3 = 67%
      expect(prereqsMet(['a', 'c'], comfort), isFalse); // 1/2 = 50%
    });
  });

  group('cardIdOf', () {
    test('strips the section slug', () {
      expect(cardIdOf('algo-1d-dp::coin-change'), 'algo-1d-dp');
      expect(cardIdOf('design-rate-limiter'), 'design-rate-limiter');
    });
  });

  group('gatePracticeAvailabilities', () {
    test('review and learn are never gated', () {
      final avail = [
        _avail(kTrackReview, [_unit(kTrackReview, 'c', 's')]),
        _avail(kTrackLearn, [_unit(kTrackLearn, 'c', 's')]),
      ];
      final gated = gatePracticeAvailabilities(
        availabilities: avail,
        prereqsByCard: const {
          'c': ['whatever']
        },
        comfortByConcept: const {},
      );
      expect(gated[0].units.length, 1);
      expect(gated[1].units.length, 1);
    });

    test('foundational algo group (no prereqs) stays available', () {
      final gated = gatePracticeAvailabilities(
        availabilities: [
          _avail(kTrackAlgorithms,
              [_unit(kTrackAlgorithms, 'algo-two-pointers', '3sum')]),
        ],
        prereqsByCard: const {'algo-two-pointers': []},
        comfortByConcept: const {},
      );
      expect(gated.single.unlocked, isTrue);
      expect(gated.single.units.length, 1);
    });

    test('gated algo group locks when its concept is not comfortable', () {
      final gated = gatePracticeAvailabilities(
        availabilities: [
          _avail(kTrackAlgorithms,
              [_unit(kTrackAlgorithms, 'algo-1d-dp', 'coin-change')]),
        ],
        prereqsByCard: const {
          'algo-1d-dp': ['dynamic-programming-1d']
        },
        comfortByConcept: const {'dynamic-programming-1d': 0.1},
        labelForConcept: (s) => 'dynamic programming',
      );
      expect(gated.single.unlocked, isFalse);
      expect(gated.single.units, isEmpty);
      expect(gated.single.gateReason, contains('dynamic programming'));
    });

    test('gated group unlocks once the concept is comfortable', () {
      final gated = gatePracticeAvailabilities(
        availabilities: [
          _avail(kTrackAlgorithms,
              [_unit(kTrackAlgorithms, 'algo-1d-dp', 'coin-change')]),
        ],
        prereqsByCard: const {
          'algo-1d-dp': ['dynamic-programming-1d']
        },
        comfortByConcept: const {'dynamic-programming-1d': 0.8},
      );
      expect(gated.single.unlocked, isTrue);
      expect(gated.single.units.length, 1);
    });

    test('keeps the ready SD problems and drops the not-ready ones', () {
      final gated = gatePracticeAvailabilities(
        availabilities: [
          _avail(kTrackSystemDesign, [
            _unit(kTrackSystemDesign, 'design-rate-limiter'),
            _unit(kTrackSystemDesign, 'design-key-value-store'),
          ]),
        ],
        prereqsByCard: const {
          'design-rate-limiter': ['rate-limiting'],
          'design-key-value-store': [
            'consistent-hashing',
            'quorum-consistency'
          ],
        },
        comfortByConcept: const {
          'rate-limiting': 0.9,
          'consistent-hashing': 0.0,
          'quorum-consistency': 0.0,
        },
      );
      expect(gated.single.unlocked, isTrue);
      expect(gated.single.units.map((u) => u.id), ['design-rate-limiter']);
    });
  });

  // Guards the class of bug where algoGroupPrereqs keys/values drift from the
  // real vault card ids — which silently either never-gates or permanently-locks
  // a whole algorithm category. Skipped when the staged vault isn't present.
  group('algoGroupPrereqs matches the real vault', () {
    const parser = CardParser();
    final dir = Directory('staging/flashcards');
    final ids = <String>{};
    if (dir.existsSync()) {
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.md')) continue;
        try {
          final c = parser.parse(f.readAsStringSync(), filePath: f.path);
          if (c != null) ids.add(c.id);
        } catch (_) {/* malformed/idless — not relevant here */}
      }
    }

    test('every GATED group key is a real algorithm card id', () {
      final missing = [
        for (final e in algoGroupPrereqs.entries)
          if (e.value.isNotEmpty && !ids.contains(e.key)) e.key,
      ];
      expect(missing, isEmpty,
          reason: 'gated group keys with no matching card: $missing');
    });

    test('every prerequisite concept slug is a real concept card id', () {
      final prereqSlugs = {for (final v in algoGroupPrereqs.values) ...v};
      final missing = [
        for (final s in prereqSlugs)
          if (!ids.contains(s)) s,
      ];
      expect(missing, isEmpty,
          reason: 'prereq concept slugs with no matching card: $missing');
    });
  }, skip: !Directory('staging/flashcards').existsSync());
}
