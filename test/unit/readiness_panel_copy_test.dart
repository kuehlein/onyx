import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/subject_config.dart';
import 'package:onyx/features/home/readiness_panel.dart';

/// G7d: the readiness panel's assessment copy reads from the goal's [Vocabulary].
/// These lock the SWE strings byte-identically and prove a neutral subject never
/// says "interview".
void main() {
  const swe =
      Vocabulary(examinerNoun: 'interviewer', assessmentNoun: 'interview');
  const neutral = Vocabulary.neutral;

  group('SWE copy is byte-identical to pre-G7', () {
    test('state word', () {
      expect(readinessStateWord(swe, interview: true), 'interview-tested');
      expect(readinessStateWord(swe, interview: false), 'recall only');
    });

    test('ready-status label', () {
      expect(readyStatusLabel(swe), 'Interview-ready');
    });

    test('tooltip — interview-tested branch', () {
      expect(
        readinessTooltip(swe, interview: true),
        'Interview readiness: recall gated by your mock-interview performance. '
        'The band narrows as you do more mocks.',
      );
    });

    test('tooltip — recall-only branch', () {
      expect(
        readinessTooltip(swe, interview: false),
        'Recall readiness. Do mock interviews to prove you can apply it — that '
        'graduates this to interview-tested and narrows the band.',
      );
    });
  });

  group('neutral subject never says "interview"', () {
    test('state word + ready label are applied-framed', () {
      expect(readinessStateWord(neutral, interview: true), 'applied-tested');
      expect(readinessStateWord(neutral, interview: false), 'recall only');
      expect(readyStatusLabel(neutral), 'Applied-ready');
    });

    test('tooltips avoid "interview"', () {
      expect(readinessTooltip(neutral, interview: true).toLowerCase(),
          isNot(contains('interview')));
      expect(readinessTooltip(neutral, interview: false).toLowerCase(),
          isNot(contains('interview')));
    });
  });
}
