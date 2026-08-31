import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock.dart';
import '../../core/srs/learn_queue.dart';
import '../models/card.dart';
import 'clock.dart';
import 'coach.dart';
import 'database.dart';
import 'settings.dart';
import 'srs.dart';
import 'vault.dart';

part 'learn.g.dart';

/// How many brand-new sections may still be started today. The new-card limit is
/// a DAILY allowance (not per-session): once you've learned that many today,
/// there's nothing new until tomorrow — mirroring how reviews are time-gated, so
/// new material doesn't pile up unbounded. Learned-today is counted from the
/// activity log against the (dev-adjustable) clock's day.
@riverpod
Future<int> dailyNewRemaining(Ref ref) async {
  final limit = await ref.watch(newCardLimitProvider.future);
  final clock = await ref.watch(clockProvider.future);
  final learnedToday = await ref
      .watch(srsRepositoryProvider)
      .sectionsStartedSince(clock.today());
  return (limit - learnedToday).clamp(0, limit);
}

/// The "learn new material" queue: un-seeded quizzable sections grouped by
/// wikilink family, foundational-first, capped by the remaining daily allowance.
@riverpod
Future<List<LearnItem>> learnQueue(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final repo = ref.watch(srsRepositoryProvider);
  final states = await repo.loadStates();
  final remaining = await ref.watch(dailyNewRemainingProvider.future);
  if (remaining <= 0) return const [];
  return buildLearnQueue(
    cards: index.cards,
    seededKeys: states.keys.toSet(),
    adjacency: _buildAdjacency(index.cards),
    newSectionLimit: remaining,
  );
}

/// Symmetric card→card adjacency from resolved wikilinks (by filename).
Map<String, Set<String>> _buildAdjacency(List<Card> cards) {
  final idByFilename = {
    for (final c in cards) _filenameKey(c.filePath): c.id,
  };
  final adjacency = <String, Set<String>>{};
  void link(String a, String b) {
    adjacency.putIfAbsent(a, () => {}).add(b);
    adjacency.putIfAbsent(b, () => {}).add(a);
  }

  for (final card in cards) {
    for (final target in card.wikilinks) {
      final toId = idByFilename[target];
      if (toId != null && toId != card.id) link(card.id, toId);
    }
  }
  return adjacency;
}

String _filenameKey(String path) {
  final base = path.split('/').last;
  return base.endsWith('.md') ? base.substring(0, base.length - 3) : base;
}

/// A Learn session: the remaining items to study (head is current) and a count
/// of how many have graduated. Graduating removes the head; a re-study moves the
/// head to the tail — so `graduated + queue.length` stays constant (a stable
/// progress denominator).
class LearnSessionState {
  const LearnSessionState({required this.queue, required this.graduated});

  final List<LearnItem> queue;
  final int graduated;

  LearnItem? get current => queue.isEmpty ? null : queue.first;
  bool get isDone => queue.isEmpty;
  int get total => graduated + queue.length;
}

/// Drives Learn mode: present un-seeded sections one at a time; a self-rating of
/// Good/Easy graduates the section (seeds FSRS state, enters the review queue),
/// while Again/Hard re-queues it for another pass this session. Learn never
/// writes a review-log row.
@riverpod
class LearnSession extends _$LearnSession {
  @override
  Future<LearnSessionState> build() async {
    final queue = await ref.watch(learnQueueProvider.future);
    // Fresh session: clear stale per-section coach chats (symmetric with the
    // review session). Browse chats are untouched; within a session, chats
    // persist to the DB so they survive closing/reopening the coach.
    await clearTestCoachConversations(ref.read(appDatabaseProvider));
    return LearnSessionState(queue: queue, graduated: 0);
  }

  /// Grade the current section (1=Again … 4=Easy). Good/Easy graduate it; lower
  /// grades send it back for another pass.
  Future<void> grade(int grade) async {
    final s = state.asData?.value;
    if (s == null || s.isDone) return;
    final item = s.queue.first;

    if (grade >= 3) {
      final scheduler = ref.read(srsSchedulerProvider);
      final repo = ref.read(srsRepositoryProvider);
      final clock = ref.read(clockProvider).asData?.value ?? Clock.real;
      // A fresh section: no prior state, so this seeds the initial FSRS values.
      final outcome = scheduler.review(
        grade: grade,
        reviewedAt: clock.now(),
        desiredRetention: item.card.priority.desiredRetention,
      );
      await repo.seedState(
        cardId: item.card.id,
        sectionSlug: item.section.slug,
        outcome: outcome,
      );
      ref.invalidate(srsStatesProvider);
      ref.invalidate(reviewQueueProvider);
      state = AsyncData(LearnSessionState(
        queue: s.queue.sublist(1),
        graduated: s.graduated + 1,
      ));
    } else {
      state = AsyncData(LearnSessionState(
        queue: [...s.queue.sublist(1), item],
        graduated: s.graduated,
      ));
    }
  }
}
