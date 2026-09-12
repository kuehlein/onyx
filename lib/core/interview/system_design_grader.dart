import '../../shared/models/card.dart';
import '../ai/system_design_interviewer.dart';
import '../practice/mock_grader.dart';
import '../readiness/target.dart';
import 'assessment.dart';

export '../practice/mock_grader.dart' show reconcilePanel01;

/// The **adversarial grader** for a system-design mock (flow 3).
///
/// The grade shape, parsing, panel run and reconciliation are the shared "AI mock"
/// core ([MockGrade] in core/practice/mock_grader.dart); this file supplies only
/// the SD-specific grader *system prompt* and rubric dimensions. Grading is done by
/// an independent skeptic reading the COLD transcript — not the live interviewer —
/// for variance reduction and structural anti-sycophancy (see mock_grader.dart).
typedef SdGrade = MockGrade;

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

/// Parses a grader reply into an [SdGrade] (SD rubric dimensions), or null.
SdGrade? parseSdGrade(String raw) =>
    parseMockGrade(raw, dimensions: systemDesignRubricDimensions.toSet());
