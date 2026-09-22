import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/interview_plan.dart';
import 'package:onyx/core/deck/aim.dart';
import 'package:onyx/core/readiness/target.dart';

final _base = ReadinessTarget.of(
  level: SeniorityLevel.senior,
  company: CompanyTier.faang,
  track: Track.general,
);

void main() {
  group('planner system prompt', () {
    final sys = buildInterviewPlannerSystem(
      deckDomains: ['ds-a', 'system-design'],
      deckConcepts: ['consistent-hashing'],
      base: _base,
      today: DateTime(2026, 9, 9),
    );
    test('lists the deck keys and the base aim so weights actually apply', () {
      expect(sys, contains('ds-a, system-design'));
      expect(sys, contains('consistent-hashing'));
      expect(sys, contains('Senior · FAANG · General'));
    });
    test('demands clarifying questions, advisory framing, and the plan block',
        () {
      expect(sys.toLowerCase(), contains('clarifying question'));
      expect(sys.toUpperCase(), contains('ADVISORY'));
      expect(sys, contains('<plan>'));
      expect(sys, contains('missingConcepts'));
      expect(sys, contains('appGaps'));
    });
  });

  group('parseInterviewPlannerReply', () {
    test('a reply with no plan block → just text, null plan', () {
      final r = parseInterviewPlannerReply(
          "I don't know that company — what role did you apply for?");
      expect(r.plan, isNull);
      expect(r.text, contains('what role'));
    });

    test('extracts + parses the plan, strips the tag from the shown text', () {
      const raw = 'Here is your plan — behavioral is on you.\n'
          '<plan>{"company":"Google","role":"Senior Backend, Maps",'
          '"level":"senior","tier":"faang","track":"backend",'
          '"date":"2026-09-20","roundType":"systemDesign",'
          '"domainWeights":{"system-design":1.6,"ds-a":1.0},'
          '"conceptWeights":{"consistent-hashing":2.0},'
          '"missingConcepts":["rate limiting"],"appGaps":["behavioral"],'
          '"summary":"Focus system design."}</plan>';
      final r = parseInterviewPlannerReply(raw);
      expect(r.text, 'Here is your plan — behavioral is on you.');
      expect(r.text, isNot(contains('<plan>')));
      final p = r.plan!;
      expect(p.company, 'Google');
      expect(p.role, 'Senior Backend, Maps');
      expect(p.level, SeniorityLevel.senior);
      expect(p.tier, CompanyTier.faang);
      expect(p.track, Track.backend);
      expect(p.date, DateTime(2026, 9, 20));
      expect(p.roundType, InterviewRoundType.systemDesign);
      expect(p.domainWeights['system-design'], 1.6);
      expect(p.conceptWeights['consistent-hashing'], 2.0);
      expect(p.missingConcepts, ['rate limiting']);
      expect(p.appGaps, ['behavioral']);
      expect(p.summary, 'Focus system design.');
    });

    test('tolerates junk / unknown enums; drops non-positive weights', () {
      const raw = '<plan>{"company":"Foo","role":"SRE","level":"wizard",'
          '"tier":"???","track":"quantum","domainWeights":{"ds-a":0,"x":2},'
          '"summary":"hi"}</plan>';
      final p = parseInterviewPlannerReply(raw).plan!;
      expect(p.company, 'Foo');
      expect(p.level, SeniorityLevel.mid); // fallback
      expect(p.tier, CompanyTier.typical); // fallback
      expect(p.track, Track.general); // fallback
      expect(p.roundType, InterviewRoundType.screen); // fallback
      expect(p.domainWeights.containsKey('ds-a'), isFalse); // 0 dropped
      expect(p.domainWeights['x'], 2.0);
      expect(p.date, isNull);
    });

    test('a plan with no company is rejected (null)', () {
      const raw = '<plan>{"role":"SWE","summary":"x"}</plan>';
      expect(parseInterviewPlannerReply(raw).plan, isNull);
    });
  });

  group('InterviewPlan.toInterview', () {
    test('maps into a persistable active Aim', () {
      final plan = InterviewPlan(
        company: 'Google',
        role: 'Senior Backend',
        level: SeniorityLevel.senior,
        tier: CompanyTier.faang,
        track: Track.backend,
        date: DateTime(2026, 9, 20),
        roundType: InterviewRoundType.systemDesign,
        domainWeights: const {'system-design': 1.6},
        conceptWeights: const {'consistent-hashing': 2.0},
        summary: 'plan',
      );
      final iv = plan.toInterview('goal-1');
      expect(iv.id, 'goal-1');
      expect(iv.companyName, 'Google');
      expect(iv.domainWeights['system-design'], 1.6);
      expect(iv.conceptWeights['consistent-hashing'], 2.0);
      expect(iv.active, isTrue);
      expect(iv.planNotes, 'plan');
      // The target (level/tier/track/date) lives on the parent goal now; the aim
      // seeds round 1 with the inferred type + date.
      expect(iv.rounds.length, 1);
      expect(iv.rounds.first.id, 'goal-1-r1');
      expect(iv.rounds.first.number, 1);
      expect(iv.rounds.first.type, InterviewRoundType.systemDesign);
      expect(iv.rounds.first.date, DateTime(2026, 9, 20));
    });

    test('drops a past date (wrong-year slip) via notBefore', () {
      final plan = InterviewPlan(
        company: 'Google',
        role: 'Senior Backend',
        level: SeniorityLevel.senior,
        tier: CompanyTier.faang,
        track: Track.backend,
        date: DateTime(2024, 9, 20), // wrong year → in the past
      );
      final iv = plan.toInterview('goal-1', notBefore: DateTime(2026, 9, 9));
      expect(iv.rounds.single.date, isNull);
    });

    test('keeps a future date under notBefore', () {
      final plan = InterviewPlan(
        company: 'Google',
        role: 'Senior Backend',
        level: SeniorityLevel.senior,
        tier: CompanyTier.faang,
        track: Track.backend,
        date: DateTime(2026, 10, 20),
      );
      final iv = plan.toInterview('goal-1', notBefore: DateTime(2026, 9, 9));
      expect(iv.rounds.single.date, DateTime(2026, 10, 20));
    });
  });
}
