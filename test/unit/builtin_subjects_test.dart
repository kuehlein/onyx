import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/builtin_subjects.dart';
import 'package:onyx/core/subject/neutral_subject.dart';
import 'package:onyx/core/subject/software_interviews.dart';

/// G7f: built-in templates are resolvable by id, so a config-less folder can
/// default to the neutral subject while a SWE vault opts back in with a one-line
/// `id: software-interviews` — the built-in reference returned verbatim (the
/// golden that guards the default-subject flip).
void main() {
  group('resolveSubjectConfig — built-in opt-in by id', () {
    test('one-line `id: software-interviews` returns the built-in SWE config',
        () {
      expect(resolveSubjectConfig('id: software-interviews'),
          same(softwareInterviewsConfig));
      // Extra fields are ignored for a built-in (app-owned) id.
      expect(resolveSubjectConfig('id: software-interviews\nfoo: bar'),
          same(softwareInterviewsConfig));
    });

    test('`id: general` returns the neutral built-in', () {
      expect(resolveSubjectConfig('id: general'), same(neutralSubjectConfig));
    });

    test('a non-built-in id is parsed as a full custom config', () {
      final cfg = resolveSubjectConfig('''
id: my-lang
target:
  levels: [{id: a1, label: A1}]
  contexts: [{id: casual, label: Casual}]
  tracks: [{id: speaking, label: Speaking}]
''');
      expect(cfg, isNotNull);
      expect(cfg!.id, 'my-lang');
      expect(cfg.vocabulary.hasAssessment, isFalse); // neutral by default
    });

    test('malformed / incomplete config → null (discovery skips it)', () {
      expect(resolveSubjectConfig('not a map'), isNull);
      expect(resolveSubjectConfig('id: my-lang'), isNull); // no target → throws
    });
  });

  test('the neutral built-in is subject-agnostic', () {
    expect(neutralSubjectConfig.id, 'general');
    expect(neutralSubjectConfig.vocabulary.hasAssessment, isFalse);
    expect(neutralSubjectConfig.flows.single.cardType, 'flashcard');
  });
}
