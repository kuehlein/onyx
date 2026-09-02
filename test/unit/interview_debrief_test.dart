import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/interview_debrief.dart';
import 'package:onyx/core/readiness/prep_goal.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/shared/models/card.dart';

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

    test('warns against overreacting to one noisy interview', () {
      final s = buildDebriefSystem(
        goal: _goal(),
        deckDomains: const ['ds-a'],
        deckConcepts: const ['graphs'],
      );
      expect(s.toLowerCase(), contains('noisy sample'));
      expect(s.toLowerCase(), contains('pattern'));
      // Empty reweights are an acceptable, encouraged outcome.
      expect(s.toLowerCase(), contains('empty'));
    });

    test('surfaces the deck frequency signal when provided', () {
      final s = buildDebriefSystem(
        goal: _goal(),
        deckDomains: const ['ds-a'],
        deckConcepts: const ['graphs', 'segment-tree'],
        highFrequency: const ['graphs'],
        lowFrequency: const ['segment-tree'],
      );
      expect(s.toLowerCase(), contains('common in real interviews'));
      expect(s, contains('graphs'));
      expect(s.toLowerCase(), contains('rare in real interviews'));
      expect(s, contains('segment-tree'));
    });
  });

  group('parseDebriefReply', () {
    test('splits shown text from the debrief block (weights clamped)', () {
      final r = parseDebriefReply(
        'Sounds like DP tripped you up.\n'
        '<debrief>{"outcome":"failed","domainWeights":{"ds-a":1.3},'
        '"conceptWeights":{"dynamic-programming":2.5},'
        '"summary":"Lean into DP for a while."}</debrief>',
      );
      expect(r.text, 'Sounds like DP tripped you up.');
      expect(r.text, isNot(contains('debrief')));
      expect(r.result, isNotNull);
      expect(r.result!.outcome, GoalOutcome.failed);
      expect(r.result!.domainWeights, {'ds-a': 1.3});
      // 2.5 is over the cap → clamped down, never a plan-overhauling spike.
      expect(r.result!.conceptWeights, {'dynamic-programming': weightCap});
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
        '<debrief>{"outcome":"unknown","domainWeights":{"ds-a":-1,"ok":1.4},'
        '"summary":""}</debrief>',
      );
      expect(r.result!.outcome, isNull);
      expect(r.result!.domainWeights, {'ok': 1.4}); // negative dropped
    });

    test('clamps every proposed multiplier into [1.0, weightCap]', () {
      final r = parseDebriefReply(
        '<debrief>{"domainWeights":{"spike":9.0,"tiny":0.3},'
        '"conceptWeights":{"ok":1.5}}</debrief>',
      );
      // A model overhaul (9.0) is capped; a sub-1.0 nudge floors to 1.0.
      expect(r.result!.domainWeights['spike'], weightCap);
      expect(r.result!.domainWeights['tiny'], 1.0);
      expect(r.result!.conceptWeights['ok'], 1.5);
    });
  });

  group('deckFrequencySignal', () {
    Card q(String id, String? freq, List<String> concepts) => Card(
          id: id,
          type: CardType.interviewQuestion,
          title: id,
          overview: '',
          tags: ['ds-a'],
          tiers: const {},
          sections: const [],
          wikilinks: const [],
          filePath: '$id.md',
          frequency: freq,
          concepts: concepts,
        );

    test('ranks a key by its highest frequency across cards', () {
      final sig = deckFrequencySignal([
        q('a', 'high', ['graphs']),
        q('b', 'low',
            ['graphs']), // graphs also appears in a rare Q → still high
        q('c', 'low', ['segment-tree']),
        q('d', null, ['ignored']), // no frequency → contributes no signal
      ]);
      expect(sig.high, contains('graphs'));
      expect(sig.high, contains('ds-a')); // domain tag of the high card
      expect(sig.low, contains('segment-tree'));
      expect(sig.low, isNot(contains('graphs')));
      expect(sig.high, isNot(contains('ignored')));
      expect(sig.low, isNot(contains('ignored')));
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
