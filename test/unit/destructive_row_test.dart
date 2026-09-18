import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/widgets/destructive_row.dart';

/// DestructiveRow's contract (design-system §4.9, constraint 7): the action is a
/// verb-labeled outlined button (not color-only), and it always takes a second,
/// deliberate confirm tap before [onConfirmed] runs. Bare `MaterialApp` (no
/// `OnyxTheme`) pins the theme-agnostic guarantee.
Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: child)),
    );

DestructiveRow _row({
  bool enabled = true,
  required Future<void> Function() onConfirmed,
}) =>
    DestructiveRow(
      icon: Icons.delete_forever_outlined,
      title: 'Reset local progress',
      actionLabel: 'Reset',
      confirmTitle: 'Reset local progress?',
      confirmMessage: 'This clears your study data.',
      enabled: enabled,
      onConfirmed: onConfirmed,
    );

void main() {
  testWidgets('shows the verb, and only confirming runs the action',
      (tester) async {
    var ran = false;
    await _pump(tester, _row(onConfirmed: () async => ran = true));

    // The action is a labeled outlined button, not a bare colored icon.
    expect(find.widgetWithText(OutlinedButton, 'Reset'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
    await tester.pumpAndSettle();
    // Confirm dialog is up; the action has NOT run on the first tap.
    expect(find.text('Reset local progress?'), findsOneWidget);
    expect(ran, isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(ran, isTrue);
  });

  testWidgets('cancelling the confirm does not run the action', (tester) async {
    var ran = false;
    await _pump(tester, _row(onConfirmed: () async => ran = true));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(ran, isFalse);
  });

  testWidgets('disabled cannot start the flow', (tester) async {
    var ran = false;
    await _pump(
        tester, _row(enabled: false, onConfirmed: () async => ran = true));

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
    await tester.tap(find.byType(OutlinedButton), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Reset local progress?'), findsNothing);
    expect(ran, isFalse);
  });
}
