/// System prompt + reply parsing for the Algorithms track's EXPLAIN mode — the
/// recognition clock. A distinct persona from the card coach (core/ai/coach.dart)
/// and the strategist (coach_update_chat.dart): here the coach is an interviewer
/// running a *verbal* round. The candidate talks through a problem they've
/// solved before — approach, complexity, edge cases, and the recognition
/// trigger — WITHOUT writing code. It's phone-doable maintenance that keeps a
/// pattern recognizable between full solves.
///
/// The coach may, once the candidate has genuinely explained, append an advisory
/// self-grade tag `<recognition>solid|shaky|lost</recognition>`. It only
/// suggests; the learner sets their own recognition grade. Explaining never
/// feeds readiness or the solve schedule.
library;

import '../../shared/models/card.dart';

/// Builds the explain-mode interviewer prompt, seeded with the problem so the
/// coach can judge the explanation without another round-trip. [section] is the
/// specific problem (its content is the recognition cue / link); [card] is the
/// pattern it belongs to.
String buildExplainCoachSystem(
    {required Card card, required CardSection section}) {
  final b = StringBuffer();
  b
    ..writeln('You are a calm, rigorous technical interviewer inside Onyx (a '
        'spaced-repetition app for software-engineering interview prep). This '
        'is a VERBAL round: the candidate has solved this problem before and is '
        'now re-explaining it from memory to keep the pattern sharp. NO coding '
        'happens — do not ask them to write or paste code.')
    ..writeln()
    ..writeln('Draw out, one focused question at a time (never lecture, never '
        'answer your own question):')
    ..writeln('- the recognition trigger — what in the problem signals this '
        'pattern ("${card.title}")?')
    ..writeln('- the approach at a high level (the key idea / invariant);')
    ..writeln('- the time & space complexity, and why;')
    ..writeln('- the main edge cases, and when this approach would be WRONG.')
    ..writeln()
    ..writeln('- Make the candidate do the thinking. If they stall, give the '
        'smallest nudge, not the answer.')
    ..writeln('- Be concise: 2–4 sentences, plain Markdown, no headings.')
    ..writeln('- Keep it low-stakes and supportive; firm, never hostile.')
    ..writeln()
    ..writeln(
        'Once they have genuinely explained the core (or clearly cannot), '
        'you MAY end a reply with a tag on its own final line: '
        '<recognition>solid|shaky|lost</recognition>. solid = recalled the '
        'trigger, approach, and complexity largely unaided; shaky = got there '
        'but needed prompting or missed a piece (complexity / edge cases); '
        'lost = could not reconstruct the approach. Advice only — the candidate '
        'sets their own grade. Omit it until you can judge, and emit it at most '
        'once.')
    ..writeln()
    ..writeln('# Pattern: ${card.title}');
  if (card.domain != null) b.writeln('Domain: ${card.domain}');
  b
    ..writeln()
    ..writeln('## Problem: ${section.heading}')
    ..writeln(
        '[Reference for YOUR judgment — the recognition cue the candidate '
        'is recalling. Do not read it to them; make them produce it.]')
    ..writeln(section.content);
  return b.toString();
}

/// An advisory recognition grade the coach suggested in a reply.
enum RecognitionSuggestion { solid, shaky, lost }

final _recognitionTag = RegExp(
    r'<recognition>\s*(solid|shaky|lost)\s*</recognition>',
    caseSensitive: false);

/// Splits a raw assistant reply into the text to display and an optional
/// advisory recognition grade. The tag is stripped so it never shows or
/// re-enters the history.
({String text, RecognitionSuggestion? suggestion}) parseExplainReply(
    String raw) {
  final match = _recognitionTag.firstMatch(raw);
  final suggestion = switch (match?.group(1)?.toLowerCase()) {
    'solid' => RecognitionSuggestion.solid,
    'shaky' => RecognitionSuggestion.shaky,
    'lost' => RecognitionSuggestion.lost,
    _ => null,
  };
  final text = raw.replaceAll(_recognitionTag, '').trim();
  return (text: text, suggestion: suggestion);
}
