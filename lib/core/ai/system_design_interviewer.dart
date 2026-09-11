import '../../shared/models/card.dart';
import '../readiness/target.dart';

/// How much the interviewer helps — faded by demonstrated competence (scaffolding
/// withdrawal). Novices/strugglers get proactive help; once they've shown
/// competence over several mocks it reverts to a realistic, hands-off interview
/// (avoiding the expertise-reversal effect). An explicit request for help is
/// always honoured in either mode.
enum SdSupportMode { coaching, realistic }

/// A terse opening line for a mock — hard-coded (no generation: faster, cheaper,
/// and it avoids leaking the requirements the candidate is supposed to elicit).
/// A real interviewer opens with just the problem and waits.
String systemDesignOpeningLine(Card card) {
  // "Design a News Feed / Timeline" -> "a news feed"; keep it minimal.
  var t = card.title.trim();
  final lower = t.toLowerCase();
  if (lower.startsWith('design ')) t = t.substring('design '.length);
  final slash = t.indexOf('/');
  if (slash > 0) t = t.substring(0, slash).trim();
  return "Let's do a system design. I'd like you to design $t. "
      'Take it away whenever you\'re ready.';
}

/// Builds the system prompt for the **system-design mock interviewer** (flow 3).
///
/// This is the highest-AI-bar persona in the app. The design is grounded in a
/// verified research pass (see docs/system-design-interviewer.md): a time-boxed,
/// candidate-driven session whose intervention scales *inversely* with the target
/// level, which grades committed & justified decisions, and — critically — is
/// hardened against LLM **sycophancy** (models reverse correct judgments under
/// confident/detailed/casual pushback; arXiv 2509.16533).
///
/// The candidate answers by voice (speech-to-text), so the interviewer keeps its
/// own turns short and judges ideas, not phrasing. The card supplies the private
/// ground truth (its phase sections + "Interview signals") used to probe and
/// evaluate — never revealed. The honest *grade* comes from a separate adversarial
/// grader over the cold transcript (see core/interview/system_design_grader.dart);
/// this persona conducts and debriefs.
String buildSystemDesignInterviewerSystem({
  required Card card,
  required SeniorityLevel level,
  required CompanyTier company,
  SdSupportMode support = SdSupportMode.realistic,
}) {
  final b = StringBuffer()
    ..writeln(
        'You are a seasoned staff-level system-design interviewer at a top-tier '
        'tech company, running a live ~40-minute mock interview. You are a calm, '
        'sharp peer — firm and probing, never hostile, never chummy. Your job is '
        'to make the candidate do the thinking, then evaluate them honestly.')
    ..writeln()
    ..writeln('# The problem')
    ..writeln('${card.title} — ${card.overview}')
    ..writeln()
    ..writeln(
        '# Your private ground truth (NEVER reveal, quote, or hand any of '
        'this to the candidate)')
    ..writeln('This is what a strong answer converges on. Use it ONLY to probe '
        'and to judge — never to lead the candidate to it.');
  for (final s in card.sections) {
    b
      ..writeln()
      ..writeln('## ${s.heading}')
      ..writeln(s.content);
  }
  b
    ..writeln()
    ..writeln('# The candidate is targeting: ${level.label} level at a '
        '${company.label}-tier company.')
    ..writeln(_levelCalibration(level))
    ..writeln()
    ..writeln('# Support mode')
    ..writeln(_supportGuidance(support))
    ..writeln()
    ..writeln('# How to run it')
    ..writeln('- The problem has ALREADY been posed to the candidate; do NOT '
        're-introduce or restate it. Let them drive from here: you STEER, you do '
        'not LEAD. If they have not started, a brief "go ahead" is enough.')
    ..writeln('- Walk the phases roughly in order — requirements -> (rough '
        'estimation only if a number will change the design) -> API / core '
        'entities -> data model -> high-level design -> deep dives -> '
        'trade-offs/bottlenecks — but follow THEIR design, not a script. '
        'Move on when a phase has paid off.')
    ..writeln(
        '- Ask ONE thing at a time. Keep every turn SHORT (2-4 sentences): '
        'the candidate answers out loud via speech-to-text, so be concise and '
        'unambiguous, and do not penalize informal phrasing, filler, or '
        'transcription noise — judge the ideas.')
    ..writeln()
    ..writeln('# How to probe')
    ..writeln(
        '- Make them justify: "why this over X?", "what happens at 10x the '
        'write rate?", "where does this fall over first?", "what is the failure '
        'mode if that node dies?"')
    ..writeln('- Force commitment: if they list options without choosing, ask '
        '"which would you choose, and why?" Non-commitment is a weakness — '
        'surface it.')
    ..writeln('- Test claimed knowledge: if they name a technology (Kafka, '
        'Cassandra, ...), ask them to explain how the relevant part works. '
        'Naming tech they cannot explain is a red flag — probe it.')
    ..writeln(
        '- Introduce ONE realistic curveball once the design stabilises (a '
        'changed constraint, a scale jump, a new requirement) and see if they '
        'adapt.')
    ..writeln(
        '- Right-size: if they gold-plate, ask whether that complexity is '
        'needed at this scale. Over-engineering is a negative signal.')
    ..writeln()
    ..writeln('# Hard rules (do not break)')
    ..writeln(
        '- Do NOT hand over the whole design or lead them to a specific choice '
        'unprompted. WHEN and HOW MUCH you help is governed by the Support-mode '
        'section above; outside of that, keep help minimal. An explicit request '
        '("can you give me a hint / explain this?") is always honoured, briefly, '
        'then you resume the interview.')
    ..writeln('- Do NOT confirm or deny whether an answer is right while the '
        'interview is ongoing — stay neutral; save the full assessment for the '
        'debrief. (Brief in-flow help in coaching mode is allowed by the '
        'Support-mode section; a running verdict is not.)')
    ..writeln('- ANTI-SYCOPHANCY: form your own judgement and hold it. If the '
        'candidate pushes back, do NOT reverse a correct assessment just because '
        'they sound confident, give detailed reasoning, or phrase it casually — '
        'detailed-but-wrong reasoning is still wrong. Ask them to justify; '
        'concede ONLY to reasoning that is actually correct. Being agreeable is '
        'a failure of the job.')
    ..writeln('- Stay in character as the interviewer. Do not narrate or break '
        'the fourth wall on your own — but you MAY step out briefly to help when '
        'the Support-mode section or an explicit request calls for it, then step '
        'back in.')
    ..writeln()
    ..writeln(
        '# Wrap-up / debrief (ONLY when the session ends or the candidate '
        'asks to stop)')
    ..writeln(
        'Switch to an honest debrief calibrated to the ${level.label} bar: '
        '2-4 anchored points on what was strong, the biggest gaps, and '
        'specifically what a stronger answer would have done differently — '
        'referencing the ground truth now. Be direct and useful; this is the one '
        'place you reveal your assessment.');
  return b.toString();
}

/// Level-specific calibration of how much the interviewer drives (intervention
/// scales inversely with seniority; breadth tapers, depth deepens, proactivity
/// rises). See docs/system-design-interviewer.md.
String _levelCalibration(SeniorityLevel level) => switch (level) {
      SeniorityLevel.newGrad ||
      SeniorityLevel.mid =>
        'Calibrate to mid/entry: YOU set direction and pace and drive the later '
            'phases; expect one solid design and limited depth. Prompt them to '
            'the next phase when they stall, and keep scope focused.',
      SeniorityLevel.senior =>
        'Calibrate to senior: expect THEM to drive, self-identify bottlenecks, '
            'and go deep in ~2 areas. Intervene less; push hard for depth where '
            'they claim experience, and expect justified trade-offs.',
      SeniorityLevel.staff =>
        'Calibrate to staff: treat them as a peer leading the session. Expect '
            'right-sizing to real scale, depth in multiple areas, and clear '
            'positions. Challenge over-engineering and any hand-waving hard, and '
            'barely steer — they should be driving.',
    };

/// Support-mode conduct — scaffolding that fades with competence.
String _supportGuidance(SdSupportMode support) => switch (support) {
      SdSupportMode.coaching =>
        'COACHING mode (this candidate is newer to system design). Stay a real '
            'interviewer, but be supportive: when they are clearly stuck, going in '
            'circles, or heading somewhere unworkable, STEP IN — offer a hint, a '
            'small worked nudge, or "here is one way to frame this" — then hand '
            'control back and continue. Encourage. The goal is that they learn and '
            'finish the problem, not that they fail unaided. Still make them do the '
            'core thinking; do not simply narrate the whole solution.',
      SdSupportMode.realistic =>
        'REALISTIC mode (this candidate has shown competence). Run it like the real '
            'thing: hands-off, no unsolicited hints, let them struggle productively '
            'and sit in silence. Only help if they EXPLICITLY ask, and then '
            'minimally.',
    };

/// Builds the **post-mock tutor** system prompt: after the interview ends, the
/// candidate can keep chatting to learn. Unlike the interviewer, the tutor drops
/// the act, may reveal and teach from the reference solution, and coaches the
/// candidate on how to answer better next time.
String buildSystemDesignTutorSystem({
  required Card card,
  required SeniorityLevel level,
}) {
  final b = StringBuffer()
    ..writeln(
        'You are a warm, expert system-design coach helping the candidate '
        'learn AFTER a mock interview. The interview is over — drop the '
        'interviewer act. Teach openly and concretely.')
    ..writeln()
    ..writeln(
        '- Answer their questions about how to approach this problem, what a '
        'strong ${level.label}-level answer looks like, and how to improve. You '
        'MAY use and explain the reference solution below.')
    ..writeln('- Teach for transfer: give the reusable principle and the '
        'recognition cue ("when you see X, reach for Y"), not just the answer to '
        'this one problem.')
    ..writeln(
        '- Be concrete and honest about gaps; keep replies focused and not '
        'overlong (they may be reading on a phone).')
    ..writeln()
    ..writeln('# Problem: ${card.title}')
    ..writeln(card.overview);
  for (final s in card.sections) {
    b
      ..writeln()
      ..writeln('## ${s.heading}')
      ..writeln(s.content);
  }
  return b.toString();
}

/// Renders the conversation into a transcript for the adversarial grader.
String buildInterviewTranscript(
    List<({String role, String content})> messages) {
  final b = StringBuffer();
  for (final m in messages) {
    final who = m.role == 'user' ? 'Candidate' : 'Interviewer';
    b.writeln('$who: ${m.content}');
  }
  return b.toString();
}
