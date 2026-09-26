import 'dart:convert';

import '../../shared/models/card.dart';
import '../interview/assessment.dart';

/// Who authored a coach turn.
enum CoachRole { user, assistant }

/// Which coach surface a conversation belongs to. Persisted on each
/// `coach_messages` row (its [name]) so transcripts that share a
/// `(cardId, sectionSlug)` don't clear or interleave each other (n0015):
///  - [coach]    — the general / browse (whole-card) chat.
///  - [tutor]    — the Learn first-exposure tutor (grading off, per section).
///  - [examiner] — the Review / mock examiner (grading on, per section).
enum CoachKind { coach, tutor, examiner }

/// The [CoachKind] for a surface, from whether it grades and whether it's scoped
/// to a section: a whole-card (browse) chat is [CoachKind.coach]; a per-section
/// chat is the [CoachKind.examiner] when grading, else the [CoachKind.tutor].
CoachKind coachKindFor({required bool grading, required bool hasSection}) =>
    !hasSection
        ? CoachKind.coach
        : (grading ? CoachKind.examiner : CoachKind.tutor);

/// One turn in a coach conversation. Assistant turns may carry an advisory
/// [suggestedGrade] (1–4) parsed out of the reply — the app highlights that
/// grade button, but the learner always taps for themselves.
class CoachMessage {
  const CoachMessage(this.role, this.text, {this.suggestedGrade});

  final CoachRole role;
  final String text;
  final int? suggestedGrade;
}

/// The research-backed **foundation** of the coach's voice — ALWAYS emitted,
/// grounded in learning science (retrieval practice, transfer, the Socratic
/// method, autonomy-support). A subject's vault skill ([CoachSkill]) *augments*
/// this with domain specifics; it never replaces it, so every subject keeps the
/// pedagogical foundation even with a thin or absent skill (task #30).
const _foundationReview =
    'You are a calm, rigorous examiner running a mock assessment inside Onyx (a '
    'spaced-repetition study app). Your job is the part flashcards cannot do: '
    'not rote recall, but whether the learner can APPLY the idea. Probe for '
    'transfer — why this idea fits here, when it would not, and how it holds up '
    'when a detail of the problem changes.';

const _foundationLearn =
    'You are a patient, Socratic tutor inside Onyx (a spaced-repetition study '
    'app). Build durable, principle-based understanding — GUIDE, do not tell. '
    'Never just hand over the answer; if asked to "just tell me", respond with a '
    'hint or a question. Ask ONE question at a time; every turn should have the '
    'learner reasoning, not passively receiving.';

/// A subject's **domain augmentation** to the coach's foundational voice, authored
/// in the vault skill `_meta/coach.md` (parsed by [coachSkillFromMarkdown]) and
/// LAYERED on top of the learning-science foundation — never replacing it. Every
/// field is optional; [none] (no skill) leaves the foundation to stand alone. The
/// engine still owns the *mechanics* (hint ladder, reveal rules, grade/assessment
/// protocol, card embedding); a skill only adds the subject's framing + emphasis.
class CoachSkill {
  const CoachSkill({
    this.reviewAugment,
    this.learnAugment,
    this.topicFit,
    this.firstExposureAugment,
  });

  /// Domain framing layered onto the grading (Review) foundation.
  final String? reviewAugment;

  /// Domain framing layered onto the tutor (Learn) foundation.
  final String? learnAugment;

  /// Optional examiner topic-fit guidance (one bullet) for the grading persona.
  final String? topicFit;

  /// Optional *first-exposure* framing/tone (n0015) — discovery-stage guidance
  /// (e.g. "keep it playful; wrong first guesses are fine"). The first-exposure
  /// tutor consumes ONLY this, never [learnAugment]/[topicFit], so a non-SWE deck
  /// never inherits interview/code framing at first exposure.
  final String? firstExposureAugment;

  /// No vault skill — the foundation stands alone.
  static const none = CoachSkill();
}

/// Parse a vault coach skill (`_meta/coach.md`) into a [CoachSkill]. The file is
/// markdown with any of `## Reviewing`, `## Learning`, `## Topic fit`,
/// `## First exposure` (each body the prose up to the next H2) — ALL optional,
/// since a skill only *augments* the foundation. Missing/empty → that field is
/// null (foundation stands). Pure.
CoachSkill coachSkillFromMarkdown(String md) {
  final sections = <String, String>{};
  String? key;
  final buf = StringBuffer();
  void flush() {
    if (key != null) {
      final body = buf.toString().trim();
      if (body.isNotEmpty) sections[key] = body;
    }
    buf.clear();
  }

  for (final line in const LineSplitter().convert(md)) {
    final h = RegExp(r'^##\s+(.+?)\s*$').firstMatch(line);
    if (h != null) {
      flush();
      key = h.group(1)!.toLowerCase();
    } else if (key != null) {
      buf.writeln(line);
    }
  }
  flush();

  return CoachSkill(
    reviewAugment: sections['reviewing'],
    learnAugment: sections['learning'],
    topicFit: sections['topic fit'],
    firstExposureAugment: sections['first exposure'],
  );
}

/// Builds the system prompt for a coaching conversation. The prompt embeds the
/// card (and, in a study session, the specific section being recalled) so the
/// coach can reason about the exact material without another round-trip.
///
/// Three levers change its behavior:
/// - [grading]: selects the persona. true → the grading *examiner* (Review):
///   probes, and may append an advisory grade tag. false → the *tutor*
///   (Learn/Browse): explains to build understanding, no grade tag.
/// - [revealed]: before reveal the coach must *hint* without spoiling; after
///   reveal it may discuss the answer fully.
/// - [firstExposure] (n0015): on the tutor persona (`grading: false`), swaps in
///   the FIRST-EXPOSURE contract — a post-reveal-but-still-withholding Socratic
///   step that elicits self-explanation (the learner generates), caps at the
///   self-explanation rung (no transfer escalation — that's Review's job), and
///   closes with a `<tutor-done/>` sentinel. Consumes only [CoachSkill.firstExposureAugment].
///   No effect on the examiner. Assumed to run after reveal.
///
/// [skill] is the subject's OPTIONAL vault-skill augmentation (loaded in
/// production by `coachSkillProvider`). The research-backed foundation is always
/// emitted first, so a caller that passes nothing ([CoachSkill.none]) still gets
/// the full pedagogical coach — only without domain-specific framing.
String buildCoachSystem({
  required Card card,
  CardSection? section,
  required bool revealed,
  required bool grading,
  bool firstExposure = false,
  String? interviewContext,
  CoachSkill skill = CoachSkill.none,
}) {
  final b = StringBuffer();
  if (grading) {
    // Foundation (always) + the subject's optional domain augmentation.
    b.writeln(_foundationReview);
    if (skill.reviewAugment != null) {
      b.writeln('For this material: ${skill.reviewAugment}');
    }
    if (interviewContext != null && interviewContext.trim().isNotEmpty) {
      b.writeln('This mock is prep for a specific interview: '
          '${interviewContext.trim()}. Pitch the difficulty and emphasis to '
          'that role/level; any company-specific slant is advisory, so keep it '
          'light and stay grounded in the card below.');
    }
    b
      ..writeln()
      ..writeln('- Make the learner do the thinking. Ask ONE focused question '
          'at a time; never lecture or answer your own question.')
      ..writeln(
          '- Give the SMALLEST useful help, only after a genuine attempt, '
          'climbing this hint ladder one rung at a time and only while they are '
          'stuck: (1) ask where they are stuck; (2) redirect them to the '
          'relevant detail; (3) name the category of problem; (4) point to the '
          'pattern; (5) as a last resort, give one concrete mechanical step — '
          'never the whole solution. Fade help as they recover.');
    if (skill.topicFit != null) b.writeln('- ${skill.topicFit}');
    b
      ..writeln('- Firm through hard questions, never hostile; keep it '
          'low-stakes so they reason freely. The learner owns their grade — '
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
            'learner still decides. Omit the tag if you cannot judge yet.')
        ..writeln('On that same grading turn only, also append — on its own '
            'final line, after the grade — a hidden structured assessment the '
            'learner never sees (it feeds their applied-readiness stats): '
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
            'learner whether their specific answer is right — even if they ask '
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
    // Foundation (always) + the subject's optional domain augmentation.
    b.writeln(_foundationLearn);
    if (firstExposure) {
      // n0015: the FIRST-EXPOSURE tutor — a distinct post-reveal-but-still-
      // withholding contract. The learner has just revealed the section; the AI
      // makes THEM put it into words (elicit, don't explain), grounded in the
      // visible text, capped at self-explanation, closing with <tutor-done/>.
      // Consumes ONLY firstExposureAugment (never learnAugment/topicFit), so a
      // non-SWE deck never inherits interview/code framing here.
      if (skill.firstExposureAugment != null) {
        b.writeln('For this material: ${skill.firstExposureAugment}');
      }
      b
        ..writeln()
        ..writeln('- The card is on screen. Your job: make the LEARNER put it '
            'into their own words — you elicit, they think. Anchor every '
            'question to the visible text.')
        ..writeln('- This is DISCOVERY, not a test: a wrong first guess is '
            'EXPECTED — treat it as "a reasonable first read, let\'s check it", '
            'never "not quite right".')
        ..writeln('- WITHHOLD the synthesis: you MAY point to or read a line '
            'that is on screen, but do NOT articulate the why / when-to-use / '
            'transfer they should generate — that is theirs to produce.')
        ..writeln('- Do NOT confirm or deny a value they propose ("so it is '
            'O(log n)?"); reply "what makes you say that?".')
        ..writeln('- If they assert something wrong, do NOT state why it is '
            'wrong or give a counter-example — ask a question that leads them to '
            'TEST their own claim.')
        ..writeln(
            '- ONE question per reply, at the SELF-EXPLANATION rung ("what '
            'is this saying, in your own words?", "why is that true?"). Do NOT '
            'escalate to transfer / "when would it break?" — that belongs to '
            'later spaced review.')
        ..writeln('- Hint ladder — climb ONE rung only when they stall, never '
            're-ask: (1) point to the specific line; (2) a leading question '
            'toward the next step; (3) a fill-in-the-blank left for THEM ("the '
            'idea is ___ because ___") — never fill it in.')
        ..writeln('- If their FIRST answer is empty or "I don\'t know", do NOT '
            'quiz — switch to scaffolded reading: "No worries, it\'s new — read '
            'it, then tell me which line didn\'t click", and build from the line '
            'they name.')
        ..writeln('- Aim for 2 learner turns, never exceed 3. To close, ask '
            'THEM to summarize the idea in one line (never summarize back to '
            'them), then emit <tutor-done/> on its own final line.')
        ..writeln('- NEVER emit a grade or any grade/assessment tag. Be '
            'concise: 2–3 sentences, plain Markdown, no headings.');
    } else {
      if (skill.learnAugment != null) {
        b.writeln('For this material: ${skill.learnAugment}');
      }
      b
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
            'worked example; for a confident one go terser and jump to edge '
            'cases and "when would this be wrong?". Fade help as they get it.')
        ..writeln('- Praise the strategy, not the person ("good — you reasoned '
            'from the invariant"); be specific; check understanding before '
            'moving on. The learner sets their own grade.')
        ..writeln('- Be concise: 2–4 sentences, plain Markdown, no headings.')
        ..writeln();
      if (revealed) {
        b.writeln('The card content is REVEALED; help them understand it '
            'deeply, referring to it directly.');
      } else {
        b.writeln(
            'The answer appears below for YOUR reference ONLY — the learner '
            'is making a first guess. Do not quote it, state its result, or '
            "confirm the learner's specific guess against it; guide with "
            'questions until they reveal it.');
      }
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

/// The sentinel a first-exposure tutor emits (n0015) to signal the exchange is
/// complete.
final _tutorDoneTag = RegExp(r'<tutor-done\s*/?>', caseSensitive: false);

/// Parse a FIRST-EXPOSURE tutor reply: the display [text] (with the `<tutor-done/>`
/// sentinel stripped) and whether the exchange is [done]. Kept SEPARATE from
/// [parseCoachReply] so the shared grading path is untouched (n0015). First
/// exposure is never graded, so any stray grade/assessment tag is stripped too and
/// a grade is never surfaced.
({String text, bool done}) parseFirstExposureReply(String raw) {
  final done = _tutorDoneTag.hasMatch(raw);
  final text = raw
      .replaceAll(_tutorDoneTag, '')
      .replaceAll(_gradeTag, '')
      .replaceAll(_assessmentTag, '')
      .trim();
  return (text: text, done: done);
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
