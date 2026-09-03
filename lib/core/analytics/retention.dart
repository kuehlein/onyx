/// Retention analytics (task #27): how well memory is holding, per domain.
///
/// Pure aggregation over the review log + current FSRS state, grouped by the
/// card's domain (tag). Two honest signals per domain:
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

  /// Domain key (the card's first tag), e.g. "system-design".
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

/// Aggregate [reviews] and [stabilities] into per-domain retention, joining each
/// card to its domain via [domainByCard]. Records — not drift rows — keep this
/// pure and trivially testable.
List<DomainRetention> computeRetention({
  required List<({String cardId, int grade})> reviews,
  required List<({String cardId, double stability})> stabilities,
  required Map<String, String> domainByCard,
  int minSample = 5,
}) {
  final total = <String, int>{};
  final retained = <String, int>{};
  for (final r in reviews) {
    final d = domainByCard[r.cardId];
    if (d == null) continue;
    total[d] = (total[d] ?? 0) + 1;
    if (r.grade >= 2) retained[d] = (retained[d] ?? 0) + 1;
  }

  final stabSum = <String, double>{};
  final stabN = <String, int>{};
  for (final s in stabilities) {
    final d = domainByCard[s.cardId];
    if (d == null) continue;
    stabSum[d] = (stabSum[d] ?? 0) + s.stability;
    stabN[d] = (stabN[d] ?? 0) + 1;
  }

  final domains = {...total.keys, ...stabN.keys};
  final out = [
    for (final d in domains)
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

  // Trustworthy domains first, weakest recall at the top (where attention is
  // needed); low-sample domains sink to the bottom, most-studied first.
  out.sort((a, b) {
    if (a.lowSample != b.lowSample) return a.lowSample ? 1 : -1;
    if (!a.lowSample) return a.recall!.compareTo(b.recall!);
    return b.studiedSections.compareTo(a.studiedSections);
  });
  return out;
}
