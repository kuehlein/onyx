import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/plan/gating.dart';
import 'package:onyx/core/plan/practice_plan.dart';

PracticeUnit _unit(TrackId t, String cardId, [String? slug]) => PracticeUnit(
      track: t,
      id: slug == null ? cardId : '$cardId::$slug',
      label: cardId,
      estMinutes: 20,
    );

TrackAvailability _avail(TrackId t, List<PracticeUnit> u) =>
    TrackAvailability(track: t, units: u);

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
        _avail(TrackId.review, [_unit(TrackId.review, 'c', 's')]),
        _avail(TrackId.learn, [_unit(TrackId.learn, 'c', 's')]),
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
          _avail(TrackId.algorithms,
              [_unit(TrackId.algorithms, 'algo-two-pointers', '3sum')]),
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
          _avail(TrackId.algorithms,
              [_unit(TrackId.algorithms, 'algo-1d-dp', 'coin-change')]),
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
          _avail(TrackId.algorithms,
              [_unit(TrackId.algorithms, 'algo-1d-dp', 'coin-change')]),
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
          _avail(TrackId.systemDesign, [
            _unit(TrackId.systemDesign, 'design-rate-limiter'),
            _unit(TrackId.systemDesign, 'design-key-value-store'),
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
}
