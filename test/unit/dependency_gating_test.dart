import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/template/dependency_gating.dart';

void main() {
  // Competence table: a concept's durability (0..1). Unknown → 0.
  const comp = {
    'greetings': 0.9,
    'food-nouns': 0.8,
    'present-tense': 0.4, // below a 0.7 bar
    'numbers': 0.0,
  };
  double competenceOf(String c) => comp[c] ?? 0;

  group('evaluateGate', () {
    test('no dependencies → unlocked', () {
      final g = evaluateGate(
          dependsOn: const [], competenceOf: competenceOf, competenceBar: 0.7);
      expect(g.unlocked, isTrue);
      expect(g.metFraction, 1.0);
      expect(g.hasDeps, isFalse);
    });

    test('all deps clear the bar → unlocked, nothing weak', () {
      final g = evaluateGate(
        dependsOn: const ['greetings', 'food-nouns'],
        competenceOf: competenceOf,
        competenceBar: 0.7,
      );
      expect(g.unlocked, isTrue);
      expect(g.weak, isEmpty);
      expect(g.satisfied, ['greetings', 'food-nouns']);
    });

    test('partial: 2 of 3 met (0.67 ≥ 0.6 fraction) → unlocked, weak listed',
        () {
      final g = evaluateGate(
        dependsOn: const ['greetings', 'food-nouns', 'present-tense'],
        competenceOf: competenceOf,
        competenceBar: 0.7,
      );
      expect(g.metFraction, closeTo(2 / 3, 1e-9));
      expect(g.unlocked, isTrue);
      expect(g.weak, ['present-tense']); // routed back to study
    });

    test('too few met (1 of 3 < 0.6) → locked', () {
      final g = evaluateGate(
        dependsOn: const ['greetings', 'present-tense', 'numbers'],
        competenceOf: competenceOf,
        competenceBar: 0.7,
      );
      expect(g.unlocked, isFalse);
      expect(g.weak, ['present-tense', 'numbers']);
    });

    test('the competence bar is respected (0.8 dep passes 0.8 bar)', () {
      final g = evaluateGate(
        dependsOn: const ['food-nouns'], // 0.8
        competenceOf: competenceOf,
        competenceBar: 0.8,
      );
      expect(g.unlocked, isTrue);
      final g2 = evaluateGate(
        dependsOn: const ['food-nouns'],
        competenceOf: competenceOf,
        competenceBar: 0.81,
      );
      expect(g2.unlocked, isFalse);
    });
  });

  group('coveredFrontier', () {
    test('returns only concepts at/above the bar', () {
      final frontier = coveredFrontier(
        concepts: comp.keys,
        competenceOf: competenceOf,
        competenceBar: 0.7,
      );
      expect(frontier, {'greetings', 'food-nouns'});
    });
  });
}
