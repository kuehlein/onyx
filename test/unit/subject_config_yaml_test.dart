import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/subject_config.dart';
import 'package:onyx/core/subject/subject_config_yaml.dart';

/// A tiny non-SWE subject (language learning) expressed purely as config — proves
/// the vault YAML loader (#30 Phase 5) builds a working SubjectConfig with values
/// that have nothing to do with SWE.
const _demoYaml = '''
id: demo-lang
target:
  levels:
    - {id: a1, label: A1, tierCurve: [1.0, 0.6, 0.3]}
    - {id: b1, label: B1, tierCurve: [1.0, 0.9, 0.6]}
  contexts:
    - {id: casual, label: Casual, stabilityTargetDays: 60}
    - {id: exam, label: DELE exam, stabilityTargetDays: 120}
  tracks:
    - {id: speaking, label: Speaking, familyWeights: {grammar: 1.3}}
    - {id: reading, label: Reading}
  families:
    - {id: grammar, exact: [grammar, syntax], contains: [conjugation]}
  fallback: {level: b1, context: exam, track: speaking}
flows:
  - {cardType: flashcard, scheduling: recall, quizzability: blocklist}
  - {cardType: conversation, scheduling: mock, quizzability: noSections, weightDomain: grammar, attemptSource: convo}
''';

void main() {
  group('subjectConfigFromYaml', () {
    final cfg = subjectConfigFromYaml(_demoYaml);
    final t = cfg.target;

    test('parses id + slot values', () {
      expect(cfg.id, 'demo-lang');
      expect(t.levels.map((l) => l.id), ['a1', 'b1']);
      expect(t.contexts.map((c) => c.label), ['Casual', 'DELE exam']);
      expect(t.tracks.map((tr) => tr.id), ['speaking', 'reading']);
    });

    test('target math resolves from the parsed config', () {
      // context → durability bar
      expect(t.stabilityTargetDays('casual'), 60);
      expect(t.stabilityTargetDays('exam'), 120);
      // level → tier curve (b1: [1.0, 0.9, 0.6]; tier 3+ clamps to 0.6)
      expect(t.tierRelevance('b1', 1), 1.0);
      expect(t.tierRelevance('b1', 2), 0.9);
      expect(t.tierRelevance('b1', 5), 0.6);
      expect(t.tierRelevance('a1', 2), 0.6);
      // track → domain weight via family (grammar exact + 'conjugation' substring)
      expect(t.domainWeight('speaking', 'grammar'), 1.3);
      expect(t.domainWeight('speaking', 'verb-conjugation'), 1.3);
      expect(
          t.domainWeight('reading', 'grammar'), 1.0); // reading lists no weight
      expect(t.domainWeight('speaking', 'vocabulary'), 1.0); // unmatched
    });

    test('fallback + flows parse', () {
      expect(t.fallbackLevelId, 'b1');
      expect(t.fallbackContextId, 'exam');
      expect(t.fallbackTrackId, 'speaking');
      expect(cfg.flowForType('flashcard')?.quizzability,
          QuizzabilityPolicy.blocklist);
      expect(cfg.flowForType('conversation')?.scheduling, SchedulingModel.mock);
    });

    test('flow weightDomain/attemptSource parse (null when absent)', () {
      final convo = cfg.flowForType('conversation');
      expect(convo?.weightDomain, 'grammar');
      expect(convo?.attemptSource, 'convo');
      // The flashcard flow declares neither → both null.
      final flash = cfg.flowForType('flashcard');
      expect(flash?.weightDomain, isNull);
      expect(flash?.attemptSource, isNull);
    });

    test('missing label falls back to id', () {
      final c = subjectConfigFromYaml('''
id: x
target:
  levels: [{id: only}]
  contexts: [{id: c}]
  tracks: [{id: tr}]
''');
      expect(c.target.levels.single.label, 'only');
    });

    test('empty/missing tierCurve becomes the default (no later crash)', () {
      // An empty curve used to parse fine then crash in tierRelevance(curve.first).
      final c = subjectConfigFromYaml('''
id: x
target:
  levels: [{id: only, tierCurve: []}]
  contexts: [{id: c}]
  tracks: [{id: tr}]
''');
      expect(c.target.tierRelevance('only', 1), 1.0);
      expect(c.target.tierRelevance('only', 5), 1.0);
    });

    test('malformed / incomplete config throws (loader then defaults)', () {
      expect(() => subjectConfigFromYaml('not a map'), throwsFormatException);
      expect(() => subjectConfigFromYaml('id: x'), throwsFormatException);
      expect(
        () => subjectConfigFromYaml(
            'id: x\ntarget: {levels: [], contexts: [{id: c}], tracks: [{id: t}]}'),
        throwsFormatException,
      );
    });
  });

  group('vocabulary + parse profile (G3/G4)', () {
    test('absent blocks → neutral vocabulary + standard parse profile', () {
      final cfg = subjectConfigFromYaml(_demoYaml);
      expect(cfg.vocabulary, same(Vocabulary.neutral));
      expect(cfg.parseProfile, same(ParseProfile.standard));
    });

    test('declared vocabulary + parse block parse into the config', () {
      final cfg = subjectConfigFromYaml('''
id: x
target:
  levels: [{id: only}]
  contexts: [{id: c}]
  tracks: [{id: tr}]
vocabulary: {examinerNoun: proctor}
domainLabels: {grammar: Grammar & syntax, verbs: Verb forms}
parse:
  sectionHeadingLevel: 3
  fileExtensions: ['.md', TXT]
  wikilinks: false
  neverQuizzed: [Related, References]
''');
      expect(cfg.vocabulary.examinerNoun, 'proctor');
      expect(cfg.domainLabels,
          {'grammar': 'Grammar & syntax', 'verbs': 'Verb forms'});
      final p = cfg.parseProfile;
      expect(p.sectionHeadingLevel, 3);
      expect(p.fileExtensions, {'md', 'txt'}); // dot stripped, lowercased
      expect(p.wikilinks, isFalse);
      expect(p.neverQuizzed, {'related', 'references'}); // lowercased
    });

    test('out-of-range level + empty extensions fall back to defaults', () {
      final cfg = subjectConfigFromYaml('''
id: x
target:
  levels: [{id: only}]
  contexts: [{id: c}]
  tracks: [{id: tr}]
parse: {sectionHeadingLevel: 9, fileExtensions: []}
''');
      final p = cfg.parseProfile;
      expect(p.sectionHeadingLevel, 2); // 9 out of range → default
      expect(p.fileExtensions, {'md'}); // empty → default
      expect(p.wikilinks, isTrue); // absent → default
      expect(p.neverQuizzed, isNull); // absent → engine's built-in blocklist
    });
  });
}
