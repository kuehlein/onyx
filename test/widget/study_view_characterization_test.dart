// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/core/srs/learn_queue.dart';
import 'package:onyx/core/srs/review_queue.dart';
import 'package:onyx/features/learn/learn_screen.dart';
import 'package:onyx/features/quiz/quiz_screen.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/learn.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/settings.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/study_grades.dart';

/// S0 characterization (ADR-0012 / task 1f): pins the RENDERING contract of the
/// Learn + Review study views before the card-widget unify rebuilds them, so the
/// refactor can't silently change the cue source, the grade set, or the reveal
/// gate. Sessions are faked (build only) so no grade is written — the DB-write
/// semantics live in test/unit/grade_paths_test.dart.

CardSection _s(String heading, {bool quizzable = true}) => CardSection(
      heading: heading,
      slug: heading.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-'),
      content: 'the answer body',
      quizzable: quizzable,
    );

Card _card({
  required String id,
  String type = 'flashcard',
  String overview = '',
  List<CardSection>? sections,
}) =>
    Card(
      id: id,
      type: type,
      title: id,
      overview: overview,
      tags: const ['ds-a'],
      tiers: const {'ds-a': 1},
      sections: sections ?? [_s('Definition')],
      wikilinks: const [],
      filePath: '$id.md',
    );

class _FakeLearn extends LearnSession {
  _FakeLearn(this._item);
  final LearnItem _item;
  @override
  Future<LearnSessionState> build() async =>
      LearnSessionState(queue: [_item], graduated: 0);
}

class _FakeReview extends StudySession {
  _FakeReview(this._item);
  final ReviewItem _item;
  @override
  Future<SessionState> build() async =>
      SessionState(queue: [_item], statesByKey: const {}, index: 0);
}

const _emptyReadiness = Readiness(domains: [], overall: 0, low: 0, high: 0);

Widget _learnApp(LearnItem item) => ProviderScope(
      overrides: [learnSessionProvider.overrideWith(() => _FakeLearn(item))],
      child: MaterialApp(theme: OnyxTheme.dark(), home: const LearnScreen()),
    );

Widget _reviewApp(ReviewItem item) => ProviderScope(
      overrides: [
        studySessionProvider.overrideWith(() => _FakeReview(item)),
        readinessProvider.overrideWith((ref) async => _emptyReadiness),
        gymModeProvider.overrideWith(() => _NoGym()),
      ],
      child: MaterialApp(theme: OnyxTheme.dark(), home: const QuizScreen()),
    );

class _NoGym extends GymMode {
  @override
  Future<GymModeState> build() async =>
      const GymModeState(enabled: false, restSeconds: 45);
}

void main() {
  group('Learn view', () {
    testWidgets('pretest gate: body hidden until Reveal; cue is the heading',
        (tester) async {
      await tester.pumpWidget(_learnApp(
          LearnItem(card: _card(id: 'L'), section: _s('When to Use'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();

      // The cue is the section heading; the answer body is withheld pre-reveal.
      expect(find.text('When to Use'), findsOneWidget);
      expect(find.textContaining('Take a guess'), findsOneWidget);
      expect(find.text('the answer body'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Reveal'), findsOneWidget);
      expect(find.text('Good'), findsNothing); // no grade bar before reveal
    });

    testWidgets('reveal shows the body + a 3-grade bar with NO Easy',
        (tester) async {
      await tester.pumpWidget(_learnApp(LearnItem(
        card: _card(id: 'L', sections: [
          _s('When to Use'),
          _s('References', quizzable: false),
        ]),
        section: _s('When to Use'),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reveal'));
      await tester.pumpAndSettle();

      expect(find.text('the answer body'), findsOneWidget);
      // Learn grades: Again / Hard / Good — never Easy (unearned on first sight).
      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Easy'), findsNothing);
      // A non-quizzable section is reachable via "View full card".
      expect(find.text('View full card'), findsOneWidget);
    });
  });

  group('Review view', () {
    testWidgets('concept card cues on the section heading (pre-reveal)',
        (tester) async {
      await tester.pumpWidget(_reviewApp(
          ReviewItem(card: _card(id: 'R'), section: _s('Definition'))));
      await tester.pumpAndSettle();

      expect(find.text('Definition'), findsOneWidget); // the cue
      expect(find.text('the answer body'), findsNothing); // withheld
      expect(find.text('Answer the coach'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Reveal'), findsOneWidget);
    });

    testWidgets('approach card cues on the overview (problem statement)',
        (tester) async {
      final approach = _card(
        id: 'AQ',
        type: 'interview',
        overview: 'Design a rate limiter.',
        sections: [_s('Approach')],
      );
      // Only meaningful if this type is an approach card for the template.
      if (!approach.isApproachCard) return;
      await tester.pumpWidget(
          _reviewApp(ReviewItem(card: approach, section: _s('Approach'))));
      await tester.pumpAndSettle();

      expect(find.textContaining('Design a rate limiter'), findsOneWidget);
    });
  });

  group('grade sets stay distinct', () {
    test('Review offers Easy; Learn does not', () {
      expect(studyGrades.any((g) => g.value == 4 && g.label == 'Easy'), isTrue);
      expect(learnGrades.any((g) => g.label == 'Easy'), isFalse);
      expect(learnGrades.length, 3);
      expect(studyGrades.length, 4);
    });
  });
}
