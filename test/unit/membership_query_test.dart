import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/membership_query.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/shared/models/card.dart';

/// A goal's member-selection is the "lens over the vault" that decides which
/// cards a goal studies — and every readiness denominator downstream. A wrong
/// `startsWith` or a bad fromJson fallback silently changes the study set, so
/// these pin the pure selector logic directly. Cards are built through the real
/// [CardParser] so `tags`/`filePath` are exactly what the app sees.

const _parser = CardParser();

Card _card({List<String> tags = const [], String path = 'note.md'}) {
  final tagLine = tags.isEmpty ? '[]' : '[${tags.join(', ')}]';
  final md =
      '---\nid: x\ntype: flashcard\ntags: $tagLine\n---\n\n# T\n\n## S\n\nbody\n';
  return _parser.parse(md, filePath: path)!;
}

void main() {
  group('TagMembership', () {
    test('matches a card carrying the tag, ignoring case and a leading #', () {
      final q = TagMembership('#DS-A');
      expect(q.tag, 'ds-a', reason: 'normalized: lowercased, no leading #');
      expect(q.matches(_card(tags: ['ds-a'])), isTrue);
      expect(q.matches(_card(tags: ['DS-A'])), isTrue);
      expect(q.matches(_card(tags: ['networking', 'ds-a'])), isTrue);
      expect(q.matches(_card(tags: ['system-design'])), isFalse);
      expect(q.matches(_card()), isFalse, reason: 'untagged never matches');
    });
  });

  group('FolderMembership', () {
    test('matches the subtree and an exact file, but NOT a sibling prefix', () {
      final q = FolderMembership('ds-a');
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
      final q = FolderMembership('ds-a/trees.md');
      expect(q.matches(_card(path: 'ds-a/trees.md')), isTrue);
      expect(q.matches(_card(path: 'ds-a/graphs.md')), isFalse);
    });

    test('trailing slashes are trimmed from the path', () {
      expect(FolderMembership('ds-a/').path, 'ds-a');
      expect(FolderMembership('ds-a///').path, 'ds-a');
    });

    test('an empty path matches everything (whole vault)', () {
      final q = FolderMembership('');
      expect(q.matches(_card(path: 'anything/deep/here.md')), isTrue);
      expect(q.matches(_card(path: 'root.md')), isTrue);
    });
  });

  group('AllCards', () {
    test('matches every card', () {
      const q = AllCards();
      expect(q.matches(_card()), isTrue);
      expect(q.matches(_card(tags: ['x'], path: 'a/b.md')), isTrue);
    });
  });

  group('fromJson', () {
    test('round-trips tag / folder / all', () {
      final tag = MembershipQuery.fromJson({'kind': 'tag', 'value': 'ds-a'});
      expect(tag, isA<TagMembership>());
      expect((tag as TagMembership).tag, 'ds-a');

      final folder =
          MembershipQuery.fromJson({'kind': 'folder', 'value': 'a/b'});
      expect(folder, isA<FolderMembership>());
      expect((folder as FolderMembership).path, 'a/b');

      expect(MembershipQuery.fromJson({'kind': 'all'}), isA<AllCards>());
    });

    test(
        'unknown/malformed kind falls back to AllCards (never selects nothing)',
        () {
      expect(MembershipQuery.fromJson({'kind': 'bogus'}), isA<AllCards>());
      expect(MembershipQuery.fromJson(const {}), isA<AllCards>());
      // A missing value coerces to '' rather than throwing.
      expect(MembershipQuery.fromJson({'kind': 'tag'}), isA<TagMembership>());
      expect(MembershipQuery.fromJson({'kind': 'folder'}),
          isA<FolderMembership>());
    });

    test('toJson/fromJson is stable across a round-trip', () {
      for (final q in [
        const AllCards(),
        TagMembership('ds-a'),
        FolderMembership('a/b'),
      ]) {
        expect(MembershipQuery.fromJson(q.toJson()).toJson(), q.toJson());
      }
    });
  });
}
