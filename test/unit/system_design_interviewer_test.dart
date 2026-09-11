import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/system_design_interviewer.dart';
import 'package:onyx/core/interview/system_design_grader.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/shared/models/card.dart';

Card _card() => const Card(
      id: 'design-rate-limiter',
      type: CardType.systemDesign,
      title: 'Design a Rate Limiter',
      overview: 'Cap request rate fairly. SECRET_GROUND_TRUTH_MARKER',
      tags: ['system-design'],
      tiers: {'system-design': 2},
      sections: [
        CardSection(
            heading: 'Deep Dives',
            slug: 'deep-dives',
            content: 'Token bucket vs sliding window.',
            quizzable: false),
      ],
      wikilinks: [],
      filePath: 'design-rate-limiter.md',
    );

void main() {
  group('buildSystemDesignInterviewerSystem', () {
    test('embeds the problem, ground truth, and the anti-sycophancy rule', () {
      final p = buildSystemDesignInterviewerSystem(
        card: _card(),
        level: SeniorityLevel.senior,
        company: CompanyTier.faang,
      );
      expect(p, contains('Design a Rate Limiter'));
      expect(p, contains('SECRET_GROUND_TRUTH_MARKER'));
      expect(p, contains('NEVER reveal'));
      expect(p, contains('ANTI-SYCOPHANCY'));
      expect(p, contains('detailed-but-wrong reasoning is still wrong'));
      expect(p, contains('speech-to-text'));
      expect(p, contains('Senior'));
    });

    test('calibration differs by level (drive inversely with seniority)', () {
      final mid = buildSystemDesignInterviewerSystem(
          card: _card(), level: SeniorityLevel.mid, company: CompanyTier.faang);
      final staff = buildSystemDesignInterviewerSystem(
          card: _card(),
          level: SeniorityLevel.staff,
          company: CompanyTier.faang);
      expect(mid, contains('YOU set direction and pace'));
      expect(staff, contains('treat them as a peer'));
      expect(mid, isNot(contains('barely steer')));
    });
  });

  group('systemDesignOpeningLine', () {
    test('is terse and does not leak the requirements/ground truth', () {
      final line = systemDesignOpeningLine(_card());
      expect(line, contains('design a Rate Limiter'));
      expect(line, isNot(contains('SECRET_GROUND_TRUTH_MARKER')));
      expect(line.length, lessThan(160));
    });
  });

  group('support mode', () {
    test('coaching invites stepping in; realistic is hands-off', () {
      final coaching = buildSystemDesignInterviewerSystem(
        card: _card(),
        level: SeniorityLevel.mid,
        company: CompanyTier.faang,
        support: SdSupportMode.coaching,
      );
      final realistic = buildSystemDesignInterviewerSystem(
        card: _card(),
        level: SeniorityLevel.mid,
        company: CompanyTier.faang,
        support: SdSupportMode.realistic,
      );
      expect(coaching, contains('COACHING mode'));
      expect(coaching, contains('STEP IN'));
      expect(realistic, contains('REALISTIC mode'));
      expect(realistic, contains('hands-off'));
    });
  });

  group('buildSystemDesignTutorSystem', () {
    test('drops the act and may use the reference solution', () {
      final t = buildSystemDesignTutorSystem(
          card: _card(), level: SeniorityLevel.senior);
      expect(t, contains('drop the interviewer act'));
      expect(t, contains('reference solution'));
      // The tutor is allowed to see the ground truth (teaching).
      expect(t, contains('SECRET_GROUND_TRUTH_MARKER'));
    });
  });

  group('buildSdGraderSystem (adversarial)', () {
    test('is skeptical, level-calibrated, and asks for the SD rubric', () {
      final g = buildSdGraderSystem(card: _card(), level: SeniorityLevel.staff);
      expect(g, contains('skeptical'));
      expect(g, contains('too lenient'));
      expect(g, contains('detailed-but-wrong is still wrong'));
      expect(g, contains('Staff-level bar'));
      expect(g, contains('tradeoffReasoning'));
      expect(g, contains('<grade>'));
    });
  });

  group('parseSdGrade', () {
    test('parses the tagged verdict with rubric', () {
      final v = parseSdGrade(
          'noise <grade>{"appliedScore":72,"rubric":{"requirements":4,'
          '"estimation":3,"deepDive":2},"note":"solid but shallow deep dive"}'
          '</grade> trailing');
      expect(v, isNotNull);
      expect(v!.appliedScore, 72);
      expect(v.rubric['requirements'], 4);
      expect(v.rubric['deepDive'], 2);
      expect(v.note, contains('shallow'));
    });

    test('clamps out-of-range values and ignores unknown dims', () {
      final v = parseSdGrade(
          '<grade>{"appliedScore":140,"rubric":{"estimation":9,"bogus":5}}'
          '</grade>');
      expect(v!.appliedScore, 100);
      expect(v.rubric['estimation'], 5);
      expect(v.rubric.containsKey('bogus'), isFalse);
    });

    test('returns null on unparseable input', () {
      expect(parseSdGrade('no grade here'), isNull);
    });
  });

  group('reconcilePanel01', () {
    SdGrade g(int s) => SdGrade(appliedScore: s);
    test('takes the median of a panel', () {
      expect(reconcilePanel01([g(40), g(60), g(80)]), closeTo(0.60, 1e-9));
      expect(reconcilePanel01([g(40), g(60)]), closeTo(0.50, 1e-9));
      expect(reconcilePanel01([g(70)]), closeTo(0.70, 1e-9));
    });
    test('returns null for an empty panel', () {
      expect(reconcilePanel01(const []), isNull);
    });
  });
}
