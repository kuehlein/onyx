import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/readiness_report.dart';
import 'package:onyx/core/ai/weak_area.dart';

void main() {
  const weakRow = DomainReportRow(
    domain: 'system-design',
    name: 'System design',
    coverage: 0.3,
    strength: 0.5,
    score: 0.25,
    transfer: 0.4,
    studied: 3,
    total: 10,
    mocks: 2,
    contested: 1,
    topics: ['Load balancing', 'Caching'],
    concepts: ['consistent-hashing', 'cap-theorem'],
  );

  group('system prompt', () {
    final sys = buildWeakAreaSystem();

    test('frames the three gaps: coverage, retention, transfer', () {
      final up = sys.toUpperCase();
      expect(up, contains('COVERAGE'));
      expect(up, contains('RETENTION'));
      expect(up, contains('TRANSFER'));
      // Names that ONE gap dominates — the drill-down's whole point.
      expect(sys.toLowerCase(), contains('dominates'));
    });

    test('demands actionable next steps and forbids praise-padding', () {
      final low = sys.toLowerCase();
      expect(low, contains('actionable'));
      expect(low, contains('next step'));
      // Task-level, not ego: no praise-padding.
      expect(low, contains('praise'));
      expect(low, contains('task-level'));
    });

    test('judges against the specific target and stays honest', () {
      expect(sys, contains('level × context × track'));
      expect(sys.toLowerCase(), contains('honest'));
      // If actually strong, say so — don't invent weakness.
      expect(sys.toLowerCase(), contains('invent'));
    });
  });

  group('user prompt', () {
    test('embeds the domain, its stats, topics/concepts, target + days', () {
      final u = buildWeakAreaUser(
        weakRow,
        targetLabel: 'Senior · FAANG · General',
        daysToInterview: 30,
        interviewTested: true,
      );
      expect(u, contains('System design'));
      expect(u, contains('25%')); // readiness score
      expect(u, contains('3/10 sections started')); // coverage
      expect(u, contains('50%')); // strength
      expect(u, contains('1 grade(s) the critic disputed')); // contested mocks
      expect(u, contains('Load balancing, Caching')); // topics
      expect(u, contains('consistent-hashing, cap-theorem')); // concepts
      expect(u, contains('Senior · FAANG · General')); // target
      expect(u, contains('Target date in 30 days')); // days left
    });

    test('flags recall-only when this domain has no mock evidence', () {
      // A domain with no proven transfer (no mocks) reads as recall-only for that
      // domain, even if the deck as a whole is interview-tested elsewhere.
      const recallRow = DomainReportRow(
        domain: 'ds-a',
        name: 'DS & A',
        coverage: 0.9,
        strength: 0.8,
        score: 0.72,
        studied: 27,
        total: 30,
        mocks: 0,
        contested: 0,
        topics: ['Binary search'],
      );
      final u = buildWeakAreaUser(
        recallRow,
        targetLabel: 'Senior · FAANG · General',
        interviewTested: true,
      );
      expect(u.toLowerCase(), contains('recall-only'));
      expect(u.toLowerCase(), contains('unproven'));
    });

    test('says when no target date is set', () {
      final u = buildWeakAreaUser(
        weakRow,
        targetLabel: 'Senior · FAANG · General',
        interviewTested: true,
      );
      expect(u, contains('No target date set'));
    });
  });
}
