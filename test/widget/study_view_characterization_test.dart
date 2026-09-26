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

    testWidgets('reveal shows the body + the full grade bar incl. Easy (n0014)',
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
      // Learn now offers the full set; Easy is safe because the scheduler caps a
      // new card's Easy interval (n0014), not by withholding the grade.
      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      // A non-quizzable section is reachable via "View full card".
      expect(find.text('View full card'), findsOneWidget);
    });

    testWidgets(
        'a substantial section shows the "Talk it through" chip post-reveal (n0015)',
        (tester) async {
      const substantial = CardSection(
        heading: 'When to Use',
        slug: 'when-to-use',
        content: 'Reach for this when X.\n\n- signal one\n- signal two',
        quizzable: true,
      );
      await tester.pumpWidget(_learnApp(LearnItem(
        card: _card(id: 'L', sections: [substantial]),
        section: substantial,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      // Learner-invited + post-reveal: no chip while still guessing.
      expect(find.text('Talk it through'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Reveal'));
      await tester.pumpAndSettle();
      expect(find.text('Talk it through'), findsOneWidget);
    });

    testWidgets('a one-line stub section shows no tutor chip (n0015)',
        (tester) async {
      const stub = CardSection(
        heading: 'Variants', // not a pretest heading → shown immediately
        slug: 'variants',
        content: 'A single short line.',
        quizzable: true,
      );
      await tester.pumpWidget(_learnApp(LearnItem(
        card: _card(id: 'L', sections: [stub]),
        section: stub,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      // Already revealed (read section), but too thin to elicit → no chip.
      expect(find.text('Talk it through'), findsNothing);
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

  group('grade sets', () {
    test(
        'both Review and Learn offer Easy (Learn caps it at the scheduler, n0014)',
        () {
      expect(studyGrades.any((g) => g.value == 4 && g.label == 'Easy'), isTrue);
      expect(learnGrades.any((g) => g.label == 'Easy'), isTrue);
      expect(learnGrades.length, 4);
      expect(studyGrades.length, 4);
    });
  });
}
