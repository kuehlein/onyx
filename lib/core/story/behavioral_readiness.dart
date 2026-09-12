/// Behavioral readiness = COVERAGE (do you have a strong story per competency —
/// durable) × FRESHNESS (have you rehearsed delivery recently — decays), per the
/// research. Kept as its own last-mile metric (surfaced in the Interview-prep
/// hub), NOT folded into the months-out knowledge-readiness gauge — behavioral is
/// a different, later thing. Pure + testable.
enum BehavioralStage {
  notStarted,
  buildingStories,
  readyToRehearse,
  rehearsing,
  sharp,
}

extension BehavioralStageInfo on BehavioralStage {
  String get label => switch (this) {
        BehavioralStage.notStarted => 'Not started',
        BehavioralStage.buildingStories => 'Building your stories',
        BehavioralStage.readyToRehearse => 'Stories ready',
        BehavioralStage.rehearsing => 'Rehearsing',
        BehavioralStage.sharp => 'Sharp',
      };

  String get hint => switch (this) {
        BehavioralStage.notStarted => 'Build your stories to get started.',
        BehavioralStage.buildingStories =>
          'Add stories to cover the missing competencies.',
        BehavioralStage.readyToRehearse =>
          'Now do a mock to rehearse delivering them.',
        BehavioralStage.rehearsing =>
          'Keep doing mocks to sharpen your delivery.',
        BehavioralStage.sharp =>
          'Delivery-ready — keep it fresh, but don\'t over-rehearse.',
      };
}

class BehavioralReadiness {
  const BehavioralReadiness({
    required this.coverage01,
    required this.freshness01,
    required this.storyCount,
    required this.recentMocks,
    required this.stage,
  });

  /// Fraction of competencies with a complete story (durable coverage).
  final double coverage01;

  /// Recent-rehearsal quality, 0..1 (delivery freshness).
  final double freshness01;
  final int storyCount;
  final int recentMocks;
  final BehavioralStage stage;

  /// A combined 0..1 for a compact readout — coverage-dominant, modulated by
  /// freshness (great stories you've never said out loud aren't delivery-ready).
  double get overall01 =>
      coverage01 == 0 ? 0 : coverage01 * (0.5 + 0.5 * freshness01);
}

/// [coveredCompetencies]/[totalCompetencies] = coverage; recent behavioral mock
/// [mocks] (score 0-100 + when) drive freshness (last 30 days).
BehavioralReadiness computeBehavioralReadiness({
  required int coveredCompetencies,
  required int totalCompetencies,
  required int storyCount,
  required List<({int score, DateTime at})> mocks,
  required DateTime now,
}) {
  final coverage01 =
      totalCompetencies == 0 ? 0.0 : coveredCompetencies / totalCompetencies;
  final recent = [
    for (final m in mocks)
      if (now.difference(m.at).inDays <= 30) m,
  ];
  final recentMocks = recent.length;
  var freshness01 = 0.0;
  if (recent.isNotEmpty) {
    final mean = recent.map((m) => m.score).reduce((a, b) => a + b) /
        recent.length /
        100.0;
    // A single recent mock counts less than a sustained couple.
    freshness01 = (mean * (recentMocks >= 2 ? 1.0 : 0.7)).clamp(0.0, 1.0);
  }

  final stage = storyCount == 0 && mocks.isEmpty
      ? BehavioralStage.notStarted
      : coverage01 < 0.6
          ? BehavioralStage.buildingStories
          : recentMocks == 0
              ? BehavioralStage.readyToRehearse
              : freshness01 < 0.65
                  ? BehavioralStage.rehearsing
                  : BehavioralStage.sharp;

  return BehavioralReadiness(
    coverage01: coverage01,
    freshness01: freshness01,
    storyCount: storyCount,
    recentMocks: recentMocks,
    stage: stage,
  );
}
