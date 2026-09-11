// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/features/system_design/sd_list_screen.dart';
import 'package:onyx/shared/models/card.dart';
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
      ],
      child: const MaterialApp(home: SdListScreen()),
    );

void main() {
  testWidgets('lists problems, flagging the first as suggested next',
      (tester) async {
    await tester.pumpWidget(_app([
      _sd('design-rate-limiter', 'Design a Rate Limiter'),
      _sd('design-url-shortener', 'Design a URL Shortener'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Design a Rate Limiter'), findsOneWidget);
    expect(find.text('Design a URL Shortener'), findsOneWidget);
    expect(find.text('Suggested next'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no problems',
      (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('No system-design problems'), findsOneWidget);
  });
}
