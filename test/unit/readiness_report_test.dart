import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/readiness_report.dart';

void main() {
  ReadinessReportData data({bool interviewTested = true, int? days}) =>
      ReadinessReportData(
        targetLabel: 'Senior · FAANG · General',
        level: 'Senior',
        company: 'FAANG',
        track: 'General',
        overall: 0.42,
        low: 0.30,
        high: 0.54,
        interviewTested: interviewTested,
        daysToInterview: days,
        domains: [
          const DomainReportRow(
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
          ),
          const DomainReportRow(
            name: 'DS & A',
            coverage: 0.9,
            strength: 0.8,
            score: 0.72,
            studied: 27,
            total: 30,
            mocks: 0,
            contested: 0,
            topics: ['Binary search', 'Hash map'],
          ),
        ],
      );

  group('system prompt', () {
    final sys = buildReadinessReportSystem();
    test('demands honesty and target-specific judgement', () {
      expect(sys.toLowerCase(), contains('honest'));
      expect(sys, contains('level × company × track'));
    });
    test('leads with LEARNING gaps and keeps CONTENT gaps soft/secondary', () {
      expect(sys.toUpperCase(), contains('LEARNING GAP'));
      expect(sys.toUpperCase(), contains('APPLIED TRANSFER'));
      // Content/missing-card gaps are explicitly secondary + soft (the deck is
      // still being built), not the headline.
      expect(sys.toUpperCase(), contains('CONTENT'));
      expect(sys.toLowerCase(), contains('secondary'));
      expect(sys.toLowerCase(), contains('still being built'));
      // Asks for the four narrative sections.
      for (final s in ['Verdict', 'Strengths', 'Gaps', 'Do next']) {
        expect(sys, contains(s));
      }
    });
  });

  group('user prompt', () {
    test('embeds the target, band, per-domain numbers and deck topics', () {
      final u = buildReadinessReportUser(data(days: 30));
      expect(u, contains('Senior · FAANG · General'));
      expect(u, contains('Interview in 30 days'));
      expect(u, contains('42%')); // overall
      expect(u, contains('30–54%')); // band
      // Weakest domain first, with its coverage + mock evidence + scope topics.
      expect(u.indexOf('System design'), lessThan(u.indexOf('DS & A')));
      expect(u, contains('3/10 sections started'));
      expect(u, contains('Load balancing, Caching'));
      expect(u, contains('1 grade(s) the critic disputed'));
      // Finer concepts are surfaced so the model reasons about learning coverage.
      expect(u, contains('consistent-hashing, cap-theorem'));
    });

    test('flags recall-only (unproven) when there is no mock evidence', () {
      final u = buildReadinessReportUser(data(interviewTested: false));
      expect(u.toLowerCase(), contains('recall-only'));
      expect(u.toLowerCase(), contains('unproven'));
    });

    test('says when no interview date is set', () {
      final u = buildReadinessReportUser(data());
      expect(u, contains('No interview date set'));
    });
  });
}
