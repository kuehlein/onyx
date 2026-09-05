import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/srs/recognition.dart';
import 'package:onyx/core/srs/recognition_repository.dart';

void main() {
  final now = DateTime(2026, 9, 5);

  group('scheduleRecognition', () {
    test('first solid explanation lands at 3 days, streak 1', () {
      final r = scheduleRecognition(outcome: ExplainOutcome.solid, now: now);
      expect(r.intervalDays, 3);
      expect(r.streak, 1);
      expect(r.dueAt, now.add(const Duration(days: 3)));
    });

    test('solid explanations expand the spacing along the steps', () {
      final steps = <int>[];
      var streak = 0;
      for (var i = 0; i < 6; i++) {
        final r = scheduleRecognition(
            outcome: ExplainOutcome.solid, now: now, priorStreak: streak);
        steps.add(r.intervalDays);
        streak = r.streak;
      }
      // 3 → 7 → 16 → 35 → 90, then caps at 90.
      expect(steps, [3, 7, 16, 35, 90, 90]);
      expect(streak, 6);
    });

    test('shaky holds the streak and comes back at the short end', () {
      final r = scheduleRecognition(
          outcome: ExplainOutcome.shaky, now: now, priorStreak: 4);
      expect(r.intervalDays, 3);
      expect(r.streak, 4); // unchanged
    });

    test('lost resets to tomorrow and zeroes the streak', () {
      final r = scheduleRecognition(
          outcome: ExplainOutcome.lost, now: now, priorStreak: 5);
      expect(r.intervalDays, 1);
      expect(r.streak, 0);
      expect(r.dueAt, now.add(const Duration(days: 1)));
    });
  });

  group('RecognitionRepository', () {
    late AppDatabase db;
    late RecognitionRepository repo;
    setUp(() {
      db = AppDatabase.withExecutor(NativeDatabase.memory());
      repo = RecognitionRepository(db);
    });
    tearDown(() => db.close());

    test('records and expands across explanations of the same problem',
        () async {
      final first = await repo.recordExplain(
        cardId: 'algo-stack',
        sectionSlug: 'valid-parens',
        outcome: ExplainOutcome.solid,
        now: now,
      );
      expect(first.intervalDays, 3);
      expect(first.streak, 1);

      final second = await repo.recordExplain(
        cardId: 'algo-stack',
        sectionSlug: 'valid-parens',
        outcome: ExplainOutcome.solid,
        now: now.add(const Duration(days: 3)),
      );
      expect(second.intervalDays, 7);
      expect(second.streak, 2);

      final states = await repo.loadStates();
      final s = states['algo-stack::valid-parens']!;
      expect(s.streak, 2);
      expect(s.intervalDays, 7);
    });

    test('a lost explanation resets the stored streak', () async {
      await repo.recordExplain(
        cardId: 'c',
        sectionSlug: 's',
        outcome: ExplainOutcome.solid,
        now: now,
      );
      await repo.recordExplain(
        cardId: 'c',
        sectionSlug: 's',
        outcome: ExplainOutcome.lost,
        now: now.add(const Duration(days: 1)),
      );
      final s = (await repo.loadStates())['c::s']!;
      expect(s.streak, 0);
      expect(s.intervalDays, 1);
    });
  });
}
