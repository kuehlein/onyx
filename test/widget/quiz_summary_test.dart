// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/srs/review_queue.dart';
import 'package:onyx/features/quiz/quiz_screen.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/settings.dart';
import 'package:onyx/shared/providers/srs.dart';

CardSection _section(String h) =>
    CardSection(heading: h, slug: h, content: 'x', quizzable: true);

Card _card(String id, String domain) => Card(
      id: id,
      type: CardType.flashcard,
      title: id,
      overview: '',
      tags: [domain],
      tiers: {domain: 1},
      sections: [_section('s1')],
      wikilinks: const [],
      filePath: '$id.md',
    );

/// A study session already finished (index == total), carrying a before-snapshot
/// and a grade mix — the state the completion screen renders.
class _DoneSession extends StudySession {
  @override
  Future<SessionState> build() async {
    final item = ReviewItem(card: _card('A', 'ds-a'), section: _section('s1'));
    return SessionState(
      queue: [item, item],
      statesByKey: const {},
      index: 2,
      grades: const [3, 3, 1],
      readinessBefore: const Readiness(
        domains: [
          DomainReadiness(
              domain: 'ds-a',
              coverage: 1,
              strength: 0.5,
              score: 0.50,
              low: 0.4,
              high: 0.6,
              studied: 1,
              total: 1),
        ],
        overall: 0.50,
        low: 0.4,
        high: 0.6,
      ),
    );
  }
}

class _FakeTargetController extends ReadinessTargetController {
  @override
  Future<ReadinessTarget> build() async => ReadinessTarget.fallback;
}

class _DisabledGym extends GymMode {
  @override
  Future<GymModeState> build() async =>
      const GymModeState(enabled: false, restSeconds: 60);
}

void main() {
  testWidgets('completion screen shows stats and an honest progress delta',
      (tester) async {
    // "After" is higher than the session's before-snapshot → a positive delta.
    const after = Readiness(
      domains: [
        DomainReadiness(
            domain: 'ds-a',
            coverage: 1,
            strength: 0.6,
            score: 0.56,
            low: 0.46,
            high: 0.66,
            studied: 1,
            total: 1),
      ],
      overall: 0.56,
      low: 0.46,
      high: 0.66,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studySessionProvider.overrideWith(_DoneSession.new),
          readinessProvider.overrideWith((ref) async => after),
          readinessTargetControllerProvider
              .overrideWith(_FakeTargetController.new),
          gymModeProvider.overrideWith(_DisabledGym.new),
        ],
        child: const MaterialApp(home: QuizScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('2 sections reviewed'), findsOneWidget);
    // Grade mix: two Good, one Again.
    expect(find.text('Good 2'), findsOneWidget);
    expect(find.text('Again 1'), findsOneWidget);
    // Progress toward the target, with an overall line and the DS&A subject.
    expect(find.textContaining('Progress toward'), findsOneWidget);
    expect(find.text('Overall'), findsOneWidget);
    expect(find.text('DS & A'), findsOneWidget);
    // +6.0% overall (0.56 - 0.50), shown as a positive delta.
    expect(find.text('+6.0%'), findsWidgets);
    // Honesty caveat present; no XP/points hype.
    expect(find.textContaining('not a mock-validated interview score'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
