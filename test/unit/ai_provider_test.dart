import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/ai_provider.dart';

/// Pure resolution of the AI provider seam (ADR-0004).

void main() {
  group('resolveAiProvider', () {
    test('off when there is no key and no managed tier', () {
      expect(resolveAiProvider(hasKey: false), AiProvider.off);
    });

    test('byoKey when the user has their own key', () {
      expect(resolveAiProvider(hasKey: true), AiProvider.byoKey);
    });

    test('managed takes precedence when a managed config is present', () {
      final cfg = ManagedAiConfig(
        baseUrl: Uri.parse('https://ai.onyx.example'),
        token: 't',
      );
      expect(resolveAiProvider(hasKey: true, managed: cfg), AiProvider.managed);
      expect(
          resolveAiProvider(hasKey: false, managed: cfg), AiProvider.managed);
    });
  });
}
