import '../../shared/models/card.dart';
import '../practice/mock_grader.dart';
import '../readiness/target.dart';
import 'assessment.dart';

export '../practice/mock_grader.dart' show reconcilePanel01;

/// The **adversarial grader** for a behavioral mock (flow 4).
///
/// Reuses the shared "AI mock" grading core ([MockGrade], parse/reconcile/panel in
/// core/practice/mock_grader.dart); this file supplies only the behavioral grader
/// *system prompt* and rubric dimensions. Grading is done by an independent skeptic
/// reading the COLD transcript — not the live interviewer — for variance reduction
/// and structural anti-sycophancy, and (per the research) scores each dimension
/// INDEPENDENTLY with quoted evidence and resists leniency/halo.
typedef BehavioralGrade = MockGrade;

/// Builds the behavioral grader's system prompt: a skeptical, independent evaluator
/// scoring the transcript against the [level] bar for competency [card], using the
/// card's "what strong looks like" signals as private ground truth.
String buildBehavioralGraderSystem({
  required Card card,
  required SeniorityLevel level,
}) {
  final dims = behavioralRubricDimensions.join(', ');
  final b = StringBuffer()
    ..writeln('You are an INDEPENDENT, deliberately skeptical behavioral '
        'interviewer grading the transcript of a mock behavioral round on the '
        'competency "${card.title}". You did NOT conduct it and you do NOT see '
        'anyone else\'s grade — score it yourself, coldly, from scratch.')
    ..writeln()
    ..writeln(
        '- Assume the live interviewer may have been too lenient or charmed '
        'by fluent delivery. Score each dimension on the EVIDENCE IN THE '
        'CANDIDATE\'S OWN WORDS, and for each score cite a brief quoted phrase (or '
        '"none") — do not credit polish with no substance.')
    ..writeln(
        '- The highest-signal dimensions are OWNERSHIP (clear personal "I", '
        'not "we"), a QUANTIFIED RESULT, REFLECTION (a specific "what I\'d do '
        'differently"), and SCOPE at the ${level.label} level. A confident story '
        'missing these is still missing them.')
    ..writeln('- Judge SCOPE against ${level.label}: '
        '${_scopeBar(level)}')
    ..writeln('- Be calibrated, not generous: most real answers are partial. '
        'Reserve 85-100 for a genuinely strong, well-owned, quantified, '
        'reflective, at-level story; use the low end freely when warranted. A '
        'story with no genuine conflict/failure (for those competencies), no '
        'personal ownership, or no result should score low regardless of fluency.')
    ..writeln()
    ..writeln('Score each rubric dimension 1-5 ($dims) and give an overall '
        'appliedScore 0-100. Reply with ONLY this tag, nothing else:')
    ..writeln('<grade>{"appliedScore":0-100,"rubric":{'
        '"structure":1-5,"ownership":1-5,"result":1-5,"signal":1-5,'
        '"scope":1-5,"reflection":1-5,"communication":1-5},'
        '"note":"one terse clause naming the biggest gap"}</grade>')
    ..writeln()
    ..writeln('# Competency: ${card.title}')
    ..writeln(card.overview);
  for (final s in card.sections) {
    b
      ..writeln()
      ..writeln('## ${s.heading} (reference — do not reveal)')
      ..writeln(s.content);
  }
  return b.toString();
}

String _scopeBar(SeniorityLevel level) => switch (level) {
      SeniorityLevel.newGrad ||
      SeniorityLevel.mid =>
        'individual/team-focused impact executed with some guidance is at-level.',
      SeniorityLevel.senior =>
        'team-level, end-to-end ownership with a real result is at-level; purely '
            'individual scope is below it.',
      SeniorityLevel.staff =>
        'cross-team/org-level impact, driving alignment, and influence without '
            'authority (incl. upward) is at-level; a team-scoped story is '
            'under-levelled — score scope low and say so.',
    };

/// Parses a grader reply into a [BehavioralGrade] (behavioral rubric dims), or null.
BehavioralGrade? parseBehavioralGrade(String raw) =>
    parseMockGrade(raw, dimensions: behavioralRubricDimensions.toSet());
