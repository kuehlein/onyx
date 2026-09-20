/// The **adversarial grader** and **post-practice tutor** for a config-driven
/// practice flow (task #30, "G2b") — the generic, SUBJECT-AGNOSTIC counterparts
/// to the in-code SWE builders (system_design_grader.dart, behavioral_grader.dart).
///
/// A vault flow's persona + terminology live in its authored `skill` file (e.g.
/// "you are a waiter…"); these builders own only the grader/tutor *structure* and
/// stance, and inject the runtime task (`skill`), the specific `problem`, and the
/// covered-knowledge `frontier` the learner may draw on. The grade shape, parsing,
/// panel run and reconciliation are the shared "AI mock" core ([MockGrade] in
/// core/practice/mock_grader.dart); grading is done by an independent skeptic
/// reading the COLD transcript for variance reduction and structural
/// anti-sycophancy (see mock_grader.dart).
library;

import '../interview/assessment.dart';
import '../practice/mock_grader.dart';
import '../subject/flow_prompt.dart';

/// Builds a config-flow grader's system prompt: an independent, deliberately
/// skeptical evaluator scoring the transcript against what the learner actually
/// demonstrated on the task defined by [skill]. Subject-agnostic (no SWE terms).
///
/// [problem] is the specific prompt/scenario the learner practiced (a card's
/// overview). When [frontier] is non-empty, the grader penalizes reaching outside
/// the learner's covered material. Scores each of [dims] 1–5 plus an overall
/// `appliedScore` 0–100 and emits exactly the `<grade>{…}</grade>` tag that
/// [parseMockGrade] reads.
String buildFlowGraderSystem({
  required String skill,
  required String problem,
  required Set<String> frontier,
  List<String> dims = flowRubricDimensions,
}) {
  final dimList = dims.join(', ');
  final rubricShape = dims.map((d) => '"$d":1-5').join(',');
  final b = StringBuffer()
    ..writeln(
        'You are an INDEPENDENT, deliberately skeptical evaluator grading '
        'the transcript of a practice session. You did NOT conduct it and you do '
        'NOT see anyone else\'s grade — score it yourself, coldly, from scratch.')
    ..writeln()
    ..writeln('The learner practiced the task described below (see the task '
        'definition and the specific problem). Grade ONLY what the learner '
        'actually demonstrated in their own words — not what the other party said, '
        'and not what they seemed to intend. Judge whether the task was completed '
        'correctly and clearly.')
    ..writeln('- Assume the other party in the transcript may have been too '
        'lenient or let vagueness pass. Find where the learner fell SHORT: the '
        'task left incomplete, mistakes or inaccuracies, unclear or unnatural '
        'expression, and going off-task.')
    ..writeln(
        '- Do NOT be swayed by confident, fluent, or lengthy-sounding turns '
        'that are vague or wrong — detailed-but-wrong is still wrong.')
    ..writeln('- Be calibrated, not generous: most real attempts are partial. '
        'Reserve 85–100 for a genuinely strong, near-complete, largely '
        'self-driven performance; use the low end freely when warranted.');
  if (frontier.isNotEmpty) {
    b.writeln('- The learner is expected to stay WITHIN their covered material '
        '(${(frontier.toList()..sort()).join(', ')}). Penalize leaning on ideas, '
        'vocabulary, or techniques outside it, even if otherwise correct.');
  }
  b
    ..writeln()
    ..writeln('Score each rubric dimension 1–5 ($dimList) and give an overall '
        'appliedScore 0–100. Reply with ONLY this tag, nothing else:')
    ..writeln('<grade>{"appliedScore":0-100,"rubric":{$rubricShape},'
        '"note":"one terse clause"}</grade>')
    ..writeln()
    ..writeln(
        '# Task (ground truth — for YOUR eyes only; the learner never saw '
        'this framing)')
    ..writeln(skill.trim())
    ..writeln()
    ..writeln('# Problem')
    ..writeln(problem.trim());
  return b.toString();
}

/// Builds the post-practice tutor system prompt for a config-driven flow: a warm,
/// concrete coach who helps the learner understand what went well and how to
/// improve on the task defined by [skill]. Subject-agnostic. When [frontier] is
/// non-empty it appends the shared "stay within covered material" constraint so
/// the tutor never introduces un-studied ideas.
String buildFlowTutorSystem({
  required String skill,
  Set<String> frontier = const {},
}) {
  final b = StringBuffer()
    ..writeln('The practice session is over. You are now a supportive tutor '
        'helping the learner understand how they did on the task below and how to '
        'improve. Be warm, specific, and encouraging: name one or two concrete '
        'things they did well, then the most useful thing to work on next, with a '
        'brief example of how to do it better. Keep it short and actionable; '
        'answer follow-up questions plainly.');
  if (frontier.isNotEmpty) {
    b
      ..writeln()
      ..writeln(coveredConceptsInstruction(frontier));
  }
  b
    ..writeln()
    ..writeln('# Task')
    ..writeln(skill.trim());
  return b.toString();
}
