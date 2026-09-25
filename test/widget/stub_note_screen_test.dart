// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/features/browse/stub_note_screen.dart';
import 'package:onyx/shared/providers/vault.dart';

/// S4 (ADR-0012 / task 1f §7): the STUB view for a broken `[[wikilink]]`. It's a
/// focused screen — NOT a synthetic Card — that de-slugs the target for a title,
/// lists the cards that reference it (from the UNRESOLVED graph, filtered by
/// target), and offers "Create this note". Here we pin that rendering contract.

/// Overrides [unresolvedLinksProvider] with [groups] and pumps [StubNoteScreen].
Future<void> _pumpStub(
  WidgetTester tester,
  String target,
  List<({String target, List<UnresolvedLink> refs})> groups,
) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      unresolvedLinksProvider.overrideWith((ref) async => groups),
    ],
    child: MaterialApp(
      theme: OnyxTheme.dark(),
      home: StubNoteScreen(target: target),
    ),
  ));
  await tester.pumpAndSettle();
}

UnresolvedLink _ref(String fromId, String fromTitle, String target) =>
    UnresolvedLink(fromCardId: fromId, fromTitle: fromTitle, target: target);

void main() {
  testWidgets('renders humanized title, the raw [[target]], refs + create CTA',
      (tester) async {
    await _pumpStub(tester, 'Two Pointers', [
      (
        target: 'Two Pointers',
        refs: [
          _ref('c1', 'Valid Palindrome', 'Two Pointers'),
          _ref('c2', 'Container With Most Water', 'Two Pointers'),
        ],
      ),
    ]);

    // AppBar title is the de-slugged target (cosmetic); the body shows the raw
    // link so it's unambiguous which [[target]] will be created.
    expect(find.widgetWithText(AppBar, 'Two Pointers'), findsOneWidget);
    expect(find.text('[[Two Pointers]]'), findsOneWidget);
    expect(
        find.widgetWithText(FilledButton, 'Create this note'), findsOneWidget);

    // References come from the unresolved group filtered by target.
    expect(find.text('REFERENCED BY'), findsOneWidget);
    expect(find.text('Valid Palindrome'), findsOneWidget);
    expect(find.text('Container With Most Water'), findsOneWidget);
  });

  testWidgets('de-slugs a kebab target for the title but keeps the raw link',
      (tester) async {
    await _pumpStub(tester, 'sliding-window', [
      (
        target: 'sliding-window',
        refs: [_ref('c1', 'Best Time', 'sliding-window')]
      ),
    ]);
    expect(find.widgetWithText(AppBar, 'Sliding Window'), findsOneWidget);
    expect(find.text('[[sliding-window]]'), findsOneWidget);
  });

  testWidgets('no matching group → CTA still shows, no References section',
      (tester) async {
    // The stub can be opened for a target that isn't in the (possibly stale)
    // unresolved set; it must still offer to create the note.
    await _pumpStub(tester, 'Ghost', [
      (target: 'Something Else', refs: [_ref('c1', 'Other', 'Something Else')]),
    ]);
    expect(
        find.widgetWithText(FilledButton, 'Create this note'), findsOneWidget);
    expect(find.text('REFERENCED BY'), findsNothing);
    expect(find.text('Other'), findsNothing);
  });
}
