/// Builds the prompt for the AI interview-readiness report (task #24) — an
/// honest, on-demand assessment that turns the readiness *number* into a
/// narrative: where you stand for your target, and — its primary job — the
/// LEARNING gaps in the material you already have (topics you haven't studied,
/// haven't retained, or haven't proven under mock pressure), plus what to do
/// next. Missing-content notes are kept soft; the deck is still being built.
library;

/// One domain's evidence, as fed to the model.
class DomainReportRow {
  const DomainReportRow({
    required this.name,
    required this.coverage,
    required this.strength,
    required this.score,
    required this.studied,
    required this.total,
    required this.mocks,
    required this.contested,
    required this.topics,
    this.concepts = const [],
    this.transfer,
  });

  final String name; // pretty domain name, e.g. "System design"
  final double coverage; // 0..1 fraction of sections started
  final double strength; // 0..1 retention of studied ones
  final double score; // 0..1 overall domain readiness (transfer-gated if mocks)
  final double? transfer; // 0..1 proven-transfer, or null (recall-only)
  final int studied;
  final int total;
  final int mocks; // applied attempts backing transfer
  final int contested; // attempts the adversarial critic disputed
  final List<String> topics; // card titles in this domain (the deck's scope)
  final List<String> concepts; // finer-grained concepts the cards tag
}

/// Everything the report reasons over. Assembled by the provider from the same
/// readiness/target/vault data the dashboard uses, so the narrative and the
/// number can never disagree.
class ReadinessReportData {
  const ReadinessReportData({
    required this.targetLabel,
    required this.level,
    required this.company,
    required this.track,
    required this.overall,
    required this.low,
    required this.high,
    required this.interviewTested,
    required this.domains,
    this.daysToInterview,
  });

  final String targetLabel; // "Senior · FAANG · General"
  final String level;
  final String company;
  final String track;
  final double overall; // 0..1
  final double low; // band lower bound
  final double high; // band upper bound
  final bool interviewTested; // mocks exist → transfer in play
  final int? daysToInterview; // null when no date set
  final List<DomainReportRow> domains; // weakest-first
}

int _pct(double v) => (v.clamp(0, 1) * 100).round();

/// The system prompt for the report Q&A chat: the learner just read the
/// assessment below and wants to discuss it. Grounded in that report,
/// autonomy-supportive, concise. Follows the same feedback principles as the
/// coach (task-level, honest, offer choices — never ego/praise).
String buildReadinessReportChatSystem(String reportText) {
  final b = StringBuffer();
  b
    ..writeln('You are a candid software-engineering interview-prep strategist '
        'inside Onyx. You just wrote the readiness assessment below for this '
        'learner, and they want to discuss it. Answer their follow-up questions '
        'about where they stand and what to do next.')
    ..writeln()
    ..writeln('Rules:')
    ..writeln(
        '- Ground your answers in the assessment below and stay consistent '
        'with it. If they ask about something it did not cover, reason from what '
        'you know but flag that it is beyond the report\'s data.')
    ..writeln(
        '- Be concrete and honest — no false comfort. Give a specific next '
        'step over generic encouragement, and prefer task-level advice to praise.')
    ..writeln(
        '- Be autonomy-supportive: lay out options and the reasoning, then '
        'let THEM choose. One focused point at a time; 2–4 sentences, plain '
        'Markdown, no headings.')
    ..writeln('- Never invent numbers you were not given.')
    ..writeln()
    ..writeln('--- THE READINESS ASSESSMENT ---')
    ..writeln(reportText);
  return b.toString();
}

/// The system prompt: the persona + rules for an honest, scope-aware readiness
/// assessment. Kept separate from the data so it can be reviewed and tested.
String buildReadinessReportSystem() {
  final b = StringBuffer();
  b
    ..writeln('You are a seasoned software-engineering interviewer and prep '
        'strategist writing a candid interview-readiness assessment for a '
        'candidate using Onyx (a spaced-repetition + mock-interview prep app). '
        'You are given their target role and hard data about their study '
        'progress. Write the assessment they need, not the one that feels good.')
    ..writeln()
    ..writeln('Ground rules:')
    ..writeln('- Be honest and specific. No vague encouragement, no false '
        'comfort. Anchor every claim to the numbers provided (name the domain '
        'and its coverage/strength/mock evidence).')
    ..writeln('- Judge against the SPECIFIC target (level × company × track), '
        'not a generic bar. A FAANG senior bar is very different from a '
        'new-grad-at-a-typical-company bar; weight system design vs. DS&A '
        'accordingly.')
    ..writeln('- Distinguish RECALL (they can retrieve it) from APPLIED '
        'TRANSFER (they proved they can use it under interview pressure, via '
        'mocks). If there is little or no mock evidence, say plainly that '
        'readiness is unproven — recall alone does not clear an interview.')
    ..writeln(
        '- LEARNING GAPS are your primary focus: within the material they '
        'ALREADY have (topics/concepts listed per domain), what have they not '
        'yet studied (low coverage), not retained (low strength), or not proven '
        'under pressure (no/weak mock transfer)? Name the specific domains and '
        'topics and what to do about each. This — not missing content — is what '
        'the learner wants help with.')
    ..writeln(
        '- CONTENT gaps are SECONDARY and SOFT. Their deck is still being '
        'built, so do NOT alarm about missing cards. You may add at most a brief '
        'note if something clearly essential for this target seems absent from '
        'the listed topics/concepts — framed as "as you build out the deck, '
        'consider adding X" — but this is inferred from titles/concepts and may '
        'already be covered under another name, so keep it tentative and short.')
    ..writeln('- If an interview date is given, factor the time remaining into '
        'what is realistic to fix.')
    ..writeln('- End with a short, PRIORITIZED action list ordered by impact '
        'toward this target — mostly what to STUDY, STRENGTHEN, or MOCK.')
    ..writeln()
    ..writeln('Format as concise Markdown with these sections, in order:')
    ..writeln('## Verdict — 1–2 sentences: are they on track for this target, '
        'and a rough sense of how far off.')
    ..writeln('## Strengths — the domains/evidence that are genuinely solid.')
    ..writeln('## Gaps & risks — lead with LEARNING gaps (unstudied, weak, or '
        'unproven topics they already have); a brief, soft content note only if '
        'clearly warranted.')
    ..writeln('## Do next — a numbered, prioritized list (3–6 items).')
    ..writeln('Keep it tight — no preamble, no restating these instructions.');
  return b.toString();
}

/// The user prompt: the candidate's target + progress data, formatted compactly.
String buildReadinessReportUser(ReadinessReportData d) {
  final b = StringBuffer();
  b
    ..writeln('# Target')
    ..writeln('Role: ${d.targetLabel} (level: ${d.level}, company: '
        '${d.company}, track: ${d.track}).');
  if (d.daysToInterview != null) {
    b.writeln('Interview in ${d.daysToInterview} day'
        '${d.daysToInterview == 1 ? '' : 's'}.');
  } else {
    b.writeln('No interview date set.');
  }

  b
    ..writeln()
    ..writeln('# Overall readiness')
    ..writeln('${_pct(d.overall)}% (plausible range ${_pct(d.low)}–'
        '${_pct(d.high)}%). Evidence: '
        '${d.interviewTested ? 'mock-tested (transfer measured)' : 'recall-only '
            '— no mock-interview evidence yet, so this is unproven'}.');

  b
    ..writeln()
    ..writeln('# Per-domain (weakest first)');
  for (final r in d.domains) {
    b
      ..writeln('## ${r.name}')
      ..writeln('- Readiness: ${_pct(r.score)}%'
          '${r.transfer != null ? ' (transfer ${_pct(r.transfer!)}%)' : ''}')
      ..writeln('- Coverage: ${r.studied}/${r.total} sections started '
          '(${_pct(r.coverage)}%); retention strength ${_pct(r.strength)}%')
      ..writeln('- Mock interviews: ${r.mocks}'
          '${r.contested > 0 ? ' (${r.contested} grade(s) the critic '
              'disputed)' : ''}');
    if (r.topics.isEmpty) {
      b.writeln('- Deck cards: (none)');
    } else {
      b.writeln('- Deck cards (${r.topics.length}): ${r.topics.join(', ')}');
    }
    if (r.concepts.isNotEmpty) {
      b.writeln('- Concepts tagged (${r.concepts.length}): '
          '${r.concepts.join(', ')}');
    }
  }

  b
    ..writeln()
    ..writeln('Write the assessment now.');
  return b.toString();
}
