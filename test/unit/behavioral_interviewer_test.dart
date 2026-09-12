import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/behavioral_interviewer.dart';
import 'package:onyx/core/interview/behavioral_grader.dart';
import 'package:onyx/core/practice/mock_session.dart' show SupportMode;
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/vault/card_parser.dart';

const _parser = CardParser();

final _card = _parser.parse('''
---
id: behavioral-conflict-and-backbone
type: behavioral
tags: [behavioral, conflict]
---

# Conflict & Backbone

Disagree respectfully, then commit.

## Prompts

- Tell me about a disagreement with your manager.
- Describe a technical decision you pushed back on.

## What strong looks like

Real stakes, upward influence for staff, disagree-then-commit. SECRETSIGNAL.
''', filePath: 'b.md')!;

void main() {
  group('behavioralOpeningLine', () {
    test('poses the first prompt from the bank', () {
      final o = behavioralOpeningLine(_card);
      expect(o, contains('Tell me about a disagreement with your manager'));
    });
  });

  group('buildBehavioralInterviewerSystem', () {
    test('embeds competency + level + probing, keeps signals private', () {
      final s = buildBehavioralInterviewerSystem(
        card: _card,
        level: SeniorityLevel.staff,
        support: SupportMode.realistic,
      );
      expect(s, contains('Conflict & Backbone'));
      expect(s, contains('Staff')); // level calibration present
      expect(s, contains('What did YOU specifically')); // gap-driven probing
      expect(s, contains('ANTI-SYCOPHANCY'));
      // It embeds the signals as private ground truth but instructs not to reveal.
      expect(s, contains('NEVER reveal'));
    });

    test('coaching vs realistic support differs', () {
      final coaching = buildBehavioralInterviewerSystem(
          card: _card,
          level: SeniorityLevel.mid,
          support: SupportMode.coaching);
      final realistic = buildBehavioralInterviewerSystem(
          card: _card,
          level: SeniorityLevel.mid,
          support: SupportMode.realistic);
      expect(coaching, contains('COACHING mode'));
      expect(realistic, contains('REALISTIC mode'));
    });
  });

  group('buildBehavioralGraderSystem + parse', () {
    test('lists the 7 behavioral dimensions and scopes to level', () {
      final s =
          buildBehavioralGraderSystem(card: _card, level: SeniorityLevel.staff);
      for (final d in [
        'structure',
        'ownership',
        'result',
        'signal',
        'scope',
        'reflection',
        'communication'
      ]) {
        expect(s, contains(d));
      }
      expect(s, contains('under-levelled')); // staff scope bar
    });

    test('parseBehavioralGrade filters to behavioral dims', () {
      final g = parseBehavioralGrade(
          '<grade>{"appliedScore":66,"rubric":{"ownership":4,"bogus":5},'
          '"note":"weak result"}</grade>')!;
      expect(g.appliedScore, 66);
      expect(g.rubric['ownership'], 4);
      expect(g.rubric.containsKey('bogus'), isFalse);
    });
  });
}
