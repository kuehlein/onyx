import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/widgets/confidence_badge.dart';

void main() {
  testWidgets('renders a label for each confidence level', (tester) async {
    for (final (level, label) in const [
      (Confidence.high, 'High confidence'),
      (Confidence.medium, 'Medium confidence'),
      (Confidence.low, 'Low confidence'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ConfidenceBadge(level))),
      );
      expect(find.text(label), findsOneWidget);
    }
  });
}
