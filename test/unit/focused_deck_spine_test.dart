import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/providers/decks.dart';

/// The one focused-goal spine (ADR-0005). The integration (readiness scopes to the
/// focused lens) lives in readiness_flow_test; here we pin the primitive itself.

void main() {
  group('FocusedDeck spine', () {
    test('defaults to null (the hub altitude); focus + clear round-trip', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(focusedDeckProvider), isNull);

      c.read(focusedDeckProvider.notifier).focus('algorithms');
      expect(c.read(focusedDeckProvider), 'algorithms');

      c.read(focusedDeckProvider.notifier).focus('korean');
      expect(c.read(focusedDeckProvider), 'korean');

      c.read(focusedDeckProvider.notifier).focus(null);
      expect(c.read(focusedDeckProvider), isNull);
    });
  });
}
