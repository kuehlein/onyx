import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/analytics/retention.dart';
import 'clock.dart';
import 'srs.dart';
import 'vault.dart';

part 'analytics.g.dart';

/// The lookback window for retention analytics. Recall reflects recent
/// performance; stability is read from current FSRS state (not windowed).
const retentionWindow = Duration(days: 90);

/// Per-domain retention (task #27), computed from the review log + current FSRS
/// state, grouped by each card's domain via the vault index.
@riverpod
Future<List<DomainRetention>> retentionByDomain(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  final clock = await ref.watch(clockProvider.future);
  final since = clock.now().subtract(retentionWindow);
  final grades =
      await ref.watch(srsRepositoryProvider).reviewGradesSince(since);

  final domainByCard = <String, String>{
    for (final c in index.cards)
      if (c.domain != null) c.id: c.domain!,
  };
  final stabilities = [
    for (final s in states.byKey.values)
      (cardId: s.cardId, stability: s.stability),
  ];

  return computeRetention(
    reviews: grades,
    stabilities: stabilities,
    domainByCard: domainByCard,
  );
}
