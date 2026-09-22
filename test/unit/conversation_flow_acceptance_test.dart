import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/template/active_template.dart';
import 'package:onyx/core/template/dependency_gating.dart';
import 'package:onyx/core/template/flow_access.dart';
import 'package:onyx/core/template/flow_prompt.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/template/deck_template_yaml.dart';
import 'package:onyx/core/vault/card_parser.dart';

/// #30c Phase 6 — end-to-end acceptance: a subject defined ENTIRELY in config +
/// vault files runs a gated, knowledge-frontier-constrained `conversation`
/// practice flow with ZERO code changes. Composes every piece built across
/// #30/#30c: config (Ph0-2/5), the card parser (Ph4), dependency gating (Ph2),
/// the soft-gate/override/provisional model (Ph3), and the vault-loaded AI skill
/// + prompt assembly with the covered-concept frontier (Ph5).
const _demoYaml = '''
id: demo-lang
target:
  levels: [{id: a1, label: A1, tierCurve: [1.0, 0.5]}]
  contexts: [{id: casual, label: Casual, stabilityTargetDays: 45}]
  tracks: [{id: speaking, label: Speaking}]
flows:
  - {cardType: flashcard, scheduling: recall, quizzability: blocklist}
  - {cardType: conversation, scheduling: mock, quizzability: noSections,
     label: Conversation, skill: 'skills/waiter.md'}
''';

const _conversationCard = '''
---
id: order-food
type: conversation
tags: [dining]
depends-on: [greetings, food-nouns, numbers]
---

# Order food at a restaurant

Role-play ordering lunch with the waiter.

## Prompt

You walk into a small café at noon.
''';

/// A fake vault reader: only the waiter skill exists.
Future<String?> _read(String path) async => path == 'skills/waiter.md'
    ? 'You are a friendly waiter. Speak simply.'
    : null;

void main() {
  setUp(() => activeTemplate = deckTemplateFromYaml(_demoYaml));
  tearDown(() => activeTemplate = softwareInterviewsTemplate);

  test('a `conversation` card parses as a configured practice-track flow', () {
    final card = const CardParser().parse(_conversationCard, filePath: 'c.md')!;
    expect(card.type, 'conversation');
    expect(card.isPracticeTrack, isTrue); // mock scheduling
    expect(card.dependsOn, ['greetings', 'food-nouns', 'numbers']);
    // Whole card is one mock unit — no section is independently quizzable.
    expect(card.sections.any((s) => s.quizzable), isFalse);
    // Its flow carries the vault skill path (Phase 5).
    expect(
        activeTemplate.flowForType('conversation')?.skill, 'skills/waiter.md');
  });

  test('gating + override + self-healing over the real card deps', () {
    final card = const CardParser().parse(_conversationCard, filePath: 'c.md')!;
    const bar = 0.7;

    // Foundation not yet in place: only greetings is durable.
    double early(String c) => {'greetings': 0.9}[c] ?? 0.0;
    final lockedGate = evaluateGate(
        dependsOn: card.dependsOn, competenceOf: early, competenceBar: bar);
    expect(lockedGate.unlocked, isFalse); // 1/3 < 0.6
    expect(lockedGate.weak, ['food-nouns', 'numbers']); // route these to study
    expect(flowAccess(gate: lockedGate, overridden: false), FlowAccess.locked);
    // "Open anyway" → provisional (started early); doesn't satisfy downstream.
    final prov = flowAccess(gate: lockedGate, overridden: true);
    expect(prov, FlowAccess.provisional);
    expect(satisfiesDownstream(prov), isFalse);

    // Foundation catches up → the same flow self-heals to unlocked, override or not.
    double later(String c) =>
        {'greetings': 0.9, 'food-nouns': 0.8, 'numbers': 0.75}[c] ?? 0.0;
    final openGate = evaluateGate(
        dependsOn: card.dependsOn, competenceOf: later, competenceBar: bar);
    expect(openGate.unlocked, isTrue);
    expect(flowAccess(gate: openGate, overridden: true), FlowAccess.unlocked);
  });

  test('the AI runs the vault skill, constrained to the covered frontier',
      () async {
    final card = const CardParser().parse(_conversationCard, filePath: 'c.md')!;
    const bar = 0.7;
    double comp(String c) =>
        {'greetings': 0.9, 'food-nouns': 0.8, 'numbers': 0.4}[c] ?? 0.0;

    // The learner's covered set (numbers not yet solid → excluded).
    final frontier = coveredFrontier(
        concepts: card.dependsOn, competenceOf: comp, competenceBar: bar);
    expect(frontier, {'greetings', 'food-nouns'});

    final flow = activeTemplate.flowForType(card.type)!;
    final skill = await loadFlowSkill(_read, flow.skill);
    expect(skill, contains('friendly waiter'));

    final prompt = assembleFlowPrompt(
      skill: skill!,
      problem: card.overview,
      frontier: frontier,
    );
    expect(prompt, contains('friendly waiter')); // the vault-authored persona
    expect(prompt, contains('Constraint: use ONLY'));
    expect(prompt, contains('food-nouns, greetings')); // sorted covered set
    expect(prompt, isNot(contains('numbers'))); // uncovered → withheld from AI
  });
}
