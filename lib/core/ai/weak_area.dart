/// Prompts for the AI weak-area drill-down (task #23): a focused, single-domain
/// explanation of *why* one domain is weak — which of the three gaps dominates
/// (unstudied coverage, low retention/strength, or unproven transfer) — plus a
/// couple of specific next steps grounded in that domain's own topics/concepts
/// and the learner's target + time left.
///
/// This is the focused counterpart to the holistic readiness report
/// (readiness_report.dart): it reuses the same [DomainReportRow] evidence but
/// answers one narrow question the whole-deck report can't dwell on. It mirrors
/// that report's voice — honest, task-level, autonomy-supportive, learning-
/// science-aligned (no praise-padding) — but is a short, cheap Q&A-style call.
library;

import '../util.dart';
import 'readiness_report.dart';

/// The system prompt: the persona + rules for a tight, single-domain diagnosis.
/// Kept separate from the data so it can be reviewed and tested.
String buildWeakAreaSystem() {
  final b = StringBuffer();
  b
    ..writeln('You are a candid study coach inside Onyx (a spaced-repetition + '
        'mock-practice study app). The learner tapped ONE domain on their '
        'readiness dashboard to understand it. You are given that domain\'s hard '
        'data and their target. Explain what is actually going on and what to do '
        '— honestly, not comfortingly.')
    ..writeln()
    ..writeln('Your job, in order:')
    ..writeln(
        '1. In 2–3 sentences, explain WHY this domain sits where it does, and '
        'name which gap DOMINATES — one of:')
    ..writeln('   - COVERAGE: too little of the domain studied yet '
        '(studied/total low) — recall can\'t be strong on material not seen.')
    ..writeln('   - RETENTION / STRENGTH: studied, but not durably retained '
        '(low strength) — it needs review to stick.')
    ..writeln('   - TRANSFER: recalled but unproven under pressure (few or no '
        'mocks, or contested grades) — recall alone does not clear the bar.')
    ..writeln('   Anchor the diagnosis to the numbers you were given (name the '
        'coverage / strength / mock evidence); never invent numbers.')
    ..writeln(
        '2. Then give 2–3 SPECIFIC, ACTIONABLE next steps, grounded in THIS '
        'domain\'s listed topics/concepts and the target + days left — e.g. '
        '"study X and Y (unstarted)", "review Z to raise retention", "do a mock '
        'on this domain to prove transfer". Point at real topics from the list, '
        'not generic advice.')
    ..writeln()
    ..writeln('Rules:')
    ..writeln('- Judge against the SPECIFIC target (level × context × track), '
        'not a generic bar — a senior/advanced bar is far higher than entry.')
    ..writeln(
        '- Be task-level, not ego-level: describe the work to do ("do X"), '
        'not the person ("great job"). No praise-padding, no false comfort, no '
        'filler.')
    ..writeln(
        '- Be autonomy-supportive: recommend, and give the reasoning, but '
        'leave the choice to them.')
    ..writeln(
        '- If the domain is actually STRONG (well covered, well retained, '
        'proven), say so briefly and plainly — do NOT invent a weakness.')
    ..writeln('- If time is short, factor days-left into what is realistic.')
    ..writeln()
    ..writeln('Format: plain, tight Markdown — a short lead paragraph then a '
        'few bullet next-steps. No headings, no preamble, no restating these '
        'instructions. Keep it brief.');
  return b.toString();
}

/// The user prompt: one domain's evidence + the target, formatted compactly.
String buildWeakAreaUser(
  DomainReportRow row, {
  required String targetLabel,
  int? daysToInterview,
  required bool interviewTested,
}) {
  final b = StringBuffer();
  // "Proven" transfer needs BOTH a transfer estimate and actual mock attempts —
  // a domain with no mocks is recall-only *even when other domains have mocks*.
  final proven = row.transfer != null && row.mocks > 0;
  b
    ..writeln('# Domain: ${row.name}')
    ..writeln('- Readiness: ${pct(row.score)}%'
        '${proven ? ' (proven transfer ${pct(row.transfer!)}%)' : ''}')
    ..writeln('- Coverage: ${row.studied}/${row.total} sections started '
        '(${pct(row.coverage)}%)')
    ..writeln('- Retention strength: ${pct(row.strength)}%');
  if (proven) {
    b.writeln('- Mock attempts: ${row.mocks}'
        '${row.contested > 0 ? ' (${row.contested} grade(s) the critic '
            'disputed)' : ''}');
  } else {
    b.writeln('- Mock attempts: none yet '
        '(recall-only for this domain — transfer unproven)');
  }
  if (row.topics.isEmpty) {
    b.writeln('- Deck cards: (none in this domain yet)');
  } else {
    b.writeln('- Deck cards (${row.topics.length}): ${row.topics.join(', ')}');
  }
  if (row.concepts.isNotEmpty) {
    b.writeln('- Concepts tagged (${row.concepts.length}): '
        '${row.concepts.join(', ')}');
  }

  if (!interviewTested) {
    b.writeln('- (No mock evidence anywhere yet across the deck — transfer is '
        'unproven overall.)');
  }

  b
    ..writeln()
    ..writeln('# Target')
    ..writeln(targetLabel);
  if (daysToInterview != null) {
    b.writeln('Target date in $daysToInterview day'
        '${daysToInterview == 1 ? '' : 's'}.');
  } else {
    b.writeln('No target date set.');
  }

  b
    ..writeln()
    ..writeln('Explain why this domain is where it is, and what to do next.');
  return b.toString();
}
