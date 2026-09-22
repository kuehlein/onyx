import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/ladder.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/template/active_template.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/template/deck_template_yaml.dart';
import 'package:onyx/core/vault/card_parser.dart';

/// #30 Phase 6 — acceptance test: a throwaway subject defined ENTIRELY in config
/// drives the app's core (readiness math, ladder, and the card parser) with zero
/// code changes and zero SWE assumptions. The demo deliberately gives the
/// `flashcard` flow a different quizzability (allSections) than SWE (blocklist),
/// so the parser assertion proves it genuinely reads the flow config.
const _demoYaml = '''
id: demo-lang
target:
  levels:
    - {id: a1, label: A1, tierCurve: [1.0, 0.5]}
    - {id: b2, label: B2, tierCurve: [1.0, 0.9]}
  contexts:
    - {id: casual, label: Casual, stabilityTargetDays: 45}
    - {id: exam, label: DELE, stabilityTargetDays: 100}
  tracks:
    - {id: speaking, label: Speaking, familyWeights: {grammar: 1.4}}
  families:
    - {id: grammar, exact: [grammar]}
flows:
  - {cardType: flashcard, scheduling: recall, quizzability: allSections}
''';

void main() {
  setUp(() => activeTemplate = deckTemplateFromYaml(_demoYaml));
  tearDown(
      () => activeTemplate = softwareInterviewsTemplate); // no cross-test leak

  test('readiness ladder is generated from the demo subject, not SWE', () {
    expect(readinessLadder.map((r) => r.label),
        ['A1 · Casual', 'A1 · DELE', 'B2 · Casual', 'B2 · DELE']);
  });

  test('target math uses the demo config', () {
    const t =
        ReadinessTarget(levelId: 'b2', contextId: 'exam', trackId: 'speaking');
    expect(t.stabilityTarget, 100); // demo DELE bar
    expect(t.label, 'B2 · DELE · Speaking');
    expect(domainWeight(t, 'grammar'), 1.4); // demo family weight
    expect(domainWeight(t, 'ds-a'), 1.0); // SWE families don't exist here
    expect(tierRelevanceForTest('a1'), 0.5); // demo A1 curve, tier 2+
  });

  test('the card parser applies the demo flow policy (allSections)', () {
    const card = '''
---
id: hola
type: flashcard
tags: [grammar]
---

# Hola

Greeting basics.

## Usage

When to use it.

## Related

Other greetings.
''';
    final parsed = const CardParser().parse(card, filePath: 'hola.md');
    // Under SWE the "Related" heading is blocklisted; under the demo's
    // allSections policy every section is quizzable — proving config drives it.
    final related = parsed!.sections.firstWhere((s) => s.heading == 'Related');
    expect(related.quizzable, isTrue);
    expect(parsed.sections.every((s) => s.quizzable), isTrue);
  });
}

/// tierRelevance takes the SWE enum; for the demo we assert via the config
/// directly (the enum getter would map an unknown id to the fallback).
double tierRelevanceForTest(String levelId) =>
    activeTemplate.target.tierRelevance(levelId, 2);
