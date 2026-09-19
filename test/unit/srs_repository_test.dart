import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/srs/srs_repository.dart';
import 'package:onyx/core/srs/srs_scheduler.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// See database_test.dart — skip when host libsqlite3 is unavailable.
final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

ReviewOutcome _outcome(DateTime at, {double stability = 3}) => ReviewOutcome(
      stability: stability,
      difficulty: 5,
      state: 2,
      step: null,
      due: at.add(const Duration(days: 1)),
      lastReview: at,
      elapsedDays: 0,
    );

void main() {
  group('SrsRepository', () {
    late AppDatabase db;
    late SrsRepository repo;

    setUp(() {
      db = AppDatabase.withExecutor(NativeDatabase.memory());
      repo = SrsRepository(db);
    });

    tearDown(() => db.close());

    test('records a review: upserts state and appends the log', () async {
      final at = DateTime.utc(2026, 1, 1, 9);
      await repo.recordReview(
        cardId: 'card-a',
        sectionSlug: 'when-to-use',
        grade: 3,
        outcome: _outcome(at),
      );

      final states = await repo.loadStates();
      expect(states.keys, contains('card-a::when-to-use'));
      final s = states['card-a::when-to-use']!;
      expect(s.stability, 3);
      expect(s.reviewCount, 1);
      expect(s.dueAt.isAfter(at), isTrue);

      final logs = await db.select(db.reviews).get();
      expect(logs.length, 1);
      expect(logs.single.grade, 3);
    });

    test('a second review updates state and increments reviewCount', () async {
      final at = DateTime.utc(2026, 1, 1, 9);
      await repo.recordReview(
        cardId: 'card-a',
        sectionSlug: 'when-to-use',
        grade: 3,
        outcome: _outcome(at, stability: 3),
      );
      await repo.recordReview(
        cardId: 'card-a',
        sectionSlug: 'when-to-use',
        grade: 4,
        outcome: _outcome(at.add(const Duration(days: 1)), stability: 12),
      );

      final states = await repo.loadStates();
      expect(states.length, 1); // still one row (upsert, not insert)
      expect(states['card-a::when-to-use']!.stability, 12);
      expect(states['card-a::when-to-use']!.reviewCount, 2);

      expect((await db.select(db.reviews).get()).length, 2); // log keeps both
    });

    test('a lapse persists relearning state and shows in lapsesByCard',
        () async {
      final at = DateTime.utc(2026, 1, 1, 9);
      // A successful review first (the card is in the review state)…
      await repo.recordReview(
        cardId: 'card-a',
        sectionSlug: 's',
        grade: 3,
        outcome: _outcome(at, stability: 20),
      );
      // …then a lapse: Again → relearning, as the scheduler would produce.
      await repo.recordReview(
        cardId: 'card-a',
        sectionSlug: 's',
        grade: 1,
        outcome: ReviewOutcome(
          stability: 2,
          difficulty: 6,
          state: 3, // relearning
          step: 0,
          due: at.add(const Duration(minutes: 10)),
          lastReview: at.add(const Duration(days: 5)),
          elapsedDays: 5,
        ),
      );

      final s = (await repo.loadStates())['card-a::s']!;
      expect(s.state, 3, reason: 'relearning state persisted');
      expect(s.stability, 2);
      expect(s.reviewCount, 2, reason: 'upsert incremented; still one row');

      final row =
          (await repo.lapsesByCard()).firstWhere((r) => r.cardId == 'card-a');
      expect(row.lapses, 1, reason: 'one Again counted as a lapse');
      expect(row.total, 2);
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
