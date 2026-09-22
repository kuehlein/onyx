import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/template/builtin_templates.dart';
import 'package:onyx/core/template/neutral_template.dart';
import 'package:onyx/core/template/software_interviews.dart';

/// G7f: built-in templates are resolvable by id, so a config-less folder can
/// default to the neutral subject while a SWE vault opts back in with a one-line
/// `id: software-interviews` — the built-in reference returned verbatim (the
/// golden that guards the default-subject flip).
void main() {
  group('resolveDeckTemplate — built-in opt-in by id', () {
    test('one-line `id: software-interviews` returns the built-in SWE config',
        () {
      expect(resolveDeckTemplate('id: software-interviews'),
          same(softwareInterviewsTemplate));
      // Extra fields are ignored for a built-in (app-owned) id.
      expect(resolveDeckTemplate('id: software-interviews\nfoo: bar'),
          same(softwareInterviewsTemplate));
    });

    test('`id: general` returns the neutral built-in', () {
      expect(resolveDeckTemplate('id: general'), same(neutralTemplate));
    });

    test('a non-built-in id is parsed as a full custom config', () {
      final cfg = resolveDeckTemplate('''
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
      expect(resolveDeckTemplate('not a map'), isNull);
      expect(resolveDeckTemplate('id: my-lang'), isNull); // no target → throws
    });
  });

  test('the neutral built-in is subject-agnostic', () {
    expect(neutralTemplate.id, 'general');
    expect(neutralTemplate.vocabulary.hasAssessment, isFalse);
    expect(neutralTemplate.flows.single.cardType, 'flashcard');
  });
}
