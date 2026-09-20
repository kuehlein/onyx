import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/active_subject.dart';
import 'package:onyx/core/subject/dependency_gating.dart';
import 'package:onyx/core/subject/flow_access.dart';
import 'package:onyx/core/subject/flow_prompt.dart';
import 'package:onyx/core/subject/software_interviews.dart';
import 'package:onyx/core/subject/subject_config_yaml.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/models/card.dart';

/// Loads the real `korean-vault/` (a hand-authored, config-only Korean subject)
/// through the actual vault loader + parser and shows the concept-recall flow and
/// the gated conversation flow operating side by side — the multi-subject
/// generalization (#30) exercised on real content, zero code changes.
void main() {
  final source = DesktopVaultSource('korean-vault');
  late List<Card> cards;

  setUp(() async {
    activeSubject = subjectConfigFromYaml((await source.readMeta(
      'onyx-subject.yaml',
    ))!);
    cards = [
      for (final path in await source.listCardPaths())
        if (const CardParser()
                .parse(await source.readCard(path), filePath: path)
            case final c?)
          c,
    ];
  });
  tearDown(() => activeSubject = softwareInterviewsConfig);

  test('the vault loads as a config-only Korean subject', () {
    expect(activeSubject.id, 'korean');
    expect(activeSubject.target.levels.map((l) => l.id),
        ['beginner', 'elementary']);
    expect(activeSubject.target.contexts.map((c) => c.label),
        ['Casual', 'TOPIK exam']);
    expect(activeSubject.flows.map((f) => f.cardType),
        ['flashcard', 'conversation']);
    // The skill file (no `type:`) is not indexed as a card.
    expect(cards.map((c) => c.id), isNot(contains('order-water-skill')));
  });

  test('recall deck and conversation flow sit side by side', () {
    final concept = cards.where((c) => !c.isPracticeTrack).toList();
    final practice = cards.where((c) => c.isPracticeTrack).toList();

    // Concept recall flow: Hangul + vocabulary + grammar + culture, all quizzable.
    expect(
        concept.map((c) => c.id),
        containsAll([
          'hangul-a',
          'word-hello',
          'grammar-topic-particle',
          'culture-politeness-levels',
        ]));
    expect(concept.length, 9);
    expect(concept.every((c) => c.quizzableSections.isNotEmpty), isTrue);
    // A coherent starter deck spans the language's facets, culture included.
    expect(concept.where((c) => c.tags.contains('culture')).length, 2);

    // Practice flow: the one conversation, whole-card mock unit, gated on words.
    expect(practice.map((c) => c.id), ['order-water']);
    final convo = practice.single;
    expect(convo.sections.any((s) => s.quizzable), isFalse);
    expect(convo.dependsOn,
        ['word-hello', 'word-water', 'word-please-give', 'word-thankyou']);
  });

  test('conversation gates on covered words, then runs its vault skill',
      () async {
    final convo = cards.firstWhere((c) => c.id == 'order-water');
    const bar = 0.7;

    // Early: only "hello" and "water" are durable → conversation not yet earned.
    double early(String c) => {'word-hello': 0.9, 'word-water': 0.8}[c] ?? 0.0;
    final locked = evaluateGate(
        dependsOn: convo.dependsOn, competenceOf: early, competenceBar: bar);
    expect(locked.unlocked, isFalse); // 2/4 = 0.5 < 0.6
    expect(flowAccess(gate: locked, overridden: false), FlowAccess.locked);
    expect(flowAccess(gate: locked, overridden: true), FlowAccess.provisional);

    // Later: the "juseyo" + "thank you" foundations catch up → unlocked.
    double later(String c) => 0.85; // all covered
    final open = evaluateGate(
        dependsOn: convo.dependsOn, competenceOf: later, competenceBar: bar);
    expect(open.unlocked, isTrue);

    // The AI runs the vault-authored server persona, limited to covered words.
    final frontier = coveredFrontier(
        concepts: convo.dependsOn, competenceOf: early, competenceBar: bar);
    expect(frontier, {'word-hello', 'word-water'});

    final skill = await loadFlowSkill(
        source.readCard, activeSubject.flowForType('conversation')!.skill);
    expect(skill, contains('Korean café server'));

    final prompt = assembleFlowPrompt(
        skill: skill!, problem: convo.overview, frontier: frontier);
    expect(prompt, contains('Korean café server')); // vault persona
    expect(prompt, contains('word-hello, word-water')); // covered → allowed
    expect(prompt, isNot(contains('word-please-give'))); // uncovered → withheld
  });
}
