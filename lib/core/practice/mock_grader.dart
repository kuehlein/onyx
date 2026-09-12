import 'dart:convert';

import '../ai/claude_service.dart';

/// Shared "AI mock" grading core, reused by every mock-style practice track
/// (system design, behavioral, …). A mock is graded by an independent, skeptical
/// panel reading the COLD transcript — not the live interviewer — for two reasons:
///
///  * **Variance reduction.** A single LLM grade is noisy and skews lenient, so
///    the readiness signal takes the median of independent grades.
///  * **Anti-sycophancy (structural).** LLM interviewers cave under confident /
///    detailed / casual pushback, inflating an in-conversation grade. A fresh
///    grader reading the raw transcript never "caved" in the moment.
///
/// Only the grader's *system prompt* and its *rubric dimension names* are
/// track-specific; the grade shape, parsing, panel run, and reconciliation are
/// shared here. This feeds the readiness applied signal — never the human's own
/// reflection.
class MockGrade {
  const MockGrade(
      {required this.appliedScore, this.rubric = const {}, this.note});

  /// Overall applied performance, 0–100.
  final int appliedScore;

  /// Per-dimension scores (1–5), keyed by the track's rubric dimensions.
  final Map<String, int> rubric;

  final String? note;
}

final _gradeTag =
    RegExp(r'<grade>\s*(.*?)\s*</grade>', dotAll: true, caseSensitive: false);

/// Parses a grader reply into a [MockGrade], or null if unparseable. Accepts the
/// `<grade>{…}</grade>` tag or a bare JSON object as a fallback. Rubric keys are
/// filtered to [dimensions] (the track's rubric) and clamped to 1–5.
MockGrade? parseMockGrade(String raw, {required Set<String> dimensions}) {
  final tagged = _gradeTag.firstMatch(raw);
  final json = tagged != null
      ? tagged.group(1)
      : RegExp(r'\{.*\}', dotAll: true).firstMatch(raw)?.group(0);
  if (json == null) return null;
  try {
    final j = jsonDecode(json) as Map<String, dynamic>;
    final score = (j['appliedScore'] as num?)?.round();
    if (score == null) return null;
    final rubric = <String, int>{};
    if (j['rubric'] is Map) {
      (j['rubric'] as Map).forEach((k, v) {
        if (v is num && dimensions.contains(k)) {
          rubric[k as String] = v.round().clamp(1, 5).toInt();
        }
      });
    }
    return MockGrade(
      appliedScore: score.clamp(0, 100).toInt(),
      rubric: rubric,
      note: j['note'] is String ? j['note'] as String : null,
    );
  } catch (_) {
    return null;
  }
}

/// Reconcile a panel of independent grades into one applied score (0..1) — the
/// **median** (robust to a single outlier grader), or the lone grade when only
/// one succeeded. Returns null for an empty panel.
double? reconcilePanel01(List<MockGrade> panel) {
  final scores = panel.map((g) => g.appliedScore).toList()..sort();
  if (scores.isEmpty) return null;
  final mid = scores.length ~/ 2;
  final median = scores.length.isOdd
      ? scores[mid].toDouble()
      : (scores[mid - 1] + scores[mid]) / 2.0;
  return (median / 100.0).clamp(0.0, 1.0);
}

/// The median grade of a panel (for its rubric + note), paired with the
/// reconciled 0..1 score. Null when the panel is empty. The returned grade's
/// [MockGrade.appliedScore] is the reconciled median score (0–100).
({MockGrade grade, double score01})? reconcilePanel(List<MockGrade> panel) {
  final score01 = reconcilePanel01(panel);
  if (score01 == null) return null;
  final sorted = [...panel]
    ..sort((a, b) => a.appliedScore.compareTo(b.appliedScore));
  final median = sorted[sorted.length ~/ 2];
  return (
    grade: MockGrade(
      appliedScore: (score01 * 100).round(),
      rubric: median.rubric,
      note: median.note,
    ),
    score01: score01,
  );
}

/// Run [panelSize] independent graders over the cold [transcript] with the
/// track's [graderSystem] prompt, parse each against [dimensions], and reconcile
/// to a single median grade. Returns null if no grader produced a usable grade.
/// Individual grader failures are swallowed (they just don't vote).
Future<({MockGrade grade, double score01})?> runAdversarialPanel({
  required ClaudeService claude,
  required String model,
  required int panelSize,
  required String graderSystem,
  required String transcript,
  required Set<String> dimensions,
  int maxTokens = 400,
}) async {
  final results = await Future.wait([
    for (var i = 0; i < panelSize; i++)
      claude
          .chat(
            system: graderSystem,
            model: model,
            maxTokens: maxTokens,
            messages: [(role: 'user', content: transcript)],
          )
          .then<MockGrade?>((r) => parseMockGrade(r, dimensions: dimensions))
          .catchError((_) => null),
  ]);
  final panel = [
    for (final g in results)
      if (g != null) g,
  ];
  return reconcilePanel(panel);
}
