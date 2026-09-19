// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/features/editor/card_editor_screen.dart';

import 'support/harness.dart';

/// The in-app card editor (#28) had no widget-level coverage. These use the
/// shared [pumpScreen] harness (theme registered so its StatusPill/tokens
/// resolve) to exercise the create-mode form + the preview toggle without the
/// async save path.
void main() {
  testWidgets('create mode renders the form: title, tags, body, Save',
      (tester) async {
    await pumpScreen(tester, const CardEditorScreen());

    expect(find.text('New card'), findsOneWidget); // app-bar title
    expect(find.text('Save'), findsOneWidget);
    // Title, Tags, Body fields.
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Body (markdown)'), findsOneWidget);
  });

  testWidgets('the preview toggle renders the typed title', (tester) async {
    await pumpScreen(tester, const CardEditorScreen());

    // Title is the first field, body the third (tags between).
    await tester.enterText(find.byType(TextField).at(0), 'My New Card');
    await tester.enterText(
        find.byType(TextField).at(2), '## Answer\n\nThe answer.');
    await tester.pump();

    await tester.tap(find.byTooltip('Preview'));
    await tester.pump();

    // Preview replaces the form with the rendered card; the title shows as a
    // heading and the editing fields are gone.
    expect(find.text('My New Card'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
