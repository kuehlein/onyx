import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/story/behavioral_readiness.dart';

void main() {
  final now = DateTime(2026, 9, 12);
  ({int score, DateTime at}) mock(int score, int daysAgo) =>
      (score: score, at: now.subtract(Duration(days: daysAgo)));

  BehavioralReadiness r({
    int covered = 0,
    int stories = 0,
    List<({int score, DateTime at})> mocks = const [],
  }) =>
      computeBehavioralReadiness(
        coveredCompetencies: covered,
        totalCompetencies: 8,
        storyCount: stories,
        mocks: mocks,
        now: now,
      );

  test('nothing yet → notStarted, 0 overall', () {
    final b = r();
    expect(b.stage, BehavioralStage.notStarted);
    expect(b.overall01, 0);
  });

  test('under 60% coverage → building stories', () {
    expect(r(covered: 4, stories: 4).stage, BehavioralStage.buildingStories);
  });

  test('good coverage, no recent mocks → ready to rehearse', () {
    final b = r(covered: 6, stories: 6);
    expect(b.stage, BehavioralStage.readyToRehearse);
    expect(b.freshness01, 0);
    expect(b.overall01, greaterThan(0)); // coverage alone gives partial
  });

  test('recent weak mocks → rehearsing; strong → sharp', () {
    expect(r(covered: 8, stories: 8, mocks: [mock(50, 2), mock(55, 5)]).stage,
        BehavioralStage.rehearsing);
    final sharp = r(covered: 8, stories: 8, mocks: [mock(85, 2), mock(90, 6)]);
    expect(sharp.stage, BehavioralStage.sharp);
    expect(sharp.freshness01, greaterThan(0.65));
  });

  test('mocks older than 30 days do not count as recent', () {
    final b = r(covered: 8, stories: 8, mocks: [mock(90, 45)]);
    expect(b.recentMocks, 0);
    expect(b.stage, BehavioralStage.readyToRehearse);
  });
}
