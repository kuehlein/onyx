/// Pure aggregations for the Insights screen beyond per-domain retention:
/// mock-interview skill breakdown, upcoming review load, struggling cards, and
/// study consistency. All dependency-free (records in, plain data out) so they
/// are trivial to unit-test.
library;

// ── Mock-interview skills ──────────────────────────────────────────────────

/// Averaged mock-interview performance: overall score, the per-dimension rubric
/// (which interview SKILL to work on), hint reliance, and how much was genuine
/// transfer (novel problems) — the "can you perform under pressure" signal that
/// recall alone can't show.
class MockSkills {
  const MockSkills({
    required this.count,
    required this.avgScore,
    required this.avgHintLevel,
    required this.novelFraction,
    required this.dims,
  });

  final int count;
  final double avgScore; // 0..100
  final double avgHintLevel; // 0..5
  final double novelFraction; // 0..1
  final Map<String, double> dims; // rubric dimension → mean (1..5)

  bool get isEmpty => count == 0;
}

MockSkills computeMockSkills(
  List<({int appliedScore, int hintLevel, bool novel, Map<String, int> rubric})>
      attempts,
) {
  if (attempts.isEmpty) {
    return const MockSkills(
        count: 0, avgScore: 0, avgHintLevel: 0, novelFraction: 0, dims: {});
  }
  var score = 0, hint = 0, novel = 0;
  final dimSum = <String, int>{};
  final dimN = <String, int>{};
  for (final a in attempts) {
    score += a.appliedScore;
    hint += a.hintLevel;
    if (a.novel) novel++;
    for (final e in a.rubric.entries) {
      dimSum[e.key] = (dimSum[e.key] ?? 0) + e.value;
      dimN[e.key] = (dimN[e.key] ?? 0) + 1;
    }
  }
  final n = attempts.length;
  return MockSkills(
    count: n,
    avgScore: score / n,
    avgHintLevel: hint / n,
    novelFraction: novel / n,
    dims: {for (final k in dimSum.keys) k: dimSum[k]! / dimN[k]!},
  );
}

// ── Upcoming review load ───────────────────────────────────────────────────

// ── Algorithm practice ─────────────────────────────────────────────────────

/// Progress in the separate Algorithms track: how many problems you've picked
/// up, how reliably you're solving them cold, and recent momentum. Distinct from
/// [MockSkills] (that's the coach rubric); this is the execution-clock signal —
/// solving under your own power. All solves also count toward readiness via the
/// ds-a transfer factor.
class AlgoStats {
  const AlgoStats({
    required this.logged,
    required this.distinctProblems,
    required this.patterns,
    required this.cleanRate,
    required this.last7,
  });

  final int logged; // total re-solves logged
  final int distinctProblems; // unique problems touched
  final int patterns; // unique patterns touched
  final double cleanRate; // 0..1 — fraction solved cleanly (no hint)
  final int last7; // solves in the last 7 days

  bool get isEmpty => logged == 0;
}

/// Aggregates the `source: algo` applied attempts into [AlgoStats]. A solve is
/// "clean" when it was logged as "solved it cleanly" (appliedScore ≥ 80, i.e.
/// no hint and not a struggle/fail).
AlgoStats computeAlgoStats(
  List<
          ({
            int appliedScore,
            DateTime occurredAt,
            String problem,
            String pattern
          })>
      solves,
  DateTime now,
) {
  if (solves.isEmpty) {
    return const AlgoStats(
        logged: 0, distinctProblems: 0, patterns: 0, cleanRate: 0, last7: 0);
  }
  final problems = <String>{};
  final patterns = <String>{};
  var clean = 0, last7 = 0;
  final weekAgo = now.subtract(const Duration(days: 7));
  for (final s in solves) {
    problems.add(s.problem);
    patterns.add(s.pattern);
    if (s.appliedScore >= 80) clean++;
    if (s.occurredAt.isAfter(weekAgo)) last7++;
  }
  return AlgoStats(
    logged: solves.length,
    distinctProblems: problems.length,
    patterns: patterns.length,
    cleanRate: clean / solves.length,
    last7: last7,
  );
}

/// Count of cards falling due on each of the next [days] days. Anything overdue
/// folds into today (index 0), so the first bar is "due now or past".
List<int> computeDueForecast({
  required List<DateTime> dueDates,
  required DateTime today,
  int days = 14,
}) {
  final out = List<int>.filled(days, 0);
  final t = DateTime(today.year, today.month, today.day);
  for (final d in dueDates) {
    final off = DateTime(d.year, d.month, d.day).difference(t).inDays;
    final bucket = off < 0 ? 0 : off;
    if (bucket < days) out[bucket]++;
  }
  return out;
}

// ── Struggling cards (leeches) ─────────────────────────────────────────────

class StrugglingCard {
  const StrugglingCard({
    required this.cardId,
    required this.title,
    required this.lapses,
    required this.reviews,
  });

  final String cardId;
  final String title;
  final int lapses; // "Again" count
  final int reviews; // total reviews (context for the lapse count)
}

/// The most-lapsed cards worth reformulating, most-failed first. Only cards with
/// at least [minLapses] lapses qualify (a single miss isn't a leech).
List<StrugglingCard> topStruggling(
  List<({String cardId, int lapses, int total})> rows,
  Map<String, String> titleByCard, {
  int minLapses = 2,
  int limit = 8,
}) {
  final out = [
    for (final r in rows)
      if (r.lapses >= minLapses)
        StrugglingCard(
          cardId: r.cardId,
          title: titleByCard[r.cardId] ?? r.cardId,
          lapses: r.lapses,
          reviews: r.total,
        ),
  ]..sort((a, b) {
      final c = b.lapses.compareTo(a.lapses);
      return c != 0 ? c : b.reviews.compareTo(a.reviews);
    });
  return out.take(limit).toList();
}

// ── Study consistency ──────────────────────────────────────────────────────

/// Study actions per day over the last [days] days, oldest first (index 0) and
/// today last — a compact activity strip. Consistency is the top predictor of
/// spaced-repetition success.
List<int> computeConsistency({
  required List<DateTime> events,
  required DateTime today,
  int days = 28,
}) {
  final out = List<int>.filled(days, 0);
  final t = DateTime(today.year, today.month, today.day);
  for (final e in events) {
    final off = t.difference(DateTime(e.year, e.month, e.day)).inDays;
    if (off >= 0 && off < days) out[days - 1 - off]++;
  }
  return out;
}
