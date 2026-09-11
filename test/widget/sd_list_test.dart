// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/system_design_interviewer.dart' show SdSupportMode;
import 'package:onyx/core/clock.dart';
import 'package:onyx/features/system_design/sd_list_screen.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/system_design.dart';

Card _sd(String id, String title) => Card(
      id: id,
      type: CardType.systemDesign,
      title: title,
      overview: '',
      tags: const ['system-design'],
      tiers: const {'system-design': 2},
      sections: const [],
      wikilinks: const [],
      filePath: '$id.md',
    );

Widget _app(List<Card> problems) => ProviderScope(
      overrides: [
        systemDesignProblemsProvider.overrideWith((ref) async => problems),
        clockProvider.overrideWith((ref) async => Clock.real),
        sdAutoSupportModeProvider
            .overrideWith((ref) async => SdSupportMode.coaching),
        for (final c in problems)
          systemDesignDueProvider(c.id).overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: SdListScreen()),
    );

void main() {
  testWidgets('leads with the next mock and offers others', (tester) async {
    await tester.pumpWidget(_app([
      _sd('design-rate-limiter', 'Design a Rate Limiter'),
      _sd('design-url-shortener', 'Design a URL Shortener'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Your next mock'), findsOneWidget);
    expect(find.text('Design a Rate Limiter'), findsOneWidget); // hero
    expect(find.text('Start the mock'), findsOneWidget);
    expect(find.text('Or practise another'), findsOneWidget);
    expect(find.text('Design a URL Shortener'), findsOneWidget); // in the list
  });

  testWidgets('shows an empty state when there are no problems',
      (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('No system-design problems'), findsOneWidget);
  });
}
