import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/practice/mock_grader.dart';

void main() {
  const dims = {'communication', 'approach'};

  group('parseMockGrade', () {
    test('parses a tagged grade and filters/clamps rubric to dimensions', () {
      final g = parseMockGrade(
        'noise <grade>{"appliedScore": 73, "rubric": '
        '{"communication": 4, "approach": 9, "bogus": 5}, '
        '"note": "solid"}</grade> trailing',
        dimensions: dims,
      )!;
      expect(g.appliedScore, 73);
      expect(g.rubric['communication'], 4);
      expect(g.rubric['approach'], 5); // clamped 9 → 5
      expect(g.rubric.containsKey('bogus'), isFalse); // filtered out
      expect(g.note, 'solid');
    });

    test('accepts a bare JSON object as a fallback', () {
      final g = parseMockGrade('{"appliedScore": 40}', dimensions: dims)!;
      expect(g.appliedScore, 40);
    });

    test('clamps appliedScore and returns null when unparseable / no score',
        () {
      expect(
          parseMockGrade('{"appliedScore": 250}', dimensions: dims)!
              .appliedScore,
          100);
      expect(parseMockGrade('no json here', dimensions: dims), isNull);
      expect(parseMockGrade('{"rubric": {}}', dimensions: dims), isNull);
    });
  });

  group('reconcile', () {
    MockGrade g(int s) => MockGrade(appliedScore: s);

    test('reconcilePanel01 is the median, normalized 0..1', () {
      expect(reconcilePanel01([g(40), g(60), g(80)]), closeTo(0.60, 1e-9));
      expect(
          reconcilePanel01([g(40), g(80)]), closeTo(0.60, 1e-9)); // even → avg
      expect(reconcilePanel01([]), isNull);
    });

    test('reconcilePanel returns the median grade with the reconciled score',
        () {
      final r = reconcilePanel([
        const MockGrade(appliedScore: 30, note: 'low'),
        const MockGrade(appliedScore: 60, note: 'mid'),
        const MockGrade(appliedScore: 90, note: 'high'),
      ])!;
      expect(r.score01, closeTo(0.60, 1e-9));
      expect(r.grade.appliedScore, 60);
      expect(r.grade.note, 'mid'); // median grader's note carried
    });
  });
}
