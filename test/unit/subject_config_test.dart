import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/ladder.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/subject/software_interviews.dart';

/// Golden tests for task #30 Phase 0: the SWE reference [softwareInterviewsConfig]
/// must reproduce the legacy readiness math bit-for-bit. Two guarantees per area:
///   1. cross-check — config output == the current target.dart/ladder.dart output
///      across the full input matrix (proves the config mirror is faithful), and
///   2. anchors — a handful of hardcoded literal expectations (proves the behavior
///      is what we think, not just "two implementations agree").
/// These lock SWE behavior BEFORE Phase 1 rewrites the legacy functions to read
/// the config, so any regression fails here. Pure computation only — no UI — so a
/// later UI rework (#50) can't disturb them.
void main() {
  final t = softwareInterviewsConfig.target;

  group('stabilityTarget (context slot)', () {
    test('mirrors ReadinessTarget.stabilityTarget', () {
      for (final c in CompanyTier.values) {
        final legacy = ReadinessTarget(
          level: SeniorityLevel.mid,
          company: c,
          track: Track.general,
        ).stabilityTarget;
        expect(t.stabilityTargetDays(c.name), legacy,
            reason: 'context ${c.name}');
      }
    });

    test('anchors', () {
      expect(t.stabilityTargetDays('typical'), 90);
      expect(t.stabilityTargetDays('faang'), 120);
    });
  });

  group('tierRelevance (level slot)', () {
    const tiers = <int?>[null, 0, 1, 2, 3, 4, 5, 8];

    test('mirrors tierRelevance() across every level × tier', () {
      for (final level in SeniorityLevel.values) {
        for (final tier in tiers) {
          expect(
            t.tierRelevance(level.name, tier),
            tierRelevance(level, tier),
            reason: 'level ${level.name}, tier $tier',
          );
        }
      }
    });

    test('anchors', () {
      expect(t.tierRelevance('staff', 1), 1.0);
      expect(t.tierRelevance('senior', 3), 0.90);
      expect(t.tierRelevance('newGrad', 4), 0.15);
      expect(t.tierRelevance('newGrad', 9), 0.15); // deeper than curve → last
      expect(t.tierRelevance('mid', null), 1.0); // untiered → foundational
    });
  });

  group('domainWeight (track slot)', () {
    const domains = [
      'ds-a',
      'dsa',
      'graph-algorithm', // contains 'algorithm'
      'array-data-structure', // contains 'data-structure'
      'system-design',
      'system-design-basics', // contains 'system-design'
      'databases',
      'distributed',
      'networking',
      'concurrency',
      'security',
      'backend',
      'api-design',
      'reliability',
      'frontend', // unmatched → 1.0
      'behavioral', // unmatched → 1.0
      'something-else',
    ];

    test('mirrors domainWeight() across every track × domain', () {
      for (final track in Track.values) {
        final target = ReadinessTarget(
          level: SeniorityLevel.senior,
          company: CompanyTier.faang,
          track: track,
        );
        for (final d in domains) {
          expect(
            t.domainWeight(track.name, d),
            domainWeight(target, d),
            reason: 'track ${track.name}, domain $d',
          );
        }
      }
    });

    test('anchors', () {
      expect(t.domainWeight('backend', 'system-design'), 1.15);
      expect(t.domainWeight('ml', 'databases'), 1.1);
      expect(t.domainWeight('frontend', 'system-design'), 0.9);
      expect(t.domainWeight('frontend', 'ds-a'), 0.7);
      expect(t.domainWeight('mobile', 'ds-a'), 0.85);
      expect(t.domainWeight('general', 'ds-a'), 1.0);
      expect(
          t.domainWeight('backend', 'ds-a'), 1.0); // algo unaffected by backend
      expect(t.domainWeight('backend', 'something-else'), 1.0); // unmatched
    });
  });

  group('ladder + fallback', () {
    test('config level × context reproduces readinessLadder order + labels',
        () {
      final expected = [
        for (final level in t.levels)
          for (final context in t.contexts) (level, context),
      ];
      expect(expected.length, readinessLadder.length);
      for (var i = 0; i < readinessLadder.length; i++) {
        final rung = readinessLadder[i];
        final (level, context) = expected[i];
        expect(level.id, rung.level.name, reason: 'rung $i level');
        expect(context.id, rung.company.name, reason: 'rung $i context');
        expect('${level.label} · ${context.label}', rung.label,
            reason: 'rung $i label');
      }
    });

    test('slot labels match the legacy enum labels', () {
      for (final level in SeniorityLevel.values) {
        expect(t.levelById(level.name).label, level.label);
      }
      for (final c in CompanyTier.values) {
        expect(t.contextById(c.name).label, c.label);
      }
      for (final track in Track.values) {
        expect(t.trackById(track.name).label, track.label);
      }
    });

    test('fallback ids match ReadinessTarget.fallback', () {
      expect(t.fallbackLevelId, ReadinessTarget.fallback.level.name);
      expect(t.fallbackContextId, ReadinessTarget.fallback.company.name);
      expect(t.fallbackTrackId, ReadinessTarget.fallback.track.name);
    });
  });
}
