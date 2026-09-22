import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/template/active_template.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/template/deck_template.dart';
import 'package:onyx/core/template/template_registry.dart';
import 'package:onyx/core/vault/card_parser.dart';

/// M2 (#30d): card behavior — card-ness, quizzability, practice-track — resolves
/// against *each card's own subject*, not a single global. Same `type:` string can
/// mean different things (or nothing) in different subjects.
const _target = TargetSpec(
  levels: [
    LevelValue(id: 'l', label: 'L', tierCurve: [1.0])
  ],
  contexts: [ContextValue(id: 'c', label: 'C', stabilityTargetDays: 30)],
  tracks: [TrackValue(id: 't', label: 'T')],
  families: [],
  fallbackLevelId: 'l',
  fallbackContextId: 'c',
  fallbackTrackId: 't',
);

DeckTemplate _subject(String id, List<FlowSpec> flows) =>
    DeckTemplate(id: id, target: _target, flows: flows);

const _card = CardParser();

String _md(String type) => '''
---
id: x
type: $type
---

# Title

## Approach

Body.
''';

void main() {
  // alpha: `drill` is a mock practice flow; `flashcard` is spaced recall.
  final alpha = _subject('alpha', const [
    FlowSpec(
      cardType: 'flashcard',
      scheduling: SchedulingModel.recall,
      quizzability: QuizzabilityPolicy.blocklist,
    ),
    FlowSpec(
      cardType: 'drill',
      scheduling: SchedulingModel.mock,
      quizzability: QuizzabilityPolicy.noSections,
    ),
  ]);
  // beta: only `flashcard`; `drill` is not a card type here at all.
  final beta = _subject('beta', const [
    FlowSpec(
      cardType: 'flashcard',
      scheduling: SchedulingModel.recall,
      quizzability: QuizzabilityPolicy.blocklist,
    ),
  ]);

  setUp(() {
    activeRegistry = TemplateRegistry.fromConfigs(
      [
        ('alpha/onyx-subject.yaml', alpha),
        ('beta/onyx-subject.yaml', beta),
      ],
      fallback: softwareInterviewsTemplate,
    );
    activeTemplate = activeRegistry.primary;
  });
  tearDown(() {
    activeRegistry = TemplateRegistry.single(softwareInterviewsTemplate);
    activeTemplate = softwareInterviewsTemplate;
  });

  test('same type resolves to different flows across subjects', () {
    final a =
        _card.parse(_md('drill'), filePath: 'alpha/x.md', templateId: 'alpha');
    expect(a, isNotNull);
    expect(a!.templateId, 'alpha');
    // drill is a mock flow in alpha → a practice-track card, no quizzable sections.
    expect(a.isPracticeTrack, isTrue);
    expect(a.quizzableSections, isEmpty);
  });

  test('a type unknown to its subject is not a card', () {
    // `drill` is not a flow in beta → not an Onyx card, even though alpha has it.
    final b =
        _card.parse(_md('drill'), filePath: 'beta/x.md', templateId: 'beta');
    expect(b, isNull);
  });

  test('recall cards stay concept cards in their subject', () {
    final a = _card.parse(_md('flashcard'),
        filePath: 'alpha/y.md', templateId: 'alpha');
    expect(a, isNotNull);
    expect(a!.isPracticeTrack, isFalse);
    // blocklist policy → the Approach section is quizzable.
    expect(a.quizzableSections.map((s) => s.slug), contains('approach'));
  });
}
