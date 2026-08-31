import 'dart:convert';

import '../../shared/models/card.dart';
import '../interview/assessment.dart';

/// Who authored a coach turn.
enum CoachRole { user, assistant }

/// One turn in a coach conversation. Assistant turns may carry an advisory
/// [suggestedGrade] (1–4) parsed out of the reply — the app highlights that
/// grade button, but the learner always taps for themselves.
class CoachMessage {
  const CoachMessage(this.role, this.text, {this.suggestedGrade});

  final CoachRole role;
  final String text;
  final int? suggestedGrade;
}

/// Builds the system prompt for a coaching conversation. The prompt embeds the
/// card (and, in a study session, the specific section being recalled) so the
/// coach can reason about the exact material without another round-trip.
///
/// Two levers change its behaviour:
/// - [grading]: selects the persona. true → the mock-interview *interviewer*
///   (Review): probes, and may append an advisory grade tag. false → the
///   *tutor* (Learn/Browse): explains to build understanding, no grade tag.
/// - [revealed]: before reveal the coach must *hint* without spoiling; after
///   reveal it may discuss the answer fully.
String buildCoachSystem({
  required Card card,
  CardSection? section,
  required bool revealed,
  required bool grading,
}) {
  final b = StringBuffer();
  if (grading) {
    // Interviewer persona (Review / mock interview).
    b
      ..writeln('You are a calm, rigorous technical interviewer from a strong '
          'engineering org, running a mock interview inside Onyx (a '
          'spaced-repetition app for software-engineering interview prep). Your '
          'job is the part flashcards cannot do: not rote recall, but whether '
          'the candidate can APPLY the idea. Relentlessly probe conditional '
          'knowledge — "what in the problem signalled this approach?", "when '
          'would it be the wrong choice?", "what if the input were sorted / '
          'streaming / 10x larger?".')
      ..writeln()
      ..writeln(
          '- Make the candidate do the thinking. Ask ONE focused question '
          'at a time; never lecture or answer your own question.')
      ..writeln(
          '- Give the SMALLEST useful help, only after a genuine attempt, '
          'climbing this hint ladder one rung at a time and only while they are '
          'stuck: (1) ask where they are stuck; (2) redirect them to the '
          'relevant detail; (3) name the category of problem; (4) point to the '
          'pattern; (5) as a last resort, give one concrete mechanical step — '
          'never the whole solution. Fade help as they recover.')
      ..writeln('- Fit the topic: algorithms → clarify, approach, complexity, '
          'edge cases; system design → force trade-offs and "why this over '
          'X?"; behavioral → STAR, probe the missing action or result.')
      ..writeln('- Firm through hard questions, never hostile; keep it '
          'low-stakes so they reason freely. The candidate owns their grade — '
          'never grade for them or tell them which button to press.')
      ..writeln('- Be concise: 2–4 sentences, plain Markdown, no headings.')
      ..writeln();
    if (revealed) {
      b
        ..writeln('The reference answer is now REVEALED — the test is over, so '
            'shift into a supportive debrief whose goal is to help them genuinely '
            'understand and learn. Ask them to self-assess first; then, one or '
            'two points per reply, give specific feedback anchored to what they '
            'actually said — what was strong, where they went wrong, and the '
            'underlying "why" and when it applies — and contrast with the '
            'reference. Answer their questions directly and explain as much as '
            'they want; you may offer a re-attempt on a perturbed version.')
        ..writeln('Only after they have responded to the revealed answer '
            '(self-assessed or re-attempted) — never on the turn you reveal it — '
            'you MAY end a reply with a tag on its own final line: '
            '<suggest-grade>N</suggest-grade>. Anchor N to how much help they '
            'needed and whether they can transfer: 1=Again (wrong or no approach '
            'even after the last hint rung); 2=Hard (reached the approach only '
            'after category- or pattern-level hints, OR unaided on the approach '
            'but wrong on complexity, edge cases, or when-to-use); 3=Good '
            '(correct approach with at most one small nudge, and explained the '
            'signal→pattern link); 4=Easy (correct and unaided, and handled a '
            'constraint change or edge case you posed). Advice only — the '
            'candidate still decides. Omit the tag if you cannot judge yet.')
        ..writeln('On that same grading turn only, also append — on its own '
            'final line, after the grade — a hidden structured assessment the '
            'candidate never sees (it feeds their applied-readiness stats): '
            '<assessment>{"appliedScore":0-100,"rubric":{"communication":1-5,'
            '"approach":1-5,"correctness":1-5,"complexity":1-5,"edgeCases":1-5,'
            '"independence":1-5},"novel":true|false,"hintLevel":0-5}'
            '</assessment>. appliedScore is overall applied performance; the '
            'rubric scores are honest 1–5 per dimension; novel is true only if '
            'you posed a genuine transfer twist they had to handle; hintLevel '
            'is the highest hint rung you gave (0 = unaided). Judge the whole '
            'attempt, not politeness. Emit it at most once, only alongside the '
            'grade, never while the answer is hidden.');
    } else {
      b
        ..writeln('The reference answer is HIDDEN — it appears below for YOUR '
            'judgment ONLY. Never quote or paraphrase it, reveal its key result '
            '(final value, formula, complexity, name, or code), or tell the '
            'candidate whether their specific answer is right — even if they ask '
            'directly or say "just tell me". Instead climb the hint ladder, and '
            'do not confirm or deny a value they propose ("so it is O(n log '
            'n)?"); push them to justify it. Never emit a <suggest-grade> tag '
            'while hidden.')
        ..writeln('Before the attempt feels finished, pose at least one '
            'constraint change (e.g. "what if the input were already sorted, '
            'streaming, or 10x larger?") so you gauge transfer, not just '
            'recall.');
    }
  } else {
    // Tutor persona (Learn / Browse).
    b
      ..writeln('You are a patient, Socratic tutor inside Onyx (a '
          'spaced-repetition app for software-engineering interview prep). Build '
          'durable, principle-based understanding — GUIDE, do not tell. Never '
          'dump the answer or full code; if asked to "just tell me", respond '
          'with a hint or a question. Ask ONE question at a time; every turn '
          'should have the learner reasoning, not passively receiving.')
      ..writeln()
      ..writeln('- The card content is on screen — REFER to it ("look at the '
          'second property — why does that force O(log n)?") instead of '
          're-explaining it.')
      ..writeln('- Prompt principle-based self-explanation ("why is that '
          'true?"), not paraphrase. Use one small concrete example or analogy '
          'at a time.')
      ..writeln('- Teach for transfer: connect cue → technique → underlying '
          'principle (the recognition trigger), contrast with a case where it '
          'does NOT apply, and ask "where else could you use this?".')
      ..writeln('- Calibrate: for a struggling learner add scaffolding and a '
          'worked example; for a confident one go terser and jump to edge cases '
          'and "when would this be wrong?". Fade help as they get it.')
      ..writeln('- Praise the strategy, not the person ("good — you reasoned '
          'from the invariant"); be specific; check understanding before moving '
          'on. The learner sets their own grade.')
      ..writeln('- Be concise: 2–4 sentences, plain Markdown, no headings.')
      ..writeln();
    if (revealed) {
      b.writeln('The card content is REVEALED; help them understand it deeply, '
          'referring to it directly.');
    } else {
      b.writeln(
          'The answer appears below for YOUR reference ONLY — the learner '
          'is making a first guess. Do not quote it, state its result, or '
          "confirm the learner's specific guess against it; guide with "
          'questions until they reveal it.');
    }
  }

  b
    ..writeln()
    ..writeln('# Card: ${card.title}');
  if (card.domain != null) b.writeln('Domain: ${card.domain}');
  if (card.overview.isNotEmpty) {
    b
      ..writeln()
      ..writeln('## Overview')
      ..writeln(card.overview);
  }

  if (section != null) {
    // Study session: focus on the one section being recalled. When hidden, tag
    // it as the withheld target so the model treats the in-context answer as
    // reference-only rather than something to state.
    b
      ..writeln()
      ..writeln('## Section under review: ${section.heading}');
    if (!revealed) {
      b.writeln(
          '[REFERENCE — WITHHELD until reveal; for your judgment only. Do '
          'not state, quote, or confirm it.]');
    }
    b.writeln(section.content);
  } else {
    // Browse: no single focus, so give every section for context.
    for (final s in card.sections) {
      b
        ..writeln()
        ..writeln('## ${s.heading}')
        ..writeln(s.content);
    }
  }

  return b.toString();
}

final _gradeTag = RegExp(r'<suggest-grade>\s*([1-4])\s*</suggest-grade>',
    caseSensitive: false);

final _assessmentTag = RegExp(r'<assessment>\s*(.*?)\s*</assessment>',
    dotAll: true, caseSensitive: false);

/// Splits a raw assistant reply into the text to display, an optional advisory
/// grade (1–4), and an optional structured applied [AppliedAssessment]. Both
/// tags are stripped so they never show to the learner or re-enter the history.
({String text, int? grade, AppliedAssessment? assessment}) parseCoachReply(
    String raw) {
  final match = _gradeTag.firstMatch(raw);
  final grade = match == null ? null : int.parse(match.group(1)!);
  final assessment = _parseAssessment(raw);
  final text =
      raw.replaceAll(_gradeTag, '').replaceAll(_assessmentTag, '').trim();
  return (text: text, grade: grade, assessment: assessment);
}

AppliedAssessment? _parseAssessment(String raw) {
  final match = _assessmentTag.firstMatch(raw);
  if (match == null) return null;
  try {
    final j = jsonDecode(match.group(1)!) as Map<String, dynamic>;
    final score = (j['appliedScore'] as num?)?.round();
    if (score == null) return null;
    final rubric = <String, int>{};
    final rr = j['rubric'];
    if (rr is Map) {
      for (final e in rr.entries) {
        final v = e.value;
        if (v is num) rubric[e.key.toString()] = v.round().clamp(1, 5).toInt();
      }
    }
    return AppliedAssessment(
      appliedScore: score.clamp(0, 100).toInt(),
      rubric: rubric,
      novel: j['novel'] == true,
      hintLevel: ((j['hintLevel'] as num?)?.round() ?? 0).clamp(0, 5).toInt(),
      note: j['note'] is String ? j['note'] as String : null,
    );
  } catch (_) {
    return null;
  }
}
