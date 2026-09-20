import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/features/browse/publish_deck_sheet.dart';
import 'package:onyx/shared/providers/registry.dart';
import 'package:onyx/shared/providers/vault.dart';

/// The publish (push) UI + its capability gate (task #30 / registry-and-sync.md
/// §4). The publish LOGIC is covered by publish_deck_test; here we cover the
/// capability seam and the sheet's honest no-folder guard.
void main() {
  test('sharing is reachable in dev/test builds (capability gate on)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    // kDebugMode is true under `flutter test`, so the SHARING UI is reachable to
    // develop/test against the fake; a release build with no backend → false.
    expect(c.read(sharingReachableProvider), isTrue);
  });

  testWidgets('publish sheet guards honestly when no study folder is set',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [vaultSourceProvider.overrideWithValue(null)],
      child: MaterialApp(
        theme: OnyxTheme.dark(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPublishDeckSheet(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Publish a deck'), findsOneWidget);
    expect(find.textContaining('Set up a study folder first'), findsOneWidget);
    // With no folder, there's no export form.
    expect(find.text('Publish'), findsNothing);
  });
}
