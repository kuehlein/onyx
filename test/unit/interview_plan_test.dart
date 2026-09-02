import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/interview_plan.dart';
import 'package:onyx/core/readiness/target.dart';

const _base = ReadinessTarget(
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
          '"date":"2026-09-20","domainWeights":{"system-design":1.6,"ds-a":1.0},'
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
      expect(p.domainWeights.containsKey('ds-a'), isFalse); // 0 dropped
      expect(p.domainWeights['x'], 2.0);
      expect(p.date, isNull);
    });

    test('a plan with no company is rejected (null)', () {
      const raw = '<plan>{"role":"SWE","summary":"x"}</plan>';
      expect(parseInterviewPlannerReply(raw).plan, isNull);
    });
  });

  group('InterviewPlan.toGoal', () {
    test('maps into a persistable active PrepGoal', () {
      final plan = InterviewPlan(
        company: 'Google',
        role: 'Senior Backend',
        level: SeniorityLevel.senior,
        tier: CompanyTier.faang,
        track: Track.backend,
        date: DateTime(2026, 9, 20),
        domainWeights: const {'system-design': 1.6},
        conceptWeights: const {'consistent-hashing': 2.0},
        summary: 'plan',
      );
      final g = plan.toGoal('goal-1');
      expect(g.id, 'goal-1');
      expect(g.companyName, 'Google');
      expect(g.tier, CompanyTier.faang);
      expect(g.level, SeniorityLevel.senior);
      expect(g.track, Track.backend);
      expect(g.date, DateTime(2026, 9, 20));
      expect(g.domainWeights['system-design'], 1.6);
      expect(g.conceptWeights['consistent-hashing'], 2.0);
      expect(g.active, isTrue);
      expect(g.notes, 'plan');
    });
  });
}
