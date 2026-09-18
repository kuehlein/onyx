import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/widgets/confidence_badge.dart';

void main() {
  testWidgets('renders a label for each confidence level', (tester) async {
    for (final (level, label) in const [
      (Confidence.high, 'High confidence'),
      (Confidence.medium, 'Medium confidence'),
      (Confidence.low, 'Low confidence'),
    ]) {
      // ConfidenceBadge composes StatusPill, which reads OnyxColors/OnyxTokens —
      // so it must be pumped inside the app theme that registers them.
      await tester.pumpWidget(
        MaterialApp(
            theme: OnyxTheme.dark(),
            home: Scaffold(body: ConfidenceBadge(level))),
      );
      expect(find.text(label), findsOneWidget);
    }
  });
}
