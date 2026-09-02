/// Builds the prompt for the AI interview-readiness report (task #24) — an
/// honest, on-demand assessment that turns the readiness *number* into a
/// narrative: where you stand for your specific target, what your deck is likely
/// missing for that bar (scope gaps the metric itself can't see, since it only
/// knows your cards), and what to do next.
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
    ..writeln('- SCOPE GAPS are your highest-value contribution. You can see '
        'only the topics in their deck (listed per domain). Compare that to '
        'what a strong candidate FOR THIS TARGET is expected to know, and call '
        'out concretely what looks missing or thin (name the specific topics — '
        'e.g. "no cards on consistent hashing, rate limiting, or CAP '
        'trade-offs"). Note this is inferred from card titles, so a topic may '
        'be covered under another name — frame gaps as "appears missing".')
    ..writeln('- If an interview date is given, factor the time remaining into '
        'what is realistic to fix.')
    ..writeln('- End with a short, PRIORITISED action list ordered by impact '
        'toward this target (what to study, what to mock, what to add to the '
        'deck).')
    ..writeln()
    ..writeln('Format as concise Markdown with these sections, in order:')
    ..writeln('## Verdict — 1–2 sentences: are they on track for this target, '
        'and a rough sense of how far off.')
    ..writeln('## Strengths — the domains/evidence that are genuinely solid.')
    ..writeln('## Gaps & risks — weak domains, unproven transfer, and SCOPE '
        'GAPS (missing/thin topics for this target).')
    ..writeln('## Do next — a numbered, prioritised list (3–6 items).')
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
      b.writeln('- Deck topics: (none)');
    } else {
      b.writeln('- Deck topics (${r.topics.length}): ${r.topics.join(', ')}');
    }
  }

  b
    ..writeln()
    ..writeln('Write the assessment now.');
  return b.toString();
}
