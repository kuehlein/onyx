import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/story_coach.dart';

void main() {
  group('buildStoryCoachSystem', () {
    test('names gaps, steers to them, and specifies the draft tag', () {
      final s = buildStoryCoachSystem(
        have: ['ownership'],
        gaps: ['conflict', 'failure'],
        level: 'Staff',
      );
      expect(s, contains('Conflict & Backbone')); // gap named via label
      expect(s, contains('STILL NEEDS'));
      expect(s, contains('<story>')); // draft tag documented
      expect(s, contains('never score')); // capture, not a graded mock
    });
  });

  group('parseStoryReply', () {
    test('extracts a draft, strips the tag, filters competencies', () {
      final r = parseStoryReply(
        'Nice — that sounds like a strong one.\n'
        '<story>{"title":"The Kafka migration","competencies":["conflict","bogus"],'
        '"situation":"paging nightly","task":"own it","action":"I drove it",'
        '"result":"cut pages 80%","learning":"stage sooner"}</story>',
      );
      expect(r.text, 'Nice — that sounds like a strong one.');
      expect(r.text, isNot(contains('<story>')));
      final d = r.draft!;
      expect(d.title, 'The Kafka migration');
      expect(d.competencies, ['conflict']); // 'bogus' filtered out
      expect(d.action, 'I drove it');
      expect(d.hasQuantifiedResult, isTrue);
      expect(d.isUsable, isTrue);
    });

    test('no tag → no draft; malformed json → no draft', () {
      expect(parseStoryReply('just chatting').draft, isNull);
      expect(parseStoryReply('<story>{not json}</story>').draft, isNull);
    });

    test('a draft without S/A/R is not usable', () {
      final d = parseStoryReply(
        '<story>{"title":"Half","situation":"x"}</story>',
      ).draft!;
      expect(d.isUsable, isFalse);
    });
  });
}
