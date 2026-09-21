import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/registry/deck.dart';
import 'package:onyx/core/registry/deck_update.dart';
import 'package:onyx/core/registry/import_deck.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';

/// Upstream-update reconciliation (task #30 / registry-and-sync.md §3.4/§4.3):
/// added + changed cards re-enter through the draft gate; removed cards are
/// tombstoned (preserved), never silently deleted. Nothing mutates silently.
String _card(String id, String title, String body) =>
    '---\nid: $id\ntype: flashcard\ntags: [geography]\n---\n\n'
    '# $title\n\n## Fact\n\n$body\n';

final _v1 = DeckManifest(deckId: 'geo', name: 'Geo', author: 'x', files: [
  DeckFile(path: 'france.md', content: _card('france', 'France', 'Paris.')),
  DeckFile(path: 'japan.md', content: _card('japan', 'Japan', 'Tokyo.')),
]);

// france CHANGED, brazil ADDED, japan REMOVED.
final _v2 = DeckManifest(deckId: 'geo', name: 'Geo', author: 'x', files: [
  DeckFile(
      path: 'france.md',
      content: _card('france', 'France', 'Paris (updated).')),
  DeckFile(path: 'brazil.md', content: _card('brazil', 'Brazil', 'Brasília.')),
]);

void main() {
  test('reconcile detects added / changed / removed by path + content', () {
    final u = reconcileDeckUpdate(_v1, _v2);
    expect(u.added.map((f) => f.path), ['brazil.md']);
    expect(u.changed.map((f) => f.path), ['france.md']);
    expect(u.removed, ['japan.md']);
    expect(u.drafts.map((f) => f.path).toSet(), {'brazil.md', 'france.md'});
  });

  test('an identical re-pull is a no-op', () {
    expect(reconcileDeckUpdate(_v1, _v1).isEmpty, isTrue);
  });

  test('apply re-drafts added+changed (even if promoted); removed is preserved',
      () async {
    final dir = await Directory.systemTemp.createTemp('onyx_update_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final source = DesktopVaultSource(dir.path);

    await importDeck(source, _v1); // france + japan land as drafts under geo/
    // Simulate the learner having reviewed + promoted france to active.
    await source.writeFile(
        'geo/france.md',
        '---\nid: france\ntype: flashcard\ndeck: "geo"\nstatus: active\n'
            'tags: [geography]\n---\n\n# France\n\n## Fact\n\nParis.\n');

    final update = reconcileDeckUpdate(_v1, _v2);
    final n = await applyDeckUpdate(source, _v2, update);
    expect(n, 2); // france (changed) + brazil (added)

    const parser = CardParser();
    // france changed → back to a draft, with the new content.
    final france = parser.parse(await source.readCard('geo/france.md'),
        filePath: 'geo/france.md')!;
    expect(france.isDraft, isTrue, reason: 'a changed card re-enters the gate');
    expect(france.sections.single.content, 'Paris (updated).');
    // brazil added → draft.
    final brazil = parser.parse(await source.readCard('geo/brazil.md'),
        filePath: 'geo/brazil.md')!;
    expect(brazil.isDraft, isTrue);
    // japan removed upstream → tombstone: still on disk, history not deleted.
    expect(File('${dir.path}/geo/japan.md').existsSync(), isTrue);
  });
}
