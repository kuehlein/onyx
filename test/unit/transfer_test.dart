import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/interview/transfer.dart';

void main() {
  group('computeTransfer', () {
    test('no evidence → sits at the pessimistic prior with a wide band', () {
      final t = computeTransfer(const []);
      expect(t.value, closeTo(transferPriorMean, 1e-9));
      expect(t.effectiveN, 0);
      expect(t.high - t.low, greaterThan(0.4)); // honestly wide
      expect(t.hasEvidence, isFalse);
    });

    test('one strong attempt is heavily shrunk toward the prior', () {
      final t = computeTransfer([
        const AppliedSample(score: 1.0, novel: true, ageDays: 0),
      ]);
      // Between the prior and 1.0, but nowhere near 1.0 (k=3 pseudo-attempts).
      expect(t.value, greaterThan(transferPriorMean));
      expect(t.value, lessThan(0.7));
    });

    test(
        'many strong recent novel attempts move well above the prior '
        'and tighten the band', () {
      final many = [
        for (var i = 0; i < 12; i++)
          const AppliedSample(score: 0.9, novel: true, ageDays: 0),
      ];
      final t = computeTransfer(many);
      expect(t.value, greaterThan(0.75));
      final one = computeTransfer(
          [const AppliedSample(score: 0.9, novel: true, ageDays: 0)]);
      expect(t.high - t.low, lessThan(one.high - one.low)); // narrows with n
      expect(t.effectiveN, closeTo(12, 1e-6));
    });

    test('novel attempts carry more weight than routine ones', () {
      final novel = computeTransfer(
          [const AppliedSample(score: 0.8, novel: true, ageDays: 0)]);
      final routine = computeTransfer(
          [const AppliedSample(score: 0.8, novel: false, ageDays: 0)]);
      expect(novel.effectiveN, greaterThan(routine.effectiveN));
      // More evidence → moves further from the prior.
      expect(novel.value, greaterThan(routine.value));
    });

    test('recency decays old attempts', () {
      final fresh = computeTransfer(
          [const AppliedSample(score: 0.9, novel: true, ageDays: 0)]);
      final old = computeTransfer([
        const AppliedSample(
            score: 0.9, novel: true, ageDays: transferHalfLifeDays * 3),
      ]);
      expect(old.effectiveN, lessThan(fresh.effectiveN));
      expect(old.value, lessThan(fresh.value)); // decayed toward the prior
    });

    test('a poor applied record pulls below the prior', () {
      final t = computeTransfer([
        for (var i = 0; i < 8; i++)
          const AppliedSample(score: 0.1, novel: true, ageDays: 0),
      ]);
      expect(t.value, lessThan(transferPriorMean));
    });
  });
}
