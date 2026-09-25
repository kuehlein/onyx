import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/query/card_query.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/shared/models/card.dart';

/// The `CardQuery` IR (ADR-0013) is the lens over the vault that decides which
/// cards a deck studies — and every readiness denominator downstream. A wrong
/// `startsWith` or a bad `fromJson` fallback silently changes the study set, so
/// these pin the pure selector logic directly. Cards are built through the real
/// [CardParser] so `tags`/`filePath` are exactly what the app sees. (This is the
/// former `membership_query_test`, moved onto the folded-in IR in G1.)

const _parser = CardParser();

Card _card({List<String> tags = const [], String path = 'note.md'}) {
  final tagLine = tags.isEmpty ? '[]' : '[${tags.join(', ')}]';
  final md =
      '---\nid: x\ntype: flashcard\ntags: $tagLine\n---\n\n# T\n\n## S\n\nbody\n';
  return _parser.parse(md, filePath: path)!;
}

void main() {
  group('TagIs', () {
    test('matches a card carrying the tag, ignoring case and a leading #', () {
      final q = TagIs('#DS-A');
      expect(q.tag, 'ds-a', reason: 'normalized: lowercased, no leading #');
      expect(q.matches(_card(tags: ['ds-a'])), isTrue);
      expect(q.matches(_card(tags: ['DS-A'])), isTrue);
      expect(q.matches(_card(tags: ['networking', 'ds-a'])), isTrue);
      expect(q.matches(_card(tags: ['system-design'])), isFalse);
      expect(q.matches(_card()), isFalse, reason: 'untagged never matches');
    });
  });

  group('FolderUnder', () {
    test('matches the subtree and an exact file, but NOT a sibling prefix', () {
      final q = FolderUnder('ds-a');
      expect(q.matches(_card(path: 'ds-a/trees.md')), isTrue, reason: 'child');
      expect(q.matches(_card(path: 'ds-a/graphs/dfs.md')), isTrue,
          reason: 'deep child');
      // The crux: 'ds-a-extra' starts with 'ds-a' as a STRING but is a sibling
      // folder — it must not match (guards startsWith('$path/'), not path).
      expect(q.matches(_card(path: 'ds-a-extra/x.md')), isFalse,
          reason: 'sibling prefix must not match');
      expect(q.matches(_card(path: 'system-design/x.md')), isFalse);
    });

    test('an exact file path matches itself', () {
      final q = FolderUnder('ds-a/trees.md');
      expect(q.matches(_card(path: 'ds-a/trees.md')), isTrue);
      expect(q.matches(_card(path: 'ds-a/graphs.md')), isFalse);
    });

    test('trailing slashes are trimmed from the path', () {
      expect(FolderUnder('ds-a/').path, 'ds-a');
      expect(FolderUnder('ds-a///').path, 'ds-a');
    });

    test('an empty path matches everything (whole vault)', () {
      final q = FolderUnder('');
      expect(q.matches(_card(path: 'anything/deep/here.md')), isTrue);
      expect(q.matches(_card(path: 'root.md')), isTrue);
    });
  });

  group('Everything', () {
    test('matches every card', () {
      const q = Everything();
      expect(q.matches(_card()), isTrue);
      expect(q.matches(_card(tags: ['x'], path: 'a/b.md')), isTrue);
    });
  });

  group('fromJson', () {
    test('round-trips tag / folder / all', () {
      final tag = CardQuery.fromJson({'kind': 'tag', 'value': 'ds-a'});
      expect(tag, isA<TagIs>());
      expect((tag as TagIs).tag, 'ds-a');

      final folder = CardQuery.fromJson({'kind': 'folder', 'value': 'a/b'});
      expect(folder, isA<FolderUnder>());
      expect((folder as FolderUnder).path, 'a/b');

      expect(CardQuery.fromJson({'kind': 'all'}), isA<Everything>());
    });

    test(
        'unknown/malformed kind falls back to Everything (never selects nothing)',
        () {
      expect(CardQuery.fromJson({'kind': 'bogus'}), isA<Everything>());
      expect(CardQuery.fromJson(const {}), isA<Everything>());
      // A missing value coerces to '' rather than throwing.
      expect(CardQuery.fromJson({'kind': 'tag'}), isA<TagIs>());
      expect(CardQuery.fromJson({'kind': 'folder'}), isA<FolderUnder>());
    });

    test('toJson/fromJson is stable across a round-trip', () {
      for (final q in [
        const Everything(),
        TagIs('ds-a'),
        FolderUnder('a/b'),
      ]) {
        expect(CardQuery.fromJson(q.toJson()).toJson(), q.toJson());
      }
    });

    test('writes the LEGACY JSON shape (existing decks unchanged on re-save)',
        () {
      // The three folded-in kinds serialize byte-for-byte as before the G1 fold,
      // so a saved deck's `_meta` JSON doesn't churn when Onyx rewrites it.
      expect(const Everything().toJson(), {'kind': 'all'});
      expect(TagIs('#DS-A').toJson(), {'kind': 'tag', 'value': 'ds-a'});
      expect(FolderUnder('a/b/').toJson(), {'kind': 'folder', 'value': 'a/b'});
    });
  });
}
