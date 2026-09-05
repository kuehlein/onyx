import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/explain_coach.dart';

void main() {
  group('parseExplainReply', () {
    test('strips a recognition tag and returns the suggestion', () {
      final r = parseExplainReply(
          'Good — you nailed the invariant.\n<recognition>solid</recognition>');
      expect(r.text, 'Good — you nailed the invariant.');
      expect(r.suggestion, RecognitionSuggestion.solid);
    });

    test('is case-insensitive and maps shaky/lost', () {
      expect(parseExplainReply('x <RECOGNITION>Shaky</RECOGNITION>').suggestion,
          RecognitionSuggestion.shaky);
      expect(parseExplainReply('<recognition>lost</recognition>').suggestion,
          RecognitionSuggestion.lost);
    });

    test('no tag → null suggestion, text untouched', () {
      final r = parseExplainReply('What signals this pattern?');
      expect(r.suggestion, isNull);
      expect(r.text, 'What signals this pattern?');
    });

    test('an unknown value is ignored (no false suggestion)', () {
      final r = parseExplainReply('ok <recognition>great</recognition>');
      expect(r.suggestion, isNull);
      // Unknown value isn't stripped (regex only matches the known words).
      expect(r.text, contains('great'));
    });
  });
}
