// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/shared/widgets/view_full_card_button.dart';

import 'support/harness.dart';

/// The shared study→card affordance (ADR-0012 / task 1f): lifted verbatim from
/// Learn + Review. It appears only when the card has material beyond the quizzed
/// sections (a non-quizzable reference the reveal omits), else renders nothing.

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(theme: OnyxTheme.dark(), home: Scaffold(body: child)),
    );

void main() {
  testWidgets('shows the link when a non-quizzable section exists',
      (tester) async {
    final card = testCard('C', 'Two Sum', sections: [
      testSection('Approach'),
      testSection('Implementation', quizzable: false),
    ]);
    await _pump(tester, ViewFullCardButton(card: card));
    expect(find.text('View full card'), findsOneWidget);
  });

  testWidgets('renders nothing when every section is quizzable',
      (tester) async {
    final card = testCard('C', 'Two Sum', sections: [testSection('Approach')]);
    await _pump(tester, ViewFullCardButton(card: card));
    expect(find.text('View full card'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
}
