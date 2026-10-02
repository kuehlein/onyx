import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/srs/recognition.dart';
import 'package:onyx/core/srs/srs_scheduler.dart';
import 'package:onyx/core/srs/study_scheduler.dart';
import 'package:onyx/core/srs/study_state.dart';

/// The per-kind scheduler registry (ADR-0024 §3). Pure — no DB.
void main() {
  group('studySchedulerFor registry', () {
    test('maps each kind to its scheduling model', () {
      final recall = studySchedulerFor(StudyKind.recall);
      expect(recall, isA<RecallScheduler>());
      expect(recall.kind, StudyKind.recall);

      final practice = studySchedulerFor(StudyKind.practice);
      expect(practice, isA<PracticeScheduler>());
      expect(practice.kind, StudyKind.practice);
    });

    test('RecallScheduler is a drop-in SrsScheduler (FSRS review works)', () {
      final sched = RecallScheduler();
      expect(sched, isA<SrsScheduler>());
      final out = sched.review(grade: 3, reviewedAt: DateTime.utc(2026, 1, 1));
      expect(out.stability, greaterThan(0));
      expect(out.due.isAfter(DateTime.utc(2026, 1, 1)), isTrue);
    });

    test('PracticeScheduler.schedule matches scheduleRecognition exactly', () {
      final now = DateTime(2026, 9, 5);
      for (final outcome in ExplainOutcome.values) {
        final viaRegistry = const PracticeScheduler()
            .schedule(outcome: outcome, now: now, priorStreak: 2);
        final direct =
            scheduleRecognition(outcome: outcome, now: now, priorStreak: 2);
        expect(viaRegistry.intervalDays, direct.intervalDays);
        expect(viaRegistry.streak, direct.streak);
        expect(viaRegistry.dueAt, direct.dueAt);
      }
    });
  });
}
