import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/features/settings/how_cards_are_read.dart';

void main() {
  test('cardParsingRules exposes the current parser facts', () {
    final byLabel = {for (final r in cardParsingRules()) r.label: r.value};
    expect(byLabel['Sections split on'], 'Headings (H2)');
    expect(byLabel['Reads files'], '.md');
    expect(byLabel.containsKey('A note is a card when it has'), isTrue);
  });

  testWidgets('the explainer shows live facts + inert future rows',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: OnyxTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showHowCardsAreReadSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('How cards are read'), findsOneWidget);
    // NOW facts (derived from the parser).
    expect(find.text('Headings (H2)'), findsOneWidget);
    expect(find.text('.md'), findsOneWidget);
    expect(find.text('type:'), findsOneWidget);
    // A LATER preview row is present but inert (no control).
    expect(find.text('Custom rule (advanced)'), findsOneWidget);
  });
}
