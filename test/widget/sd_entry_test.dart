// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/features/system_design/sd_entry_screen.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/system_design.dart';

void main() {
  testWidgets('shows an empty state when there are no problems',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        systemDesignProblemsProvider.overrideWith((ref) async => <Card>[]),
      ],
      child: const MaterialApp(home: SdEntryScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No system-design problems'), findsOneWidget);
  });
}
