import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/srs/learn_queue.dart';
import 'package:onyx/core/srs/review_queue.dart';
import 'package:onyx/core/srs/srs_repository.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/learn.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/vault.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// S0 characterization (ADR-0012 / task 1f): pins the two study grade paths at
/// the SESSION-NOTIFIER + DB level BEFORE the card-widget unify touches them, so
/// the later refactor cannot silently merge them. The load-bearing invariant is
/// that Learn and Review are DIFFERENT DB writes:
///   • Learn Good = `seedState` — an srs_state row + an `activity_log` 'learn'
///     event, and NO `reviews` row (the forgetting curve fits from the first real
///     review, not this first-study event).
///   • Review grade = `recordReview` — a `reviews` row + an upsert that increments
///     reviewCount, threading the prior FSRS state.
/// These drive the REAL notifiers' `grade()` against a real in-memory DB (only the
/// queue is stubbed via `build()`), so a regression in scheduling semantics fails.

final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

final _past = DateTime(2000);

const _section = CardSection(
    heading: 'Definition', slug: 'def', content: 'body', quizzable: true);

Card _card(String id) => Card(
      id: id,
      type: 'flashcard',
      title: id,
      overview: '',
      tags: const ['ds-a'],
      tiers: const {'ds-a': 1},
      sections: const [_section],
      wikilinks: const [],
      filePath: '$id.md',
    );

const _deck =
    Deck(id: 'default', name: 'All', templateId: 'software-interviews');

class _FixedDecks extends Decks {
  @override
  Future<List<Deck>> build() async => const [_deck];
}

/// A Learn session pinned to one item; the real [LearnSession.grade] runs.
class _OneLearn extends LearnSession {
  _OneLearn(this._item);
  final LearnItem _item;
  @override
  Future<LearnSessionState> build() async =>
      LearnSessionState(queue: [_item], graduated: 0);
}

/// A Review session pinned to one item, threading whatever prior state the DB
/// holds (so the real [StudySession.grade] sees the existing FSRS state).
class _OneReview extends StudySession {
  _OneReview(this._item);
  final ReviewItem _item;
  @override
  Future<SessionState> build() async {
    final states = await ref.read(srsRepositoryProvider).loadStates();
    return SessionState(queue: [_item], statesByKey: states, index: 0);
  }
}

final _index = IndexResult(
    cards: [_card('L1'), _card('R1')], idless: 0, malformed: 0, skipped: 0);

// Two typed factories with inline override lists — riverpod's bare `Override`
// supertype isn't in the public export, so it can't be named in a signature.
ProviderContainer _makeLearn(AppDatabase db, LearnItem item) =>
    ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWith((ref) async => Clock.real),
      vaultIndexProvider.overrideWith((ref) async => _index),
      decksProvider.overrideWith(_FixedDecks.new),
      learnSessionProvider.overrideWith(() => _OneLearn(item)),
    ]);

ProviderContainer _makeReview(AppDatabase db, ReviewItem item) =>
    ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWith((ref) async => Clock.real),
      vaultIndexProvider.overrideWith((ref) async => _index),
      decksProvider.overrideWith(_FixedDecks.new),
      studySessionProvider.overrideWith(() => _OneReview(item)),
    ]);

void main() {
  group('Learn grade path (seedState — no review-log row)', () {
    test('Good seeds FSRS state + a learn event, and writes NO review row',
        () async {
      if (!_sqliteAvailable) return;
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final c = _makeLearn(db, LearnItem(card: _card('L1'), section: _section));
      addTearDown(c.dispose);

      await c.read(learnSessionProvider.future);
      await c.read(learnSessionProvider.notifier).grade(3); // Good

      final repo = SrsRepository(db);
      expect((await repo.loadStates()).containsKey('L1::def'), isTrue,
          reason: 'Good seeds the section into the review schedule');
      expect((await repo.recentReviewStats(_past)).total, 0,
          reason: 'seedState must NOT write a review-log row');
      expect(await repo.sectionsStartedSince(_past), 1,
          reason: "first study logs a 'learn' activity event");
    });

    test('Again re-queues the section and seeds nothing', () async {
      if (!_sqliteAvailable) return;
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final c = _makeLearn(db, LearnItem(card: _card('L1'), section: _section));
      addTearDown(c.dispose);

      await c.read(learnSessionProvider.future);
      await c.read(learnSessionProvider.notifier).grade(1); // Again

      final repo = SrsRepository(db);
      expect(await repo.loadStates(), isEmpty,
          reason: 'a failed first attempt is not graduated into review');
      expect((await repo.recentReviewStats(_past)).total, 0);
      final s = c.read(learnSessionProvider).asData!.value;
      expect(s.graduated, 0);
      expect(s.queue.length, 1,
          reason: 'the section is re-queued this session');
    });
  });

  group('Review grade path (recordReview — a review-log row, prior threaded)',
      () {
    test('Good records a review row + increments reviewCount over the prior',
        () async {
      if (!_sqliteAvailable) return;
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      // A prior state (reviewCount 2) so the increment proves threading.
      await SrsRepository(db).seedStudied(
        [(cardId: 'R1', sectionSlug: 'def', stability: 10)],
        at: _past,
      );
      final c =
          _makeReview(db, ReviewItem(card: _card('R1'), section: _section));
      addTearDown(c.dispose);

      await c.read(studySessionProvider.future);
      await c.read(studySessionProvider.notifier).grade(3); // Good

      final repo = SrsRepository(db);
      expect((await repo.recentReviewStats(_past)).total, 1,
          reason: 'recordReview appends a review-log row');
      final grades = await repo.reviewGradesSince(_past);
      expect(grades.single.grade, 3);
      expect((await repo.loadStates())['R1::def']!.reviewCount, 3,
          reason: 'upsert increments the prior reviewCount (2 → 3)');
    });
  });
}
