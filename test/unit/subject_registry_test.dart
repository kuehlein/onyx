import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/subject_config.dart';
import 'package:onyx/core/subject/subject_registry.dart';

const _target = TargetSpec(
  levels: [
    LevelValue(id: 'l', label: 'L', tierCurve: [1.0])
  ],
  contexts: [ContextValue(id: 'c', label: 'C', stabilityTargetDays: 30)],
  tracks: [TrackValue(id: 't', label: 'T')],
  families: [],
  fallbackLevelId: 'l',
  fallbackContextId: 'c',
  fallbackTrackId: 't',
);

SubjectConfig _cfg(String id) => SubjectConfig(id: id, target: _target);

void main() {
  group('subjectRootDir', () {
    test('maps config paths to their subtree root', () {
      expect(subjectRootDir('_meta/onyx-subject.yaml'), '');
      expect(subjectRootDir('onyx-subject.yaml'), '');
      expect(subjectRootDir('korean/onyx-subject.yaml'), 'korean');
      expect(subjectRootDir('korean/_meta/onyx-subject.yaml'), 'korean');
      expect(subjectRootDir('langs/korean/onyx-subject.yaml'), 'langs/korean');
    });
  });

  group('SubjectRegistry.single', () {
    test('is a one-entry whole-vault registry', () {
      final r = SubjectRegistry.single(_cfg('swe'));
      expect(r.isSingle, isTrue);
      expect(r.primary.id, 'swe');
      expect(r.subjectForPath('anything/at/all.md').id, 'swe');
      expect(r.subjectIdForPath('x.md'), 'swe');
    });
  });

  group('SubjectRegistry.fromConfigs', () {
    test('empty discovery falls back to the built-in subject', () {
      final r = SubjectRegistry.fromConfigs(const [], fallback: _cfg('swe'));
      expect(r.isSingle, isTrue);
      expect(r.primary.id, 'swe');
    });

    test('single root config collapses to the single-subject case', () {
      final r = SubjectRegistry.fromConfigs(
        [('_meta/onyx-subject.yaml', _cfg('korean'))],
        fallback: _cfg('swe'),
      );
      expect(r.isSingle, isTrue);
      expect(r.primary.id, 'korean');
      expect(r.subjectForPath('word-hello.md').id, 'korean');
    });

    test('resolves each card to its nearest-ancestor subject', () {
      final r = SubjectRegistry.fromConfigs(
        [
          ('_meta/onyx-subject.yaml', _cfg('root')),
          ('korean/onyx-subject.yaml', _cfg('korean')),
          ('cs/onyx-subject.yaml', _cfg('cs')),
        ],
        fallback: _cfg('swe'),
      );
      expect(
          r.subjects.map((s) => s.id), containsAll(['root', 'korean', 'cs']));
      expect(r.isSingle, isFalse);
      // Nearest-ancestor by longest matching root.
      expect(r.subjectForPath('korean/word-hello.md').id, 'korean');
      expect(r.subjectForPath('cs/deck/two-sum.md').id, 'cs');
      // Under no subtree → the whole-vault (root) subject is primary.
      expect(r.subjectForPath('misc/stray.md').id, 'root');
      expect(r.primary.id, 'root');
      expect(r.byId('cs')?.id, 'cs');
      expect(r.byId('nope'), isNull);
    });

    test('deeper subtree wins over a shallower one', () {
      final r = SubjectRegistry.fromConfigs(
        [
          ('langs/onyx-subject.yaml', _cfg('langs')),
          ('langs/korean/onyx-subject.yaml', _cfg('korean')),
        ],
        fallback: _cfg('swe'),
      );
      expect(r.subjectForPath('langs/korean/hi.md').id, 'korean');
      expect(r.subjectForPath('langs/spanish/hola.md').id, 'langs');
      // No root subject → first discovered is primary.
      expect(r.primary.id, 'langs');
    });
  });
}
