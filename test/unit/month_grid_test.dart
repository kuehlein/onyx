import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/features/home/target_sheet.dart';

// Locks the only date arithmetic in the custom inline calendar. Everything else
// in the widget is layout; this is where a from-scratch calendar could go wrong.
void main() {
  group('monthGrid', () {
    test('days-in-month handles leap years via DateTime', () {
      expect(monthGrid(2026, 2).days, 28); // non-leap
      expect(monthGrid(2028, 2).days, 29); // leap
      expect(monthGrid(2000, 2).days, 29); // century leap
      expect(monthGrid(1900, 2).days, 28); // century non-leap
      expect(monthGrid(2026, 4).days, 30);
      expect(
          monthGrid(2026, 12).days, 31); // December (month+1 rolls to next yr)
    });

    test('leading blanks = the Sunday-first weekday index of day 1', () {
      // Jan 1 2026 is a Thursday (Mon=1..Sun=7 → Thu=4).
      expect(monthGrid(2026, 1).leading, 4);
      // A month starting Sunday → 0 leading blanks. Feb 1 2026 is a Sunday.
      expect(monthGrid(2026, 2).leading, 0);
      // General invariant: leading is always in [0,6] and matches DateTime.
      for (var m = 1; m <= 12; m++) {
        final g = monthGrid(2026, m);
        expect(g.leading, inInclusiveRange(0, 6));
        expect(g.leading, DateTime(2026, m, 1).weekday % 7);
      }
    });

    test('a full grid (leading + days) always fits in whole weeks ≤ 6 rows',
        () {
      for (var y = 2024; y <= 2030; y++) {
        for (var m = 1; m <= 12; m++) {
          final g = monthGrid(y, m);
          final cells = g.leading + g.days;
          expect(cells, lessThanOrEqualTo(42)); // 6 rows × 7
          expect(cells, greaterThanOrEqualTo(28));
        }
      }
    });
  });
}
