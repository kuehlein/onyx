import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/ladder.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/template/deck_template.dart';

/// Golden tests for task #30: the SWE reference [softwareInterviewsTemplate] locks
/// the readiness math + flow definitions. The app reads from this config, so
/// these assert against **literal snapshots** (independent of the implementation)
/// — a regression in either the config values or the resolution logic fails here.
/// Pure computation only, no UI, so a later UI rework (#50) can't disturb them.
void main() {
  final t = softwareInterviewsTemplate.target;

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

  group('ladder + labels + fallback', () {
    test('readinessLadder is the 8 SWE rungs, level-major, in order', () {
      const expected = [
        ('newGrad', 'typical', 'New-grad · Typical'),
        ('newGrad', 'faang', 'New-grad · FAANG'),
        ('mid', 'typical', 'Mid · Typical'),
        ('mid', 'faang', 'Mid · FAANG'),
        ('senior', 'typical', 'Senior · Typical'),
        ('senior', 'faang', 'Senior · FAANG'),
        ('staff', 'typical', 'Staff · Typical'),
        ('staff', 'faang', 'Staff · FAANG'),
      ];
      expect(readinessLadder.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        final (levelId, contextId, label) = expected[i];
        expect(readinessLadder[i].levelId, levelId, reason: 'rung $i level');
        expect(readinessLadder[i].contextId, contextId, reason: 'rung $i ctx');
        expect(readinessLadder[i].label, label, reason: 'rung $i label');
      }
    });

    test('slot labels (literal snapshot)', () {
      expect(t.levelById('newGrad').label, 'New-grad');
      expect(t.levelById('staff').label, 'Staff');
      expect(t.contextById('faang').label, 'FAANG');
      expect(t.trackById('backend').label, 'Backend');
      expect(t.trackById('fullStack').label, 'Full-stack');
    });

    test('fallback is mid · faang · general', () {
      expect(t.fallbackLevelId, 'mid');
      expect(t.fallbackContextId, 'faang');
      expect(t.fallbackTrackId, 'general');
      expect(ReadinessTarget.fallback.levelId, 'mid');
      expect(ReadinessTarget.fallback.contextId, 'faang');
      expect(ReadinessTarget.fallback.trackId, 'general');
    });
  });

  group('flows (Phase 3) → scheduling + quizzability per card type', () {
    const expected = {
      'flashcard': (SchedulingModel.recall, QuizzabilityPolicy.blocklist),
      'interview-question': (
        SchedulingModel.recall,
        QuizzabilityPolicy.approachOnly
      ),
      'algorithm': (SchedulingModel.twoClock, QuizzabilityPolicy.allSections),
      'system-design': (SchedulingModel.mock, QuizzabilityPolicy.noSections),
      'behavioral': (SchedulingModel.mock, QuizzabilityPolicy.noSections),
    };

    test('literal snapshot per card type', () {
      expected.forEach((cardType, spec) {
        final flow = softwareInterviewsTemplate.flowForType(cardType);
        expect(flow, isNotNull, reason: cardType);
        final (scheduling, quizzability) = spec;
        expect(flow!.scheduling, scheduling, reason: '$cardType scheduling');
        expect(flow.quizzability, quizzability,
            reason: '$cardType quizzability');
      });
    });

    test('unknown card type has no flow (caller falls back)', () {
      expect(softwareInterviewsTemplate.flowForType('nonexistent'), isNull);
    });

    test('prereq source: SD gates on `## Related` wikilinks, others depends-on',
        () {
      // The daily plan dispatches prerequisite gating on this (not a `type ==`
      // branch — invariant #2).
      for (final cardType in expected.keys) {
        expect(
          softwareInterviewsTemplate.flowForType(cardType)!.prereqSource,
          cardType == 'system-design'
              ? PrereqSource.wikilinks
              : PrereqSource.dependsOn,
          reason: cardType,
        );
      }
    });
  });

  group('vocabulary (G3) → per-subject assessment terminology', () {
    test('SWE reference keeps "interviewer" so its shared copy is unchanged',
        () {
      final v = softwareInterviewsTemplate.vocabulary;
      expect(v.examinerNoun, 'interviewer');
      expect(v.examinerNounTitle, 'Interviewer');
      // G7: SWE also declares the assessment event so Home/readiness copy is
      // byte-identical ("interview target", "Interview readiness", …).
      expect(v.assessmentNoun, 'interview');
      expect(v.assessmentNounTitle, 'Interview');
      expect(v.hasAssessment, isTrue);
      // S5e-2: SWE overrides the aim-editor axis titles so its copy reads the
      // familiar Level / Company / Track (not the neutral defaults below).
      expect(v.levelAxisTitle, 'Level');
      expect(v.contextAxisTitle, 'Company');
      expect(v.trackAxisTitle, 'Track');
    });

    test('a subject that declares no vocabulary gets the neutral default', () {
      const bare = DeckTemplate(id: 'x', target: _emptyTarget);
      expect(bare.vocabulary, same(Vocabulary.neutral));
      expect(bare.vocabulary.examinerNoun, 'examiner');
      expect(bare.vocabulary.examinerNounTitle, 'Examiner');
      // G7: neutral subject has no assessment framing → gate stays off.
      expect(bare.vocabulary.assessmentNoun, isNull);
      expect(bare.vocabulary.assessmentNounTitle, isNull);
      expect(bare.vocabulary.hasAssessment, isFalse);
      // S5e-2: the neutral aim-editor axis titles are subject-agnostic.
      expect(bare.vocabulary.levelAxisTitle, 'Difficulty');
      expect(bare.vocabulary.contextAxisTitle, 'Durability');
      expect(bare.vocabulary.trackAxisTitle, 'Emphasis');
    });

    test('title-casing is safe for an empty noun', () {
      expect(const Vocabulary(examinerNoun: '').examinerNounTitle, '');
    });
  });

  group('parse profile (G4) → default reproduces the built-in parser', () {
    test('SWE reference uses the standard profile (parses identically)', () {
      expect(
          softwareInterviewsTemplate.parseProfile, same(ParseProfile.standard));
    });

    test('standard defaults: H2 · .md · wikilinks on · default blocklist', () {
      const p = ParseProfile.standard;
      expect(p.sectionHeadingLevel, 2);
      expect(p.fileExtensions, {'md'});
      expect(p.wikilinks, isTrue);
      expect(p.neverQuizzed, isNull); // null → engine's built-in blocklist
    });

    test('a bare subject gets the standard profile', () {
      const bare = DeckTemplate(id: 'x', target: _emptyTarget);
      expect(bare.parseProfile, same(ParseProfile.standard));
    });
  });
}

/// A minimal target for constructing a bare [DeckTemplate] in the vocabulary
/// default test — its values are irrelevant there.
const _emptyTarget = TargetSpec(
  levels: [
    LevelValue(id: 'l', label: 'L', tierCurve: [1.0])
  ],
  contexts: [ContextValue(id: 'c', label: 'C', stabilityTargetDays: 90)],
  tracks: [TrackValue(id: 't', label: 'T')],
  families: [],
  fallbackLevelId: 'l',
  fallbackContextId: 'c',
  fallbackTrackId: 't',
);
