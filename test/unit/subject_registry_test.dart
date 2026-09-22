import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/template/deck_template.dart';
import 'package:onyx/core/template/template_registry.dart';

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

DeckTemplate _cfg(String id) => DeckTemplate(id: id, target: _target);

void main() {
  group('templateRootDir', () {
    test('maps config paths to their subtree root', () {
      expect(templateRootDir('_meta/onyx-subject.yaml'), '');
      expect(templateRootDir('onyx-subject.yaml'), '');
      expect(templateRootDir('korean/onyx-subject.yaml'), 'korean');
      expect(templateRootDir('korean/_meta/onyx-subject.yaml'), 'korean');
      expect(templateRootDir('langs/korean/onyx-subject.yaml'), 'langs/korean');
    });
  });

  group('TemplateRegistry.single', () {
    test('is a one-entry whole-vault registry', () {
      final r = TemplateRegistry.single(_cfg('swe'));
      expect(r.isSingle, isTrue);
      expect(r.primary.id, 'swe');
      expect(r.templateForPath('anything/at/all.md').id, 'swe');
      expect(r.templateIdForPath('x.md'), 'swe');
    });
  });

  group('TemplateRegistry.fromConfigs', () {
    test('empty discovery falls back to the built-in subject', () {
      final r = TemplateRegistry.fromConfigs(const [], fallback: _cfg('swe'));
      expect(r.isSingle, isTrue);
      expect(r.primary.id, 'swe');
    });

    test('single root config collapses to the single-subject case', () {
      final r = TemplateRegistry.fromConfigs(
        [('_meta/onyx-subject.yaml', _cfg('korean'))],
        fallback: _cfg('swe'),
      );
      expect(r.isSingle, isTrue);
      expect(r.primary.id, 'korean');
      expect(r.templateForPath('word-hello.md').id, 'korean');
    });

    test('resolves each card to its nearest-ancestor subject', () {
      final r = TemplateRegistry.fromConfigs(
        [
          ('_meta/onyx-subject.yaml', _cfg('root')),
          ('korean/onyx-subject.yaml', _cfg('korean')),
          ('cs/onyx-subject.yaml', _cfg('cs')),
        ],
        fallback: _cfg('swe'),
      );
      expect(
          r.templates.map((s) => s.id), containsAll(['root', 'korean', 'cs']));
      expect(r.isSingle, isFalse);
      // Nearest-ancestor by longest matching root.
      expect(r.templateForPath('korean/word-hello.md').id, 'korean');
      expect(r.templateForPath('cs/deck/two-sum.md').id, 'cs');
      // Under no subtree → the whole-vault (root) subject is primary.
      expect(r.templateForPath('misc/stray.md').id, 'root');
      expect(r.primary.id, 'root');
      expect(r.byId('cs')?.id, 'cs');
      expect(r.byId('nope'), isNull);
    });

    test('duplicate ids are deduped (first by path wins)', () {
      final r = TemplateRegistry.fromConfigs(
        [
          ('cs/onyx-subject.yaml', _cfg('dup')),
          ('korean/onyx-subject.yaml', _cfg('dup')),
        ],
        fallback: _cfg('swe'),
      );
      // Only one entry survives, so path- and id-resolution can't disagree.
      expect(r.entries.length, 1);
      expect(r.templates.map((s) => s.id), ['dup']);
      expect(r.byId('dup')?.id, 'dup');
      // The second (deduped) subtree no longer resolves to a distinct config.
      expect(r.templateForPath('cs/x.md').id, 'dup');
    });

    test('deeper subtree wins over a shallower one', () {
      final r = TemplateRegistry.fromConfigs(
        [
          ('langs/onyx-subject.yaml', _cfg('langs')),
          ('langs/korean/onyx-subject.yaml', _cfg('korean')),
        ],
        fallback: _cfg('swe'),
      );
      expect(r.templateForPath('langs/korean/hi.md').id, 'korean');
      expect(r.templateForPath('langs/spanish/hola.md').id, 'langs');
      // No root subject → first discovered is primary.
      expect(r.primary.id, 'langs');
    });
  });
}
