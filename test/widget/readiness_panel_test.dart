import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/ladder.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/stats/streak.dart';
import 'package:onyx/features/home/readiness_panel.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/stats.dart';

/// Serves a fixed target without reaching the DB / vault.
class _FakeTargetController extends ReadinessTargetController {
  @override
  Future<ReadinessTarget> build() async => const ReadinessTarget(
        level: SeniorityLevel.senior,
        company: CompanyTier.faang,
        track: Track.general,
      );
}

void main() {
  const readiness = Readiness(
    domains: [
      DomainReadiness(
        domain: 'ds-a',
        coverage: 0.8,
        strength: 0.7,
        score: 0.55,
        low: 0.5,
        high: 0.74,
        studied: 8,
        total: 10,
      ),
    ],
    overall: 0.62, // distinct from the domain score so "62%" is unambiguous
    low: 0.5,
    high: 0.74,
  );

  final ladder = LadderPosition(
    rungScores: List<double>.filled(readinessLadder.length, 0.6),
    clearedCount: 4,
    youFraction: 0.6,
    goalIndex: 5, // Senior · FAANG
    goalFraction: 0.75,
    currentLabel: 'Mid · FAANG',
    rungsToGo: 2,
  );

  testWidgets(
      'renders the studied panel — gauge, ticks and domain bars — '
      'without layout errors', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readinessProvider.overrideWith((ref) async => readiness),
          readinessLadderPositionProvider.overrideWith((ref) async => ladder),
          readinessPaceProvider.overrideWith((ref) async => null),
          readinessTargetControllerProvider
              .overrideWith(_FakeTargetController.new),
          studyStreakProvider.overrideWith((ref) async => const StreakInfo(
                current: 5,
                best: 9,
                studiedToday: true,
                todayCount: 12,
              )),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: SingleChildScrollView(child: ReadinessPanel()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Headline: the overall % and the tappable target it's measured against.
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('Senior · FAANG · General'), findsOneWidget);
    // Recall-only state (no mock evidence) is shown next to the band.
    expect(find.textContaining('recall only'), findsOneWidget);
    // Compact streak chip shows the current run.
    expect(find.text('5'), findsWidgets);
    // Ladder standing is shown as discrete milestone chips, one per level.
    expect(find.text('Ladder standing'), findsOneWidget);
    for (final l in ['New-grad', 'Mid', 'Senior', 'Staff']) {
      expect(find.text(l), findsOneWidget);
    }
    // The caption names the current rung the user clears.
    expect(find.textContaining('Mid · FAANG'), findsWidgets);
    // No overflow / assertion errors surfaced during layout.
    expect(tester.takeException(), isNull);
  });

  testWidgets('graduates to interview readiness when transfer evidence exists',
      (tester) async {
    const interviewReadiness = Readiness(
      domains: [
        DomainReadiness(
          domain: 'system-design', // a longer label, to stress the row width
          coverage: 1,
          strength: 0.8,
          score: 0.5, // interview-adjusted (proven) — the darker fill
          recall: 0.72, // recall ceiling — the lighter fill it sits inside
          low: 0.38,
          high: 0.62,
          studied: 5,
          total: 5,
          transfer: 0.55,
          appliedN: 4,
        ),
      ],
      overall: 0.5,
      low: 0.38,
      high: 0.62,
      interview: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readinessProvider.overrideWith((ref) async => interviewReadiness),
          readinessLadderPositionProvider.overrideWith((ref) async => ladder),
          readinessPaceProvider.overrideWith((ref) async => null),
          readinessTargetControllerProvider
              .overrideWith(_FakeTargetController.new),
          studyStreakProvider.overrideWith((ref) async => StreakInfo.empty),
          appliedSummaryProvider.overrideWith(
              (ref) async => {'system-design': (attempts: 4, contested: 1)}),
        ],
        // A narrow phone width to guard against row overflow.
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: SingleChildScrollView(child: ReadinessPanel()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Graduated state: the header reads "interview-tested", not recall-only.
    expect(find.textContaining('interview-tested'), findsOneWidget);
    expect(find.textContaining('recall only'), findsNothing);
    // The two-tone bar legend appears once mocks graduate the view.
    expect(find.text('proven in mocks'), findsOneWidget);
    expect(find.text('recall to prove'), findsOneWidget);
    // The evidence decomposition is surfaced per domain: mock count + contested.
    expect(find.textContaining('4 mocks'), findsOneWidget);
    expect(find.textContaining('1 contested'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
