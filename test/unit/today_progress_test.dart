import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/providers/today_progress.dart';

void main() {
  test('fraction, allDone and nothingScheduled', () {
    const partial = TodayProgress(done: 1, total: 4, minutesLeft: 48);
    expect(partial.fraction, closeTo(0.25, 1e-9));
    expect(partial.allDone, isFalse);
    expect(partial.nothingScheduled, isFalse);

    const done = TodayProgress(done: 3, total: 3, minutesLeft: 0);
    expect(done.allDone, isTrue);
    expect(done.fraction, 1);

    const empty = TodayProgress(done: 0, total: 0, minutesLeft: 0);
    expect(empty.nothingScheduled, isTrue);
    expect(empty.allDone, isFalse); // nothing to do isn't an accomplishment
    expect(empty.fraction, 0);
  });
}
