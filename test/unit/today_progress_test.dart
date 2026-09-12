import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/providers/today_progress.dart';

void main() {
  test('fraction/percent, allDone and nothingScheduled', () {
    // 20 done of 80 total → 25% (the "half of a half-day flow" case).
    const partial = TodayProgress(doneMinutes: 20, remainingMinutes: 60);
    expect(partial.fraction, closeTo(0.25, 1e-9));
    expect(partial.percent, 25);
    expect(partial.allDone, isFalse);
    expect(partial.nothingScheduled, isFalse);

    const done = TodayProgress(doneMinutes: 90, remainingMinutes: 0);
    expect(done.allDone, isTrue);
    expect(done.fraction, 1);
    expect(done.percent, 100);

    const empty = TodayProgress(doneMinutes: 0, remainingMinutes: 0);
    expect(empty.nothingScheduled, isTrue);
    expect(empty.allDone, isFalse);
    expect(empty.fraction, 0);
  });
}
