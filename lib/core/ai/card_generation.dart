/// The AI card-generation on-ramp (docs/content-creation.md §2.2): the learner
/// pastes notes or names a topic, and a capable model proposes a SMALL batch of
/// well-formed cards. The model emits a hidden `<cards>{…}</cards>` block (the
/// same tagged-JSON trick as the interview planner's `<plan>`), parsed here with
/// defensive fallbacks. Generation is the *first retrieval rep*, not finished
/// knowledge — everything written enters as a `draft` and is earned through the
/// existing review gate.
///
/// The card-authoring rules baked into the prompt come straight from
/// docs/learning-science.md §5 and docs/card-schema.md §1 (the quality crux).
library;

import 'dart:convert';

/// A batch of generated cards, ready to be written as local drafts. [name] is a
/// short label the model picked for the batch (used for the deck folder slug).
class GeneratedBatch {
  const GeneratedBatch({required this.name, required this.cards});

  /// A short human label for this batch (e.g. "TCP fundamentals"). Falls back to
  /// 'Generated cards' when the model omits it.
  final String name;

  final List<GeneratedCard> cards;
}

/// One proposed card: an H1 [title], a few [tags], and 1–3 quizzable [sections].
class GeneratedCard {
  const GeneratedCard({
    required this.title,
    required this.tags,
    required this.sections,
  });

  final String title;
  final List<String> tags;
  final List<({String heading, String content})> sections;
}

/// The card-authoring system prompt. Instructs a capable model to write a small
/// batch of well-formed cards following the learning-science formulation rules,
/// and to emit them in a hidden tagged-JSON block. The learner's pasted notes or
/// topic go in the USER message, never here.
String buildCardGenerationSystem({required DateTime today}) {
  final todayStr = _fmtDate(today);
  final b = StringBuffer();
  b
    ..writeln(
        'You are a flashcard author inside Onyx, a spaced-repetition study '
        'app. The learner will paste some notes OR name a topic they want to '
        'study. Turn it into a SMALL batch of high-quality, self-testable cards '
        'they will review by active recall. You are proposing a starting point, '
        'not a finished body of knowledge — the learner will test and vet each '
        'card before it counts, so favour a few excellent cards over many shallow '
        'ones.')
    ..writeln()
    ..writeln(
        'Each card has an H1 title and one to three `## ` sections; every '
        'section becomes an independent recall prompt shown as '
        '"Title — Section heading", so it must stand on its own. Write cards that '
        'follow these formulation rules (they are what make recall stick):')
    ..writeln(
        '- One coherent idea per section, answerable from its heading alone. '
        'Split a section that secretly bundles several independent facts; never '
        'shatter one coherent idea into trivia.')
    ..writeln(
        '- Lead with the underlying rule or principle, not rote facts — the '
        'learner should be able to derive the specifics from it. Prefer "why it '
        'works" over "what it is".')
    ..writeln(
        '- Do NOT make an unordered list the thing to recall ("list all X"). '
        'Encode the principle that GENERATES the list, or structure it so it is '
        'reconstructable rather than memorised by brute force.')
    ..writeln(
        '- Keep each section challenging but winnable — a prompt the learner can '
        'actually answer, never a wall of facts. Effortful recall only helps when '
        'it succeeds.')
    ..writeln(
        '- Disambiguate confusable siblings with an explicit contrast ("vs X" — '
        'name the distinguishing signal). Interference between similar items is '
        'the single biggest cause of forgetting.')
    ..writeln('- Where it fits, frame a section as conditional knowledge: the '
        'recognition triggers / "when to use this" — the observable signals that '
        'tell you this idea applies. This is the highest-value kind of card.')
    ..writeln(
        '- Phrase sections as active recall (a question the heading poses, a '
        'short sufficient answer in the body), not declarative walls of prose.')
    ..writeln(
        '- Markdown is fine in section content (short lists, a small table, '
        'inline code); keep it concise.')
    ..writeln()
    ..writeln('Scope: generate 8 to 12 cards (never more than 15, never a huge '
        'dump) — the best cards the material supports, not one per sentence. '
        'Pick a short `name` labelling the batch (a few words). Give each card 1 '
        'to 3 kebab-case tags. If the input is thin, cover it well with fewer '
        'cards rather than padding.')
    ..writeln()
    ..writeln(
        'When you are done, reply with ONE short plain-text line confirming '
        'what you made (e.g. "12 cards on TCP fundamentals"), then — on its own '
        'final line — a hidden block the learner never sees:')
    ..writeln('<cards>{"name":"<short batch label>","cards":['
        '{"title":"<card title>","tags":["<tag>",…],"sections":['
        '{"heading":"<section heading>","content":"<markdown answer>"},…]},'
        '…]}</cards>')
    ..writeln('Rules for the JSON: it must be valid JSON on that final line; '
        'every card needs a non-empty "title" and at least one section with a '
        '"heading" and "content"; 1 to 3 sections per card; keep answers short '
        'and sufficient. Emit the <cards> block exactly once. Today is '
        '$todayStr (for any dated content).');
  return b.toString();
}

final _cardsTag = RegExp(r'<cards>\s*(\{.*\})\s*</cards>', dotAll: true);

/// The hard cap on cards written from one run — a defence in depth behind the
/// prompt's "8–12" guidance so a runaway reply can never dump a huge draft pile
/// (docs/content-creation.md §2.2 conservative default).
const kMaxGeneratedCards = 15;

/// Splits a generation reply into the text to show and the parsed batch (if the
/// model emitted one). The `<cards>` block is stripped so it never shows to the
/// learner. Returns a null batch when there is no valid block or no valid cards.
({String text, GeneratedBatch? batch}) parseCardGenerationReply(String raw) {
  final match = _cardsTag.firstMatch(raw);
  final text = raw.replaceAll(_cardsTag, '').trim();
  if (match == null) return (text: text, batch: null);
  return (text: text, batch: _parseBatch(match.group(1)!));
}

GeneratedBatch? _parseBatch(String json) {
  try {
    final m = jsonDecode(json) as Map<String, dynamic>;
    final rawCards = m['cards'];
    if (rawCards is! List) return null;
    final cards = <GeneratedCard>[];
    for (final raw in rawCards) {
      final card = _parseCard(raw);
      if (card != null) cards.add(card);
      if (cards.length >= kMaxGeneratedCards) break; // cap the batch
    }
    if (cards.isEmpty) return null;
    final name = (m['name'] as String?)?.trim();
    return GeneratedBatch(
      name: (name == null || name.isEmpty) ? 'Generated cards' : name,
      cards: cards,
    );
  } catch (_) {
    return null;
  }
}

/// Maps one card entry defensively: skips a card with no title or no valid
/// section, coerces tags to `List<String>`, and drops sections missing a heading
/// or content.
GeneratedCard? _parseCard(Object? raw) {
  if (raw is! Map) return null;
  final title = (raw['title'] as String?)?.trim();
  if (title == null || title.isEmpty) return null;
  final sections = <({String heading, String content})>[];
  final rawSections = raw['sections'];
  if (rawSections is List) {
    for (final s in rawSections) {
      if (s is! Map) continue;
      final heading = (s['heading'] as String?)?.trim();
      final content = (s['content'] as String?)?.trim();
      if (heading == null || heading.isEmpty) continue;
      if (content == null || content.isEmpty) continue;
      sections.add((heading: heading, content: content));
    }
  }
  if (sections.isEmpty) return null;
  return GeneratedCard(
      title: title, tags: _strings(raw['tags']), sections: sections);
}

List<String> _strings(Object? v) {
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ];
}

String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
