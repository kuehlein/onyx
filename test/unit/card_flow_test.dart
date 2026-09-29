import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/template/active_template.dart';
import 'package:onyx/core/template/card_flow.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/template/template_registry.dart';
import 'package:onyx/shared/models/card.dart';

Card _card(String type) => Card(
      id: 'x',
      type: type,
      title: 'T',
      overview: '',
      tags: const [],
      tiers: const {},
      sections: const [],
      wikilinks: const [],
      filePath: 'x.md',
    );

void main() {
  // The pure-core placeholder is the SWE reference; keep it stable across cases.
  tearDown(() {
    activeTemplate = softwareInterviewsTemplate;
    activeRegistry = TemplateRegistry.single(softwareInterviewsTemplate);
  });

  group('CardFlow.flow resolves via the flow selector', () {
    test(
        'each SWE type resolves to the SAME flow as flowForType (byte-identical)',
        () {
      for (final t in [
        kTypeFlashcard,
        kTypeInterviewQuestion,
        kTypeAlgorithm,
        kTypeSystemDesign,
        kTypeBehavioral,
      ]) {
        final bySelector = _card(t).flow;
        final byType = softwareInterviewsTemplate.flowForType(t);
        expect(bySelector?.cardType, byType?.cardType,
            reason: 'selector resolution == flowForType for $t');
        expect(bySelector?.scheduling, byType?.scheduling);
        expect(bySelector?.quizzability, byType?.quizzability);
      }
    });

    test('schedulingModel is the resolved flow scheduling', () {
      expect(_card(kTypeAlgorithm).schedulingModel, SchedulingModel.twoClock);
      expect(_card(kTypeFlashcard).schedulingModel, SchedulingModel.recall);
      expect(_card(kTypeInterviewQuestion).schedulingModel,
          SchedulingModel.recall);
      expect(_card(kTypeSystemDesign).schedulingModel, SchedulingModel.mock);
      expect(_card(kTypeBehavioral).schedulingModel, SchedulingModel.mock);
    });

    test('an unconfigured type falls to the default flow (ADR-0023)', () {
      // No selector matches → the subject's default flashcard flow, so an engine
      // dispatching on the model treats an unclassified card as plain recall —
      // never a wrong practice track. (Was null before card-ness moved to the lens.)
      expect(_card('made-up-type').flow?.cardType, 'flashcard');
      expect(_card('made-up-type').schedulingModel, SchedulingModel.recall);
    });

    test('the default selector is a TypeIs over the flow cardType', () {
      // A flow with no explicit selector matches exactly its `type:` (the pre-selector
      // behavior), so a plain card needs no selector authored.
      final algo = softwareInterviewsTemplate.flowForType(kTypeAlgorithm)!;
      expect(algo.selector.matches(_card(kTypeAlgorithm)), isTrue);
      expect(algo.selector.matches(_card(kTypeFlashcard)), isFalse);
    });
  });
}
