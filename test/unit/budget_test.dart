import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/budget.dart';
import 'package:onyx/core/deck/deck.dart';

final _today = DateTime(2026, 1, 1);

Deck _g(String id,
        {PriorityTier priority = PriorityTier.normal,
        DeckState state = DeckState.active,
        List<Aim> aims = const []}) =>
    Deck(
        id: id,
        name: id,
        templateId: 't',
        priority: priority,
        state: state,
        aims: aims);

Aim _aim(String id, PriorityTier importance, {DateTime? date}) => Aim(
      id: id,
      importance: importance,
      rounds: date == null
          ? const []
          : [InterviewRound(id: '$id-r', number: 1, date: date)],
    );

void main() {
  group('deadlineFactor', () {
    test('undated or far → 1.0; ramps up as the date nears; peak on/after', () {
      expect(deadlineFactor(null, _today), 1.0);
      expect(deadlineFactor(_today.add(const Duration(days: 90)), _today), 1.0);
      expect(deadlineFactor(_today, _today), kDeadlinePeak); // on the date
      expect(deadlineFactor(_today.subtract(const Duration(days: 1)), _today),
          kDeadlinePeak); // past → still peak
      final near = deadlineFactor(_today.add(const Duration(days: 10)), _today);
      final far = deadlineFactor(_today.add(const Duration(days: 40)), _today);
      expect(near, greaterThan(far));
      expect(far, greaterThan(1.0));
    });
  });

  group('deckPriorityWeight', () {
    test('a coverage-only deck (no active aims) uses its deck tier', () {
      expect(deckPriorityWeight(_g('a'), _today), PriorityTier.normal.weight);
      expect(
          deckPriorityWeight(_g('a', priority: PriorityTier.highest), _today),
          PriorityTier.highest.weight);
    });

    test('with aims: the MAX aim importance drives it (interleaving unit)', () {
      // A deck with a highest + a low aim pulls at the highest (the wedged case).
      final deck = _g('a', aims: [
        _aim('hi', PriorityTier.highest),
        _aim('lo', PriorityTier.low),
      ]);
      expect(deckPriorityWeight(deck, _today), PriorityTier.highest.weight);
    });

    test('a soon deadline raises the weight above the bare tier', () {
      final undated = _g('a', aims: [_aim('x', PriorityTier.high)]);
      final soon = _g('b', aims: [
        _aim('x', PriorityTier.high, date: _today.add(const Duration(days: 5)))
      ]);
      expect(deckPriorityWeight(soon, _today),
          greaterThan(deckPriorityWeight(undated, _today)));
    });

    test('paused/ended aims are ignored (fall back to the deck tier)', () {
      const deck = Deck(
        id: 'a',
        name: 'a',
        templateId: 't',
        priority: PriorityTier.low,
        aims: [
          Aim(id: 'muted', active: false, importance: PriorityTier.highest),
          Aim(
              id: 'done',
              status: InterviewStatus.rejected,
              importance: PriorityTier.highest),
        ],
      );
      expect(deckPriorityWeight(deck, _today), PriorityTier.low.weight);
    });
  });

  group('allocateBudget', () {
    test('a single active goal gets the whole budget', () {
      expect(allocateBudget(goals: [_g('a')], totalMinutes: 150, today: _today),
          {'a': 150.0});
    });

    test('equal (all-normal, no deadlines) splits evenly — byte-identical', () {
      final b = allocateBudget(
          goals: [_g('a'), _g('b')], totalMinutes: 150, today: _today);
      expect(b, {'a': 75.0, 'b': 75.0});
    });

    test('a higher-priority deck gets a bigger share; none below the floor',
        () {
      final b = allocateBudget(
        goals: [
          _g('a', priority: PriorityTier.highest),
          _g('b', priority: PriorityTier.low)
        ],
        totalMinutes: 150,
        today: _today,
      );
      expect(b['a']!, greaterThan(b['b']!));
      expect(b['b']!, greaterThanOrEqualTo(kEngagementFloorMinutes));
      // 2.0 vs 0.5 over a 15-min floor, 120 remainder: 111 vs 39.
      expect(b['a']!, closeTo(111, 0.5));
      expect(b['b']!, closeTo(39, 0.5));
    });

    test('a paused goal drops out and its share redistributes', () {
      final b = allocateBudget(
        goals: [_g('a'), _g('b', state: DeckState.paused), _g('c')],
        totalMinutes: 120,
        today: _today,
      );
      expect(b.containsKey('b'), isFalse);
      expect(b, {'a': 60.0, 'c': 60.0});
    });

    test('floors that exceed the budget scale down to an equal split', () {
      // 3 active decks × 15-min floor = 45 > 30 → equal 10 each (warn on the result).
      final b = allocateBudget(
          goals: [_g('a'), _g('b'), _g('c')], totalMinutes: 30, today: _today);
      expect(b, {'a': 10.0, 'b': 10.0, 'c': 10.0});
    });

    test('no active goals → empty', () {
      expect(
        allocateBudget(
            goals: [_g('a', state: DeckState.paused)],
            totalMinutes: 100,
            today: _today),
        isEmpty,
      );
    });
  });

  group('deckAllocationWarning', () {
    test('below the engagement floor → tooLittle', () {
      expect(
          deckAllocationWarning(allocatedMinutes: 10, hasLongSessions: false),
          DeckAllocationWarning.tooLittle);
    });

    test('a deck with long sessions under a session cost → longSessionWontFit',
        () {
      expect(
        deckAllocationWarning(
            allocatedMinutes: 25,
            hasLongSessions: true,
            longSessionMinutes: 40),
        DeckAllocationWarning.longSessionWontFit,
      );
    });

    test('enough time, or no long sessions → none', () {
      expect(
          deckAllocationWarning(allocatedMinutes: 25, hasLongSessions: false),
          DeckAllocationWarning.none);
      expect(
        deckAllocationWarning(
            allocatedMinutes: 45,
            hasLongSessions: true,
            longSessionMinutes: 40),
        DeckAllocationWarning.none,
      );
    });

    test('the engagement floor takes precedence over the long-session check',
        () {
      expect(deckAllocationWarning(allocatedMinutes: 5, hasLongSessions: true),
          DeckAllocationWarning.tooLittle);
    });
  });
}
