import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/widgets/confidence_badge.dart';
import 'package:onyx/shared/widgets/status_pill.dart';

/// StatusPill structure + the color+shape+number+Semantics contract (design-system
/// §4.1). Verifiable without goldens (which are the visual regression net).

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
          theme: OnyxTheme.dark(), home: Scaffold(body: Center(child: child))),
    );

void main() {
  testWidgets('shows label + value and speaks one merged Semantics node',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const StatusPill(tone: StatusTone.good, label: 'Ready', value: '0.82'),
    );

    expect(find.text('Ready · 0.82'), findsOneWidget); // number channel present
    expect(
        find.bySemanticsLabel('Ready · 0.82'), findsOneWidget); // spoken once
    handle.dispose();
  });

  testWidgets('semanticLabel overrides the announced text', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const StatusPill(
        tone: StatusTone.warn,
        label: 'Shaky',
        semanticLabel: 'Confidence medium. Cross-check the Resources.',
      ),
    );
    expect(
      find.bySemanticsLabel('Confidence medium. Cross-check the Resources.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('ConfidenceBadge composes a StatusPill with the tip as Semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const ConfidenceBadge(Confidence.high));

    expect(find.byType(StatusPill), findsOneWidget);
    expect(find.text('High confidence'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('High confidence')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
