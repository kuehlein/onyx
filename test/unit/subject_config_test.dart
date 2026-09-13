import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/ladder.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/subject/software_interviews.dart';

/// Golden tests for task #30: the SWE reference [softwareInterviewsConfig] locks
/// the readiness math. Phase 1 rewired target.dart to READ from this config, so
/// these assert against **literal snapshots** (independent of the implementation)
/// rather than cross-checking the now-delegating functions — a regression in
/// either the config values or the resolution logic fails here. Pure computation
/// only, no UI, so a later UI rework (#50) can't disturb them.
///
/// The ladder/label/fallback checks still cross-check the not-yet-migrated
/// enum-based ladder.dart/target.dart (those migrate to config in Phase 2).
void main() {
  final t = softwareInterviewsConfig.target;

  group('context slot → stability bar', () {
    test('literal snapshot', () {
      expect(t.stabilityTargetDays('typical'), 90);
      expect(t.stabilityTargetDays('faang'), 120);
    });
  });

  group('level slot → tier-relevance curves', () {
    // index i → tier (i+1); last entry applies to that tier and deeper.
    const curves = {
      'newGrad': [1.0, 0.7, 0.35, 0.15],
      'mid': [1.0, 0.9, 0.55, 0.30],
      'senior': [1.0, 1.0, 0.90, 0.50],
      'staff': [1.0, 1.0, 1.00, 0.65],
    };

    test('literal snapshot across every level × tier', () {
      curves.forEach((level, curve) {
        for (var tier = 1; tier <= 6; tier++) {
          final want = curve[(tier - 1).clamp(0, curve.length - 1)];
          expect(t.tierRelevance(level, tier), want,
              reason: '$level tier $tier');
        }
        // untiered / non-positive → foundational (1.0).
        expect(t.tierRelevance(level, null), 1.0, reason: '$level null');
        expect(t.tierRelevance(level, 0), 1.0, reason: '$level 0');
      });
    });
  });

  group('track slot → domain weights', () {
    // [algo multiplier, systems-backend multiplier] per track.
    const weights = {
      'general': [1.0, 1.0],
      'backend': [1.0, 1.15],
      'frontend': [0.7, 0.9],
      'fullStack': [1.0, 1.0],
      'ml': [1.0, 1.1],
      'mobile': [0.85, 1.0],
    };

    test('literal snapshot per track (algo vs systems-backend families)', () {
      weights.forEach((track, w) {
        expect(t.domainWeight(track, 'ds-a'), w[0], reason: '$track algo');
        expect(t.domainWeight(track, 'system-design'), w[1],
            reason: '$track systems');
        expect(t.domainWeight(track, 'totally-unmatched'), 1.0,
            reason: '$track unmatched');
      });
    });

    test('family matchers (exact + substring)', () {
      // algo family: exact {ds-a, dsa} + contains {algorithm, data-structure}
      expect(t.domainWeight('frontend', 'dsa'), 0.7);
      expect(t.domainWeight('frontend', 'graph-algorithm'), 0.7);
      expect(t.domainWeight('frontend', 'array-data-structure'), 0.7);
      // systems-backend: several exact keys + contains {system-design}
      expect(t.domainWeight('backend', 'databases'), 1.15);
      expect(t.domainWeight('backend', 'distributed'), 1.15);
      expect(t.domainWeight('backend', 'system-design-basics'), 1.15);
      // algo is checked before systems-backend (declared order).
      expect(t.domainWeight('backend', 'ds-a'), 1.0);
    });
  });

  group('ladder + labels + fallback (cross-check pre-Phase-2)', () {
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
