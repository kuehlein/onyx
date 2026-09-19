import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/card_generation.dart';

void main() {
  group('buildCardGenerationSystem', () {
    final prompt = buildCardGenerationSystem(today: DateTime(2026, 9, 19));

    test('bakes in the key card-authoring rules', () {
      // Atomicity / one coherent idea per section, answerable from its cue.
      expect(prompt, contains('One coherent idea per section'));
      // Lead with the rule/principle, not rote facts.
      expect(prompt.toLowerCase(), contains('principle'));
      // Interference / disambiguate siblings with an explicit "vs X" contrast.
      expect(prompt.toLowerCase(), contains('interference'));
      expect(prompt, contains('vs X'));
      // Conditional "when to use" / recognition triggers framing.
      expect(prompt.toLowerCase(), contains('recognition triggers'));
      // Active recall, not declarative walls.
      expect(prompt.toLowerCase(), contains('active recall'));
      // Don't make an unordered enumeration the recall target.
      expect(prompt.toLowerCase(), contains('list all'));
    });

    test('states the <cards> tagged-JSON output format', () {
      expect(prompt, contains('<cards>'));
      expect(prompt, contains('</cards>'));
      expect(prompt, contains('"name"'));
      expect(prompt, contains('"cards"'));
      expect(prompt, contains('"title"'));
      expect(prompt, contains('"sections"'));
      expect(prompt, contains('"heading"'));
      expect(prompt, contains('"content"'));
    });

    test('gives the small-batch count guidance (8–12, cap 15)', () {
      expect(prompt, contains('8 to 12'));
      expect(prompt, contains('15'));
      expect(prompt, contains('1 to 3 sections'));
    });

    test('includes today for dated content', () {
      expect(prompt, contains('2026-09-19'));
    });

    test('prefers fewer, well-formed cards over many shallow ones (rule 8)',
        () {
      expect(prompt, contains('a few excellent cards over many shallow ones'));
    });
  });

  group('parseCardGenerationReply', () {
    const reply = '12 cards on TCP fundamentals.\n'
        '<cards>{"name":"TCP fundamentals","cards":['
        '{"title":"TCP handshake","tags":["tcp","networking"],"sections":['
        '{"heading":"When to Use","content":"When you need reliable, ordered '
        'delivery."},'
        '{"heading":"vs UDP","content":"TCP is reliable + ordered; UDP is '
        'fire-and-forget."}]},'
        '{"title":"Flow control","tags":["tcp"],"sections":['
        '{"heading":"Key idea","content":"The receiver advertises a window."}]}'
        ']}</cards>';

    test('parses a realistic reply into a batch (name + cards + sections)', () {
      final result = parseCardGenerationReply(reply);
      final batch = result.batch;
      expect(batch, isNotNull);
      expect(batch!.name, 'TCP fundamentals');
      expect(batch.cards.length, 2);

      final first = batch.cards.first;
      expect(first.title, 'TCP handshake');
      expect(first.tags, ['tcp', 'networking']);
      expect(first.sections.length, 2);
      expect(first.sections.first.heading, 'When to Use');
      expect(first.sections.first.content,
          'When you need reliable, ordered delivery.');
      expect(first.sections[1].heading, 'vs UDP');

      final second = batch.cards[1];
      expect(second.title, 'Flow control');
      expect(second.sections.single.heading, 'Key idea');
    });

    test('strips the <cards> block from the shown text', () {
      final result = parseCardGenerationReply(reply);
      expect(result.text, '12 cards on TCP fundamentals.');
      expect(result.text.contains('<cards>'), isFalse);
    });

    test('no block → null batch, text preserved', () {
      final result = parseCardGenerationReply('I need more detail first.');
      expect(result.batch, isNull);
      expect(result.text, 'I need more detail first.');
    });

    test('malformed JSON → null batch', () {
      final result =
          parseCardGenerationReply('<cards>{"name": "x", cards: oops}</cards>');
      expect(result.batch, isNull);
    });

    test('skips a card missing a title or missing sections', () {
      const r = '<cards>{"cards":['
          '{"tags":["x"],"sections":[{"heading":"H","content":"C"}]},' // no title
          '{"title":"No sections","tags":["x"],"sections":[]},' // empty sections
          '{"title":"Good","sections":[{"heading":"H","content":"C"}]}' // ok
          ']}</cards>';
      final batch = parseCardGenerationReply(r).batch;
      expect(batch, isNotNull);
      expect(batch!.cards.length, 1);
      expect(batch.cards.single.title, 'Good');
    });

    test('drops sections missing a heading or content', () {
      const r = '<cards>{"cards":[{"title":"T","sections":['
          '{"content":"no heading"},'
          '{"heading":"no content"},'
          '{"heading":"H","content":"C"}]}]}</cards>';
      final batch = parseCardGenerationReply(r).batch;
      expect(batch!.cards.single.sections.length, 1);
      expect(batch.cards.single.sections.single.heading, 'H');
    });

    test('coerces missing/absent tags to an empty list', () {
      const r = '<cards>{"cards":[{"title":"T","sections":'
          '[{"heading":"H","content":"C"}]}]}</cards>';
      final batch = parseCardGenerationReply(r).batch;
      expect(batch!.cards.single.tags, isEmpty);
    });

    test('falls back to a default name when missing/empty', () {
      const r = '<cards>{"cards":[{"title":"T","sections":'
          '[{"heading":"H","content":"C"}]}]}</cards>';
      final batch = parseCardGenerationReply(r).batch;
      expect(batch!.name, 'Generated cards');
    });

    test('caps the batch at 15 cards even if the model returns more', () {
      final many = [
        for (var i = 0; i < 30; i++)
          '{"title":"Card $i","sections":[{"heading":"H","content":"C"}]}',
      ].join(',');
      final batch =
          parseCardGenerationReply('<cards>{"cards":[$many]}</cards>').batch;
      expect(batch, isNotNull);
      expect(batch!.cards.length, kMaxGeneratedCards);
      expect(batch.cards.length, 15);
    });

    test('all-invalid cards → null batch', () {
      const r = '<cards>{"cards":[{"tags":["x"]},{"title":""}]}</cards>';
      expect(parseCardGenerationReply(r).batch, isNull);
    });
  });
}
