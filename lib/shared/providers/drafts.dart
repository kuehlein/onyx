import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/vault/card_parser.dart';
import '../../core/vault/card_promotion.dart';
import '../../core/vault/vault_source.dart';
import '../models/card.dart';
import 'vault.dart';

part 'drafts.g.dart';

/// Every unpromoted [CardStatus.draft] card in the index — the pool the review
/// gate works over (from an import today; AI-generation later). Browse reads the
/// full index and marks these "not counted"; this is the promotion queue.
@riverpod
Future<List<Card>> draftCards(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  return index.cards.where((c) => c.isDraft).toList(growable: false);
}

/// A bounded draft-review session: self-test-then-promote over the drafts snapshot
/// (docs/content-creation.md §4). Each card is decided individually after a recall
/// attempt — no bulk accept.
///
/// The queue is SNAPSHOT once at [build] (via `read`, not `watch`) so a mid-session
/// `vaultIndexProvider` invalidation — which each keep/discard fires so Browse and
/// study reflect the change — can't reshuffle or truncate the queue underfoot.
class DraftReviewSession {
  const DraftReviewSession({
    required this.queue,
    required this.index,
    this.promoted = 0,
    this.discarded = 0,
    this.skipped = 0,
  });

  /// The drafts to review, snapshotted at session start.
  final List<Card> queue;

  /// Position in [queue]; equals `queue.length` once the session is done.
  final int index;

  final int promoted;
  final int discarded;
  final int skipped;

  int get total => queue.length;
  bool get isDone => index >= queue.length;
  Card? get current => isDone ? null : queue[index];

  DraftReviewSession copyWith({
    List<Card>? queue,
    int? index,
    int? promoted,
    int? discarded,
    int? skipped,
  }) =>
      DraftReviewSession(
        queue: queue ?? this.queue,
        index: index ?? this.index,
        promoted: promoted ?? this.promoted,
        discarded: discarded ?? this.discarded,
        skipped: skipped ?? this.skipped,
      );
}

@riverpod
class DraftReview extends _$DraftReview {
  @override
  Future<DraftReviewSession> build() async {
    // Register the sync dep BEFORE the async gap (disposed-element safety).
    final source = ref.watch(vaultSourceProvider);
    // Snapshot the queue once (read, not watch): keep/discard invalidate the
    // index, and a watch here would rebuild the session and lose our place.
    final drafts = await ref.read(draftCardsProvider.future);
    return DraftReviewSession(
      queue: source == null ? const [] : drafts,
      index: 0,
    );
  }

  VaultSource? get _source => ref.read(vaultSourceProvider);

  /// KEEP: promote the current draft to active (it now counts + enters FSRS),
  /// then advance and refresh the index so Browse/study reflect it.
  Future<void> keep() async {
    final s = state.asData?.value;
    final card = s?.current;
    final source = _source;
    if (s == null || card == null || source == null) return;
    await promoteCard(source, card.filePath);
    state = AsyncData(
      s.copyWith(index: s.index + 1, promoted: s.promoted + 1),
    );
    ref.invalidate(vaultIndexProvider);
  }

  /// DISCARD: delete the current draft's file (nothing enters FSRS), advance,
  /// and refresh the index.
  Future<void> discard() async {
    final s = state.asData?.value;
    final card = s?.current;
    final source = _source;
    if (s == null || card == null || source == null) return;
    await discardCard(source, card.filePath);
    state = AsyncData(
      s.copyWith(index: s.index + 1, discarded: s.discarded + 1),
    );
    ref.invalidate(vaultIndexProvider);
  }

  /// EDIT applied: the in-app editor rewrote the current draft's file, but the
  /// session snapshotted the queue at start (see [build]) so `current` is stale.
  /// Re-read + re-parse the file and swap the fresh [Card] into `queue[index]`
  /// so the displayed card reflects the edit — then invalidate the index so
  /// Browse/study see it too. The card stays a draft (frontmatter/status
  /// preserved on edit), so the user can then Keep it. Guards nulls +
  /// parse-failure (a bad edit just leaves the old card in place).
  Future<void> refreshCurrent() async {
    final s = state.asData?.value;
    final card = s?.current;
    final source = _source;
    if (s == null || card == null || source == null) return;
    final Card? fresh;
    try {
      final raw = await source.readCard(card.filePath);
      fresh = const CardParser()
          .parse(raw, filePath: card.filePath, subjectId: card.subjectId);
    } catch (_) {
      return; // read/parse failed — leave the stale card rather than crash
    }
    if (fresh == null) return; // no longer a card (shouldn't happen on edit)
    final queue = [...s.queue];
    queue[s.index] = fresh;
    state = AsyncData(s.copyWith(queue: queue));
    ref.invalidate(vaultIndexProvider);
  }

  /// SKIP: leave it a draft to decide later; just advance (no write, no
  /// invalidation).
  void skip() {
    final s = state.asData?.value;
    if (s == null || s.current == null) return;
    state = AsyncData(
      s.copyWith(index: s.index + 1, skipped: s.skipped + 1),
    );
  }
}
