import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/interview_debrief.dart';
import 'package:onyx/core/readiness/prep_goal.dart';
import 'package:onyx/core/readiness/target.dart';

PrepGoal _goal() => const PrepGoal(
      id: 'g1',
      companyName: 'Google',
      tier: CompanyTier.faang,
      level: SeniorityLevel.senior,
      track: Track.backend,
      domainWeights: {'ds-a': 1.5, 'system-design': 1.2},
      conceptWeights: {'graphs': 1.5},
      notes: 'Original plan notes.',
    );

void main() {
  group('buildDebriefSystem', () {
    test('seeds the goal label and the deck keys', () {
      final s = buildDebriefSystem(
        goal: _goal(),
        deckDomains: ['ds-a', 'system-design'],
        deckConcepts: ['graphs', 'dynamic-programming'],
      );
      expect(s, contains('Google · Senior · Backend'));
      expect(s, contains('dynamic-programming'));
      expect(s, contains('<debrief>'));
    });
  });

  group('parseDebriefReply', () {
    test('splits shown text from the debrief block', () {
      final r = parseDebriefReply(
        'Sounds like DP tripped you up.\n'
        '<debrief>{"outcome":"failed","domainWeights":{"ds-a":2.0},'
        '"conceptWeights":{"dynamic-programming":2.5},'
        '"summary":"Lean into DP for a while."}</debrief>',
      );
      expect(r.text, 'Sounds like DP tripped you up.');
      expect(r.text, isNot(contains('debrief')));
      expect(r.result, isNotNull);
      expect(r.result!.outcome, GoalOutcome.failed);
      expect(r.result!.domainWeights, {'ds-a': 2.0});
      expect(r.result!.conceptWeights, {'dynamic-programming': 2.5});
      expect(r.result!.summary, 'Lean into DP for a while.');
    });

    test('no block → null result, unchanged text', () {
      final r = parseDebriefReply('So how did the coding round feel?');
      expect(r.result, isNull);
      expect(r.text, 'So how did the coding round feel?');
    });

    test('malformed JSON → null result, tag still stripped', () {
      final r = parseDebriefReply('Text <debrief>not json</debrief>');
      expect(r.result, isNull);
      expect(r.text, 'Text');
    });

    test('"unknown" outcome and junk weights are dropped', () {
      final r = parseDebriefReply(
        '<debrief>{"outcome":"unknown","domainWeights":{"ds-a":-1,"ok":2},'
        '"summary":""}</debrief>',
      );
      expect(r.result!.outcome, isNull);
      expect(r.result!.domainWeights, {'ok': 2.0}); // negative dropped
    });
  });

  group('DebriefResult.applyTo', () {
    test('merges reweights, sets the outcome, and appends the summary', () {
      const result = DebriefResult(
        outcome: GoalOutcome.failed,
        domainWeights: {'ds-a': 2.0, 'behavioral': 1.3},
        conceptWeights: {'dynamic-programming': 2.5},
        summary: 'Drill DP; graphs are solid.',
      );
      final updated = result.applyTo(_goal());

      expect(updated.outcome, GoalOutcome.failed);
      // New key overrides / adds; untouched keys survive.
      expect(updated.domainWeights['ds-a'], 2.0);
      expect(updated.domainWeights['behavioral'], 1.3);
      expect(updated.domainWeights['system-design'], 1.2);
      expect(updated.conceptWeights['dynamic-programming'], 2.5);
      expect(updated.conceptWeights['graphs'], 1.5);
      // Summary appended to notes and recorded as the outcome note.
      expect(updated.notes, contains('Original plan notes.'));
      expect(updated.notes, contains('Drill DP; graphs are solid.'));
      expect(updated.outcomeNotes, 'Drill DP; graphs are solid.');
    });

    test('a null outcome leaves the goal outcome as-is', () {
      const result = DebriefResult(summary: 'Just some notes.');
      final updated = result.applyTo(_goal());
      expect(updated.outcome, GoalOutcome.pending);
    });
  });
}
