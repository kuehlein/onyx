import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/ladder.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/features/home/readiness_panel.dart';
import 'package:onyx/shared/providers/readiness.dart';

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
        score: 0.62,
        low: 0.5,
        high: 0.74,
        studied: 8,
        total: 10,
      ),
    ],
    overall: 0.62,
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

    expect(find.text('Knowledge-base readiness'), findsOneWidget);
    expect(find.text('Aiming at'), findsOneWidget);
    // Ladder level labels are present.
    for (final l in ['New-grad', 'Mid', 'Senior', 'Staff']) {
      expect(find.text(l), findsOneWidget);
    }
    // The recalibration summary names the inferred current rung.
    expect(find.textContaining('Mid · FAANG'), findsWidgets);
    // No overflow / assertion errors surfaced during layout.
    expect(tester.takeException(), isNull);
  });
}
