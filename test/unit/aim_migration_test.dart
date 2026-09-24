import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/aim_migration.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/template/software_interviews.dart';

/// Phase B (B5): the legacy aim stores (base target + the old `onyx-goals.json`
/// PrepGoal array) fold into the whole-vault default Deck losing nothing —
/// slots/deadline + each interview. The user's real vault has legacy data, so the
/// `legacyInterviewsFromRaw` parse (guarded here) must stay correct.
void main() {
  group('legacyInterviewsFromRaw', () {
    test('maps a legacy onyx-goals.json array into InterviewAims', () {
      // The old PrepGoal.toJson shape: tier/level/track are DROPPED (interviews
      // share the goal's slots); rounds carry over; `notes` → planNotes.
      const raw = '[{"id":"g1","companyName":"Google","tier":"faang",'
          '"level":"senior","track":"backend","active":false,'
          '"domainWeights":{"system-design":1.3},'
          '"conceptWeights":{"consistent-hashing":2.0},'
          '"outcome":"passed","outcomeNotes":"strong","notes":"plan text",'
          '"status":"offer","rounds":[{"id":"g1-r1","number":1,'
          '"type":"systemDesign","date":"2026-05-15","outcome":"passed"}]}]';
      final aims = legacyInterviewsFromRaw(raw);

      expect(aims.length, 1);
      final iv = aims.single;
      expect(iv.id, 'g1');
      expect(iv.companyName, 'Google');
      expect(iv.active, isFalse);
      expect(iv.status, InterviewStatus.offer);
      expect(iv.outcome, AimOutcome.passed);
      expect(iv.outcomeNotes, 'strong');
      expect(iv.domainWeights['system-design'], 1.3);
      expect(iv.conceptWeights['consistent-hashing'], 2.0);
      // legacy 'notes' → planNotes.
      expect(iv.planNotes, 'plan text');
      // Stored rounds carry over verbatim.
      expect(iv.rounds.single.type, InterviewRoundType.systemDesign);
      expect(iv.rounds.single.date, DateTime(2026, 5, 15));
    });

    test('synthesizes round 1 from a single date when no rounds are stored',
        () {
      const raw = '[{"id":"g2","companyName":"Amazon","date":"2026-06-01",'
          '"active":true,"status":"active"}]';
      final iv = legacyInterviewsFromRaw(raw).single;
      expect(iv.rounds.length, 1);
      expect(iv.rounds.single.id, 'g2-r1');
      expect(iv.rounds.single.number, 1);
      expect(iv.rounds.single.date, DateTime(2026, 6, 1));
    });

    test('drops entries with no id; tolerates junk / non-list', () {
      const raw = '[{"companyName":"NoId"},{"id":"","companyName":"Empty"},'
          '{"id":"ok","companyName":"Kept"}]';
      final aims = legacyInterviewsFromRaw(raw);
      expect(aims.map((a) => a.id), ['ok']);

      expect(legacyInterviewsFromRaw('not json'), isEmpty);
      expect(legacyInterviewsFromRaw('{"not":"a list"}'), isEmpty);
      expect(legacyInterviewsFromRaw(null), isEmpty);
      expect(legacyInterviewsFromRaw(''), isEmpty);
    });
  });

  group('migratedDefaultDeck', () {
    test(
        'folds the base target into the interview aims (deck carries no slots)',
        () {
      final base = ReadinessTarget.of(
        level: SeniorityLevel.senior,
        company: CompanyTier.faang,
        track: Track.backend,
        interviewDate: DateTime(2026, 6, 1),
      );
      final interviews = legacyInterviewsFromRaw(
        '[{"id":"g1","companyName":"Google","tier":"faang","level":"senior",'
        '"track":"backend","date":"2026-05-15","active":false,'
        '"domainWeights":{"system-design":1.3},"status":"active"}]',
      );

      final goal = migratedDefaultDeck(softwareInterviewsTemplate,
          baseTarget: base, aims: interviews);
      expect(goal.id, defaultDeckId);

      // The base target's slots fold into the interview aim (S5 — the deck is a
      // pure lens; no separate 'target' aim, since there IS an interview).
      expect(goal.aims.length, 1);
      final iv = goal.aims.single;
      expect(iv.companyName, 'Google');
      expect(iv.active, isFalse);
      expect(iv.domainWeights['system-design'], 1.3);
      expect([iv.levelId, iv.contextId, iv.trackId],
          ['senior', 'faang', 'backend']); // inherited from the base target
      // The interview keeps its OWN round date (its rounds aren't empty, so the
      // base deadline doesn't synthesize one).
      expect(iv.rounds.single.date, DateTime(2026, 5, 15));
    });

    test('a base target with no interviews → one coverage `target` aim', () {
      final base = ReadinessTarget.of(
        level: SeniorityLevel.senior,
        company: CompanyTier.faang,
        track: Track.general,
        interviewDate: DateTime(2026, 6, 1),
      );
      final goal =
          migratedDefaultDeck(softwareInterviewsTemplate, baseTarget: base);
      final iv = goal.aims.single;
      expect(iv.id, 'target');
      expect([iv.levelId, iv.contextId, iv.trackId],
          ['senior', 'faang', 'general']);
      expect(iv.rounds.single.date, DateTime(2026, 6, 1));
    });

    test('no legacy data → a bare default goal (template fallbacks stand)', () {
      final bare = migratedDefaultDeck(softwareInterviewsTemplate);
      expect(bare.aims, isEmpty);
    });
  });

  group('foldSlotsIntoAims (S5 parse-time migration)', () {
    test('no slots + no deadline → the aim list is returned unchanged', () {
      const aims = [Aim(id: 'a')];
      expect(identical(foldSlotsIntoAims(aims, deckId: 'd'), aims), isTrue);
    });

    test('an aim inherits the deck slots explicitly (byte-identical)', () {
      final f = foldSlotsIntoAims(
        const [Aim(id: 'a')],
        levelId: 'senior',
        contextId: 'faang',
        trackId: 'backend',
        deckId: 'd',
      );
      final a = f.single;
      expect(
          [a.levelId, a.contextId, a.trackId], ['senior', 'faang', 'backend']);
      expect(a.rounds, isEmpty); // no deadline → no synthetic round
    });

    test('a round-less aim gets the deck deadline as an explicit round 1', () {
      final f = foldSlotsIntoAims(
        const [Aim(id: 'a')],
        levelId: 'senior',
        deadline: DateTime(2026, 6, 1),
        deckId: 'd',
      );
      final r = f.single.rounds.single;
      expect(r.id, 'a-r1');
      expect(r.number, 1);
      expect(r.date, DateTime(2026, 6, 1));
    });

    test('slots with NO aims become one coverage `target` aim', () {
      final f = foldSlotsIntoAims(
        const [],
        levelId: 'senior',
        contextId: 'faang',
        trackId: 'backend',
        deadline: DateTime(2026, 6, 1),
        deckId: 'd',
      );
      expect(f.length, 1);
      final a = f.single;
      expect(a.id, 'target');
      expect(
          [a.levelId, a.contextId, a.trackId], ['senior', 'faang', 'backend']);
      expect(a.rounds.single.date, DateTime(2026, 6, 1));
    });

    test('an aim keeps its OWN slots; only null-slot aims inherit', () {
      final f = foldSlotsIntoAims(
        const [Aim(id: 'a', levelId: 'staff'), Aim(id: 'b')],
        levelId: 'senior',
        deckId: 'd',
      );
      expect(f[0].levelId, 'staff'); // its own, untouched
      expect(f[1].levelId, 'senior'); // inherited from the deck
    });

    test('idempotent — re-folding does not duplicate the round', () {
      final once = foldSlotsIntoAims(
        const [Aim(id: 'a')],
        levelId: 'senior',
        deadline: DateTime(2026, 6, 1),
        deckId: 'd',
      );
      final twice = foldSlotsIntoAims(once,
          levelId: 'senior', deadline: DateTime(2026, 6, 1), deckId: 'd');
      expect(twice.single.rounds.length, 1); // round not duplicated
      expect(twice.single.levelId, 'senior');
    });

    test(
        're-parsing an already-folded deck (residual slots + `target` aim) does '
        'not duplicate it', () {
      // The post-S5a on-disk shape: the JSON kept the slot keys AND the `target`
      // aim they were folded into. Re-folding must not create a second one.
      final f = foldSlotsIntoAims(
        const [
          Aim(
              id: 'target',
              levelId: 'senior',
              contextId: 'faang',
              trackId: 'general')
        ],
        levelId: 'senior',
        contextId: 'faang',
        trackId: 'general',
        deckId: 'default',
      );
      expect(f.length, 1); // no duplicate 'target'
      expect(f.single.id, 'target');
    });
  });
}
