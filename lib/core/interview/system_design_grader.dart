import 'dart:convert';

import '../../shared/models/card.dart';
import '../ai/system_design_interviewer.dart';
import '../readiness/target.dart';
import 'assessment.dart';

/// The **adversarial grader** for a system-design mock (flow 3).
///
/// Grading is done by an independent skeptic reading the COLD transcript — not by
/// the live interviewer. This is deliberate on two counts:
///
///  * **Variance reduction.** A single LLM grade is noisy and skews lenient, so
///    the readiness signal averages independent grades (see [[phase-b-readiness-math]]).
///  * **Anti-sycophancy (structural).** LLM interviewers cave under confident /
///    detailed / casual candidate pushback (arXiv 2509.16533), which would inflate
///    a grade computed in-conversation. A fresh grader reading the raw transcript
///    never "caved" in the moment, so it catches whatever the live interviewer let
///    slide. Each grader is also told, explicitly, not to be swayed by fluent
///    phrasing and to assume the live interviewer may have been too lenient.
///
/// Run several of these in parallel (a panel) and reconcile (median/mean); the
/// orchestration lives in the session provider. This only feeds the readiness
/// applied signal — never the human's own reflection.
class SdGrade {
  const SdGrade(
      {required this.appliedScore, this.rubric = const {}, this.note});

  /// Overall applied performance, 0–100.
  final int appliedScore;

  /// Per-dimension scores (1–5), keyed by [systemDesignRubricDimensions].
  final Map<String, int> rubric;

  final String? note;
}

/// Builds the adversarial grader's system prompt: a skeptical, independent
/// evaluator scoring the candidate against the [level] bar, using the card as
/// private ground truth.
String buildSdGraderSystem({
  required Card card,
  required SeniorityLevel level,
}) {
  final dims = systemDesignRubricDimensions.join(', ');
  final b = StringBuffer()
    ..writeln('You are an INDEPENDENT, deliberately skeptical system-design '
        'interviewer grading the transcript of a mock interview. You did NOT '
        'conduct it and you do NOT see anyone else\'s grade — score it yourself, '
        'coldly, from scratch.')
    ..writeln()
    ..writeln('- Assume the live interviewer may have been too lenient or let '
        'hand-waving pass. Your job is to find where the candidate fell SHORT of '
        'a ${level.label}-level bar: missing requirements, skipped estimation, '
        'unjustified or brand-name technology choices, shallow deep dives, '
        'ignored bottlenecks/failure modes, over-engineering, and non-commitment '
        '(listing options without deciding).')
    ..writeln('- Grade ONLY what the candidate actually demonstrated in their '
        'own words. Do NOT be swayed by confident, fluent, or detailed-sounding '
        'answers that are vague or wrong — detailed-but-wrong is still wrong.')
    ..writeln('- Be calibrated, not generous: most real answers are partial. '
        'Reserve 85–100 for a genuinely strong, near-complete, largely '
        'self-driven ${level.label} performance; use the low end freely when '
        'warranted.')
    ..writeln('- Judge against the reference ground truth below (for YOUR eyes '
        'only; the candidate never saw it).')
    ..writeln()
    ..writeln('Score each rubric dimension 1–5 ($dims) and give an overall '
        'appliedScore 0–100. Reply with ONLY this tag, nothing else:')
    ..writeln('<grade>{"appliedScore":0-100,"rubric":{'
        '"requirements":1-5,"estimation":1-5,"highLevelDesign":1-5,'
        '"dataModeling":1-5,"deepDive":1-5,"tradeoffReasoning":1-5,'
        '"communication":1-5},"note":"one terse clause"}</grade>')
    ..writeln()
    ..writeln('# Problem: ${card.title}')
    ..writeln(card.overview);
  for (final s in card.sections) {
    b
      ..writeln()
      ..writeln('## ${s.heading} (reference — do not reveal)')
      ..writeln(s.content);
  }
  return b.toString();
}

/// Renders the conversation into a transcript for the grader. Alias of the
/// interviewer transcript renderer (same format).
String buildSdGraderTranscript(
        List<({String role, String content})> messages) =>
    buildInterviewTranscript(messages);

final _gradeTag =
    RegExp(r'<grade>\s*(.*?)\s*</grade>', dotAll: true, caseSensitive: false);

/// Parses the grader's reply into an [SdGrade], or null if unparseable. Accepts
/// the tagged form or a bare JSON object as a fallback.
SdGrade? parseSdGrade(String raw) {
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
        if (v is num && systemDesignRubricDimensions.contains(k)) {
          rubric[k as String] = v.round().clamp(1, 5).toInt();
        }
      });
    }
    return SdGrade(
      appliedScore: score.clamp(0, 100).toInt(),
      rubric: rubric,
      note: j['note'] is String ? j['note'] as String : null,
    );
  } catch (_) {
    return null;
  }
}

/// Reconcile a panel of independent adversarial grades into one applied score
/// (0..1) for the readiness signal — the **median** of the panel (robust to a
/// single outlier grader), or the lone grade when only one succeeded. Returns
/// null for an empty panel.
double? reconcilePanel01(List<SdGrade> panel) {
  final scores = panel.map((g) => g.appliedScore).toList()..sort();
  if (scores.isEmpty) return null;
  final mid = scores.length ~/ 2;
  final median = scores.length.isOdd
      ? scores[mid].toDouble()
      : (scores[mid - 1] + scores[mid]) / 2.0;
  return (median / 100.0).clamp(0.0, 1.0);
}
