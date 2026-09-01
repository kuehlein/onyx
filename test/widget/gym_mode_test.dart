// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/core/srs/review_queue.dart';
import 'package:onyx/features/quiz/quiz_screen.dart';
import 'package:onyx/features/quiz/rest_timer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/settings.dart';
import 'package:onyx/shared/providers/srs.dart';

CardSection _section(String s) =>
    CardSection(heading: s, slug: s, content: 'answer', quizzable: true);

Card _card(String id) => Card(
      id: id,
      type: CardType.flashcard,
      title: id,
      overview: '',
      tags: const ['ds-a'],
      tiers: const {'ds-a': 1},
      sections: [_section('s1')],
      wikilinks: const [],
      filePath: '$id.md',
    );

/// A live one-item review session so QuizScreen renders the review view.
class _ActiveSession extends StudySession {
  @override
  Future<SessionState> build() async => SessionState(
        queue: [ReviewItem(card: _card('A'), section: _section('s1'))],
        statesByKey: const {},
        index: 0,
      );
}

class _Gym extends GymMode {
  _Gym(this.on);
  final bool on;
  @override
  Future<GymModeState> build() async =>
      GymModeState(enabled: on, restSeconds: 45);
}

const _empty = Readiness(domains: [], overall: 0, low: 0, high: 0);

Widget _app({required bool gymOn}) => ProviderScope(
      overrides: [
        studySessionProvider.overrideWith(_ActiveSession.new),
        readinessProvider.overrideWith((ref) async => _empty),
        gymModeProvider.overrideWith(() => _Gym(gymOn)),
      ],
      child: const MaterialApp(home: QuizScreen()),
    );

void main() {
  testWidgets('gym mode shows the rest timer and hides the coach',
      (tester) async {
    await tester.pumpWidget(_app(gymOn: true));
    await tester.pumpAndSettle();

    expect(find.byType(RestTimer), findsOneWidget);
    expect(find.text('Rest timer'), findsOneWidget);
    // Coach entry points are hidden; Reveal is the primary action.
    expect(find.text('Answer the coach'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Reveal'), findsOneWidget);
  });

  testWidgets('normal mode shows the coach and no timer', (tester) async {
    await tester.pumpWidget(_app(gymOn: false));
    await tester.pumpAndSettle();

    expect(find.byType(RestTimer), findsNothing);
    expect(find.text('Answer the coach'), findsOneWidget);
  });

  testWidgets('the rest timer starts counting on tap', (tester) async {
    await tester.pumpWidget(_app(gymOn: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(RestTimer));
    await tester.pump(const Duration(milliseconds: 100));
    // Started: shows the countdown and a "tap to reset" affordance.
    expect(find.text('tap to reset'), findsOneWidget);
    expect(find.text('45s'), findsOneWidget);
  });
}
