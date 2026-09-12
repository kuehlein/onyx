// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/features/behavioral/behavioral_entry_screen.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/behavioral.dart';

void main() {
  testWidgets('shows an empty state when there are no competencies',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        behavioralCompetenciesProvider.overrideWith((ref) async => <Card>[]),
      ],
      child: const MaterialApp(home: BehavioralEntryScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No behavioral competencies'), findsOneWidget);
  });
}
