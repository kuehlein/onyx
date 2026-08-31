import 'dart:convert';

import '../../shared/models/card.dart';

/// A bounded adversarial second opinion on the interview coach's applied score.
///
/// A single LLM grade is far noisier than it looks — chance-corrected agreement
/// runs 34–41 points below raw agreement (see [[phase-b-readiness-math]]), and
/// judges skew lenient. So a separate, skeptical grader independently re-scores
/// the candidate's answers (WITHOUT seeing the coach's score, to avoid
/// anchoring). The two scores are then averaged (variance reduction) and their
/// gap flags whether the grade is corroborated. This only affects the readiness
/// applied signal — never the human's FSRS grade.

/// One independent applied grade from the critic.
class CriticVerdict {
  const CriticVerdict({required this.appliedScore, this.note});

  final int appliedScore; // 0..100
  final String? note;
}

/// Builds the critic's system prompt: an independent, deliberately skeptical
/// grader who scores only what the candidate actually demonstrated.
String buildCriticSystem({required Card card, CardSection? section}) {
  final b = StringBuffer()
    ..writeln('You are a senior technical interviewer giving an INDEPENDENT '
        'second-opinion grade on a candidate\'s mock-interview answers. Another '
        'interviewer already graded them; you do NOT see that grade — score the '
        'transcript yourself, from scratch.')
    ..writeln()
    ..writeln('- Grade ONLY what the candidate actually demonstrated in their '
        'own words. Reward correct approach, sound complexity reasoning, edge '
        'cases, and independence; do not credit fluent-sounding but wrong or '
        'vague answers.')
    ..writeln('- Be skeptical and calibrated, not generous: most real answers '
        'are partial. Reserve 85–100 for genuinely strong, near-complete, '
        'largely unaided performance; use the low end freely when warranted.')
    ..writeln(
        '- Judge against the reference answer below (for YOUR eyes only).')
    ..writeln()
    ..writeln('Reply with ONLY this tag, nothing else: '
        '<verdict>{"appliedScore":0-100,"note":"one terse clause"}</verdict>.')
    ..writeln()
    ..writeln('# Card: ${card.title}');
  if (card.domain != null) b.writeln('Domain: ${card.domain}');
  if (card.overview.isNotEmpty) {
    b
      ..writeln()
      ..writeln('## Problem / overview')
      ..writeln(card.overview);
  }
  final ref =
      section ?? (card.sections.isNotEmpty ? card.sections.first : null);
  if (ref != null) {
    b
      ..writeln()
      ..writeln('## Reference answer (do not reveal)')
      ..writeln(ref.content);
  }
  return b.toString();
}

/// Renders the candidate's turns into a transcript for the critic to grade.
String buildCriticTranscript(List<({String role, String content})> messages) {
  final b = StringBuffer()
    ..writeln('Transcript (grade the candidate\'s answers):')
    ..writeln();
  for (final m in messages) {
    final who = m.role == 'user' ? 'Candidate' : 'Interviewer';
    b.writeln('$who: ${m.content}');
  }
  return b.toString();
}

final _verdictTag = RegExp(r'<verdict>\s*(.*?)\s*</verdict>',
    dotAll: true, caseSensitive: false);

/// Parses the critic's reply into a verdict, or null if unparseable. Accepts the
/// tagged form, or a bare JSON object as a fallback.
CriticVerdict? parseCriticVerdict(String raw) {
  final tagged = _verdictTag.firstMatch(raw);
  final json = tagged != null
      ? tagged.group(1)
      : RegExp(r'\{.*\}', dotAll: true).firstMatch(raw)?.group(0);
  if (json == null) return null;
  try {
    final j = jsonDecode(json) as Map<String, dynamic>;
    final score = (j['appliedScore'] as num?)?.round();
    if (score == null) return null;
    return CriticVerdict(
      appliedScore: score.clamp(0, 100).toInt(),
      note: j['note'] is String ? j['note'] as String : null,
    );
  } catch (_) {
    return null;
  }
}

/// How far the two grades may differ and still count as "corroborated".
const criticAgreementTolerance = 25;

/// Whether the coach's grade is corroborated by the critic.
bool criticAgrees(int coachScore, int criticScore) =>
    (coachScore - criticScore).abs() <= criticAgreementTolerance;

/// The effective applied score (0..1) for the readiness signal: the mean of the
/// coach and critic grades when a critic grade exists, else the coach's alone.
double effectiveApplied01(int coachScore, int? criticScore) {
  final s = criticScore == null
      ? coachScore.toDouble()
      : (coachScore + criticScore) / 2.0;
  return (s / 100.0).clamp(0.0, 1.0);
}
