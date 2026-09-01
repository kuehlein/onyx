// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/core/srs/learn_queue.dart';
import 'package:onyx/features/quiz/quiz_screen.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/learn.dart';
import 'package:onyx/shared/providers/practice.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/settings.dart';
import 'package:onyx/shared/providers/srs.dart';

CardSection _section(String s) =>
    CardSection(heading: s, slug: s, content: 'x', quizzable: true);

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

const _empty = Readiness(domains: [], overall: 0, low: 0, high: 0);

/// An empty study session (total == 0) so QuizScreen renders _EmptyState.
class _EmptySession extends StudySession {
  @override
  Future<SessionState> build() async =>
      const SessionState(queue: [], statesByKey: {}, index: 0);
}

Widget _app({
  required bool hasProgress,
  required int newCount,
}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const QuizScreen()),
    GoRoute(path: '/learn', builder: (_, __) => const Scaffold()),
  ]);
  return ProviderScope(
    overrides: [
      studySessionProvider.overrideWith(_EmptySession.new),
      reviewQueueProvider.overrideWith((ref) async => ReviewQueueData(
            queue: const [],
            statesByKey: hasProgress ? {'x::s1': _state()} : const {},
          )),
      learnQueueProvider.overrideWith((ref) async => [
            for (var i = 0; i < newCount; i++)
              LearnItem(card: _card('c$i'), section: _section('s1')),
          ]),
      readinessProvider.overrideWith((ref) async => _empty),
      practiceSetProvider('ds-a').overrideWith((ref) async => const []),
      gymModeProvider.overrideWith(_DisabledGym.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _DisabledGym extends GymMode {
  @override
  Future<GymModeState> build() async =>
      const GymModeState(enabled: false, restSeconds: 60);
}

// A minimal SrsState — the empty state only checks statesByKey.isNotEmpty.
SrsState _state() => SrsState(
      cardId: 'x',
      sectionSlug: 's1',
      stability: 1,
      difficulty: 5,
      state: 2,
      dueAt: DateTime(2026),
      reviewCount: 0,
    );

void main() {
  testWidgets('nothing studied yet → "nothing to test" + Learn CTA',
      (tester) async {
    await tester.pumpWidget(_app(hasProgress: false, newCount: 3));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to test yet'), findsOneWidget);
    expect(find.text('Learn 3 new cards'), findsOneWidget);
    expect(find.text('Caught up for today'), findsNothing);
  });

  testWidgets('studied but nothing due → caught up for today', (tester) async {
    await tester.pumpWidget(_app(hasProgress: true, newCount: 0));
    await tester.pumpAndSettle();

    expect(find.text('Caught up for today'), findsOneWidget);
    expect(find.text('Nothing to test yet'), findsNothing);
  });
}
