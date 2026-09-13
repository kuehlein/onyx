import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/analytics/insights.dart';
import 'package:onyx/core/analytics/retention.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/features/insights/insights_screen.dart';
import 'package:onyx/shared/providers/analytics.dart';
import 'package:onyx/shared/providers/readiness.dart';

const _emptyMock = MockSkills(
    count: 0, avgScore: 0, avgHintLevel: 0, novelFraction: 0, dims: {});
const _emptyAlgo = AlgoStats(
    logged: 0, distinctProblems: 0, patterns: 0, cleanRate: 0, last7: 0);
const _emptyReadiness = Readiness(domains: [], overall: 0, low: 0, high: 0);

/// Pump Insights with the top-level providers overridden. Readiness is left
/// empty so the reused ReadinessPanel cleanly shrinks (its own chain is tested
/// elsewhere) and this focuses on the new summary strip + collapsible groups.
Widget _harness({
  Readiness? readiness,
  List<DomainRetention> retention = const [],
  MockSkills? mocks,
  List<int> consistency = const [],
}) =>
    ProviderScope(
      overrides: [
        readinessProvider
            .overrideWith((ref) async => readiness ?? _emptyReadiness),
        retentionByDomainProvider.overrideWith((ref) async => retention),
        mockSkillsProvider.overrideWith((ref) async => mocks ?? _emptyMock),
        systemDesignSkillsProvider.overrideWith((ref) async => _emptyMock),
        behavioralSkillsProvider.overrideWith((ref) async => _emptyMock),
        algoStatsProvider.overrideWith((ref) async => _emptyAlgo),
        studyConsistencyProvider.overrideWith((ref) async => consistency),
        // Watched only when the (collapsed) Memory group is expanded.
        dueForecastProvider.overrideWith((ref) async => const <int>[]),
        strugglingCardsProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: InsightsScreen()),
    );

void main() {
  testWidgets('summary strip + collapsed groups; group expands on tap',
      (tester) async {
    await tester.pumpWidget(_harness(
      retention: const [
        DomainRetention(
            domain: 'ds-a',
            reviews: 20,
            recall: 0.9,
            avgStabilityDays: 12,
            studiedSections: 5),
      ],
      mocks: const MockSkills(
          count: 2,
          avgScore: 78,
          avgHintLevel: 1.2,
          novelFraction: 0.5,
          dims: {}),
      consistency: [
        for (var i = 0; i < 28; i++) i >= 23 ? 1 : 0
      ], // 5 of last 7
    ));
    await tester.pumpAndSettle();

    // Summary KPIs (only those with data).
    expect(find.text('Recall'), findsOneWidget);
    expect(find.text('90%'), findsWidgets);
    expect(find.text('Mock avg'), findsOneWidget);
    expect(find.text('78'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('5/7'), findsOneWidget);

    // All four group headers present.
    expect(find.text('Readiness'), findsOneWidget);
    expect(find.text('Memory & recall'), findsOneWidget);
    expect(find.text('Applied performance'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);

    // A collapsed group's inner section is not built until expanded.
    expect(find.text('Retention by domain'), findsNothing);
    await tester.tap(find.text('Memory & recall'));
    await tester.pumpAndSettle();
    expect(find.text('Retention by domain'), findsOneWidget);
  });

  testWidgets('brand-new user (no data) shows the empty state', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text('No insights yet'), findsOneWidget);
    expect(find.text('Memory & recall'), findsNothing);
  });
}
