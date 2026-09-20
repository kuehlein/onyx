/// Retention analytics (task #27): how well memory is holding, per domain and
/// per tag.
///
/// Pure aggregation over the review log + current FSRS state, grouped by the
/// card's domain (its first tag) or — in the by-tag view — by EVERY tag a card
/// carries, so a cross-cutting tag (e.g. `caching`, `sharding`) gets its own
/// recall across domains. Two honest signals per group:
/// - **recall** — the fraction of reviews that were NOT a lapse (grade ≥ 2, i.e.
///   not "Again"). This is the FSRS sense of retention: did you still remember?
/// - **avgStabilityDays** — the mean current FSRS stability of the domain's
///   studied sections: roughly how long the memory lasts before it needs a
///   refresh. This is the thing FSRS actually optimizes.
///
/// Recall is withheld (null) below [minSample] reviews, because a rate over a
/// handful of reviews is noise, not signal.
library;

class DomainRetention {
  const DomainRetention({
    required this.domain,
    required this.reviews,
    required this.recall,
    required this.avgStabilityDays,
    required this.studiedSections,
  });

  /// The grouping key — a domain (the card's first tag, e.g. "system-design")
  /// in the by-domain view, or a tag in the by-tag view.
  final String domain;

  /// Reviews logged for this domain in the window.
  final int reviews;

  /// Fraction not lapsed (grade ≥ 2), or null when the sample is too small.
  final double? recall;

  /// Mean current FSRS stability (days) of studied sections, or null if none.
  final double? avgStabilityDays;

  /// How many sections in this domain have been studied (have FSRS state).
  final int studiedSections;

  /// True when there aren't enough reviews to show a trustworthy recall rate.
  bool get lowSample => recall == null;
}

/// By-DOMAIN retention: each card joins its single domain via [domainByCard].
/// Records — not drift rows — keep this pure and trivially testable.
List<DomainRetention> computeRetention({
  required List<({String cardId, int grade})> reviews,
  required List<({String cardId, double stability})> stabilities,
  required Map<String, String> domainByCard,
  int minSample = 5,
}) =>
    _computeGrouped(
      reviews: reviews,
      stabilities: stabilities,
      groupsByCard: {
        for (final e in domainByCard.entries) e.key: [e.value],
      },
      minSample: minSample,
    );

/// By-TAG retention: each card contributes to EVERY tag in [tagsByCard], so a
/// card tagged `[databases, query-optimization]` counts toward both — a
/// cross-cutting tag (which can span domains) gets its own recall. Otherwise
/// identical to [computeRetention].
List<DomainRetention> computeRetentionByTag({
  required List<({String cardId, int grade})> reviews,
  required List<({String cardId, double stability})> stabilities,
  required Map<String, List<String>> tagsByCard,
  int minSample = 5,
}) =>
    _computeGrouped(
      reviews: reviews,
      stabilities: stabilities,
      groupsByCard: tagsByCard,
      minSample: minSample,
    );

/// Shared aggregation for both views. Each card maps to one-or-more group keys
/// (a single domain, or all its tags); every review/stability counts toward each
/// of the card's groups.
List<DomainRetention> _computeGrouped({
  required List<({String cardId, int grade})> reviews,
  required List<({String cardId, double stability})> stabilities,
  required Map<String, List<String>> groupsByCard,
  required int minSample,
}) {
  final total = <String, int>{};
  final retained = <String, int>{};
  for (final r in reviews) {
    for (final d in groupsByCard[r.cardId] ?? const <String>[]) {
      total[d] = (total[d] ?? 0) + 1;
      if (r.grade >= 2) retained[d] = (retained[d] ?? 0) + 1;
    }
  }

  final stabSum = <String, double>{};
  final stabN = <String, int>{};
  for (final s in stabilities) {
    for (final d in groupsByCard[s.cardId] ?? const <String>[]) {
      stabSum[d] = (stabSum[d] ?? 0) + s.stability;
      stabN[d] = (stabN[d] ?? 0) + 1;
    }
  }

  final groups = {...total.keys, ...stabN.keys};
  final out = [
    for (final d in groups)
      DomainRetention(
        domain: d,
        reviews: total[d] ?? 0,
        recall: (total[d] ?? 0) >= minSample
            ? (retained[d] ?? 0) / total[d]!
            : null,
        avgStabilityDays: (stabN[d] ?? 0) > 0 ? stabSum[d]! / stabN[d]! : null,
        studiedSections: stabN[d] ?? 0,
      ),
  ];

  // Trustworthy groups first, weakest recall at the top (where attention is
  // needed); low-sample groups sink to the bottom, most-studied first.
  out.sort((a, b) {
    if (a.lowSample != b.lowSample) return a.lowSample ? 1 : -1;
    if (!a.lowSample) return a.recall!.compareTo(b.recall!);
    return b.studiedSections.compareTo(a.studiedSections);
  });
  return out;
}
