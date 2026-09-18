import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/widgets/empty_state.dart';

/// EmptyState structure + its theme-agnostic contract (design-system §6). The
/// bare `MaterialApp` (no `OnyxTheme`) is the point: empty/error frames must
/// render without the Onyx `ThemeExtension`s in scope. Visual regression is the
/// golden's job; this pins which slots show.
Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('title only — no icon, message, or action', (tester) async {
    await _pump(tester, const EmptyState(title: 'No matches'));

    expect(find.text('No matches'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('renders icon + message + action when given', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No cards indexed',
        message: 'Point Onyx at a vault in Settings.',
        action: FilledButton(
          onPressed: () => tapped = true,
          child: const Text('Open Settings'),
        ),
      ),
    );

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('No cards indexed'), findsOneWidget);
    expect(find.text('Point Onyx at a vault in Settings.'), findsOneWidget);

    await tester.tap(find.text('Open Settings'));
    expect(tapped, isTrue);
  });
}
