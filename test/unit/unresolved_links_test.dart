import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';

String _card({
  required String id,
  required String title,
  required String body,
}) =>
    '''
---
id: $id
type: flashcard
tags: [test]
---

# $title

$body

## When to Use

Recall it.
''';

/// Unresolved-links detection (task #20): a `[[wikilink]]` is dangling only when
/// NO file of any type shares its name — driven through the real parser so
/// wikilink extraction is exercised too.
void main() {
  group('computeUnresolvedLinks', () {
    const parser = CardParser();
    Card parse(String content, String path) =>
        parser.parse(content, filePath: path)!;

    test('flags a target with no file; a target with a .md card resolves', () {
      final alpha = parse(
        _card(
          id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          title: 'Alpha',
          body: 'See [[beta]] and [[ghost]].',
        ),
        'alpha.md',
      );
      final beta = parse(
        _card(
          id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          title: 'Beta',
          body: 'Nothing linked here.',
        ),
        'beta.md',
      );

      // Only alpha.md + beta.md exist → [[ghost]] is dangling, [[beta]] resolves.
      final unresolved =
          computeUnresolvedLinks([alpha, beta], {'alpha', 'beta'});
      expect(unresolved.map((u) => u.target), ['ghost']);
      expect(unresolved.single.fromCardId, alpha.id);
      expect(unresolved.single.fromTitle, 'Alpha');
    });

    test('a link to a NON-.md file (any extension) is not flagged', () {
      final alpha = parse(
        _card(
          id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          title: 'Alpha',
          body: 'See the [[diagram]] and [[notes]].',
        ),
        'alpha.md',
      );

      // diagram.png + notes.txt exist (stems present) → both resolve, none
      // dangling — resolution follows file-type support, not just `.md`.
      final unresolved =
          computeUnresolvedLinks([alpha], {'alpha', 'diagram', 'notes'});
      expect(unresolved, isEmpty);
    });

    test('the same missing target from two cards yields one entry each', () {
      Card ref(String id, String title) => parse(
            _card(id: id, title: title, body: 'Depends on [[missing]].'),
            '$title.md',
          );
      final one = ref('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'One');
      final two = ref('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'Two');

      final unresolved = computeUnresolvedLinks([one, two], {'One', 'Two'});
      expect(unresolved.length, 2);
      expect(unresolved.every((u) => u.target == 'missing'), isTrue);
      expect(unresolved.map((u) => u.fromTitle).toSet(), {'One', 'Two'});
    });
  });
}
