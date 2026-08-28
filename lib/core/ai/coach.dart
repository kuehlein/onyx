import '../../shared/models/card.dart';

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
/// - [revealed]: before reveal the coach must *hint* without spoiling; after
///   reveal it may discuss the answer fully.
/// - [grading]: in a study session (true) the coach may append an advisory
///   grade tag; when just browsing a card (false) grading is irrelevant, so it
///   is told not to.
String buildCoachSystem({
  required Card card,
  CardSection? section,
  required bool revealed,
  required bool grading,
}) {
  final b = StringBuffer()
    ..writeln('You are a study coach inside Onyx, a spaced-repetition app for '
        'software-engineering interview preparation. Help the learner '
        'understand and recall the card below. Be concise (2–5 sentences), '
        'Socratic, and encouraging. Use plain Markdown; no headings.')
    ..writeln()
    ..writeln(
        'The learner owns their own grading. Never grade for them or order '
        'them to press a button.');

  if (revealed) {
    b.writeln('The answer is REVEALED, so you may discuss it fully, correct '
        'misconceptions, and go deeper.');
  } else {
    b.writeln('The answer is currently HIDDEN. Give hints that nudge recall '
        'WITHOUT stating the answer or its key result. If pushed, escalate the '
        'hint gradually rather than handing over the whole solution.');
  }

  if (grading && revealed) {
    b.writeln('When the learner has described what they recalled and you can '
        'fairly judge it, you MAY end your reply with a tag on its own final '
        'line: <suggest-grade>N</suggest-grade> where N is 1=Again, 2=Hard, '
        '3=Good, 4=Easy. It is advice only — the learner still decides. Omit '
        'the tag if you cannot judge yet.');
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
    // Study session: focus on the one section being recalled.
    b
      ..writeln()
      ..writeln('## Section under review: ${section.heading}')
      ..writeln(section.content);
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

/// Splits a raw assistant reply into the text to display and an optional
/// advisory grade (1–4). The tag is stripped so it never shows to the learner
/// and never re-enters the conversation history.
({String text, int? grade}) parseCoachReply(String raw) {
  final match = _gradeTag.firstMatch(raw);
  final grade = match == null ? null : int.parse(match.group(1)!);
  final text = raw.replaceAll(_gradeTag, '').trim();
  return (text: text, grade: grade);
}
