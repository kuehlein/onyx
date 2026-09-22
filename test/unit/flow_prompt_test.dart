import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/template/flow_prompt.dart';

void main() {
  group('assembleFlowPrompt', () {
    test('composes skill + problem; no frontier → no constraint', () {
      final p = assembleFlowPrompt(
        skill: 'You are a waiter at a Spanish restaurant.',
        problem: 'The learner wants to order lunch.',
      );
      expect(p, contains('You are a waiter'));
      expect(p, contains('# Problem'));
      expect(p, contains('order lunch'));
      expect(p, isNot(contains('Constraint:')));
    });

    test('injects the covered-knowledge frontier as a hard constraint', () {
      final p = assembleFlowPrompt(
        skill: 'You are a waiter.',
        problem: 'Order food.',
        frontier: {'food-nouns', 'greetings', 'present-tense'},
      );
      expect(p, contains('Constraint: use ONLY'));
      // Deterministic, sorted list so the prompt is stable.
      expect(p, contains('food-nouns, greetings, present-tense'));
    });

    test('includes a level note when given', () {
      final p = assembleFlowPrompt(
        skill: 'skill',
        problem: 'prob',
        levelNote: 'Keep it to A1 vocabulary.',
      );
      expect(p, contains('Keep it to A1 vocabulary.'));
    });
  });

  group('coveredConceptsInstruction', () {
    test('sorts the concepts for a stable prompt', () {
      expect(coveredConceptsInstruction({'c', 'a', 'b'}), contains('a, b, c'));
    });
  });

  group('loadFlowSkill', () {
    test('null / empty path → null (fall back to in-code builder)', () async {
      expect(await loadFlowSkill((_) async => 'x', null), isNull);
      expect(await loadFlowSkill((_) async => 'x', '  '), isNull);
    });

    test('reads via the injected reader', () async {
      final read = await loadFlowSkill(
          (path) async => path == 'skills/waiter.md' ? 'the skill' : null,
          'skills/waiter.md');
      expect(read, 'the skill');
    });

    test('missing file / throw / blank → null', () async {
      expect(await loadFlowSkill((_) async => null, 'skills/x.md'), isNull);
      expect(await loadFlowSkill((_) async => '   ', 'skills/x.md'), isNull);
      expect(
          await loadFlowSkill(
              (_) async => throw Exception('io'), 'skills/x.md'),
          isNull);
    });
  });
}
