import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/claude_service.dart';
import 'package:onyx/core/ai/coach.dart' show CoachRole;
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/practice/mock_session.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/ai.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/flow_runner.dart';
import 'package:onyx/shared/providers/interview.dart';
import 'package:onyx/shared/providers/srs.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

/// A canned ClaudeService that distinguishes GRADER turns from interlocutor/tutor
/// turns by a marker unique to the grader system prompt — the `<grade>` output
/// contract only the grader is instructed to emit — and returns a parseable
/// `<grade>{…}</grade>` for those, an ordinary line otherwise.
class FakeClaudeService implements ClaudeService {
  final List<String?> systemsSeen = [];

  @override
  Future<String> chat({
    required List<({String role, String content})> messages,
    String? system,
    String model = ClaudeService.defaultModel,
    int maxTokens = 1024,
    bool cacheSystem = false,
  }) async {
    systemsSeen.add(system);
    // The grader system prompt is the only one carrying the `<grade>` output
    // contract; interlocutor/tutor prompts never mention it.
    final isGrader =
        system != null && system.contains('<grade>{"appliedScore"');
    if (isGrader) {
      return '<grade>{"appliedScore":72,"rubric":{"taskCompletion":4,'
          '"accuracy":3,"communication":4},"note":"solid, minor slips"}</grade>';
    }
    return 'Sure — let us continue.';
  }

  @override
  Future<String> complete({
    required String prompt,
    String? system,
    String model = ClaudeService.defaultModel,
    int maxTokens = 1024,
  }) =>
      chat(messages: [(role: 'user', content: prompt)], system: system);

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Card _conversationCard() => const Card(
      id: 'order-water',
      type: 'conversation',
      title: 'Order water',
      overview: 'Politely ask a waiter for a glass of water.',
      tags: ['korean'],
      tiers: {'korean': 1},
      sections: [],
      wikilinks: [],
      filePath: 'order-water.md',
      dependsOn: ['greetings'],
    );

void main() {
  const skill = 'You are a waiter at a Korean restaurant. Speak only Korean.';
  const frontier = {'greetings'};

  ProviderContainer make(AppDatabase db, FakeClaudeService fake) =>
      ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        claudeServiceProvider.overrideWithValue(fake),
      ]);

  test('runs a config flow end to end: reply, grade, applied + recognition',
      () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(() => db.close());
    final fake = FakeClaudeService();
    final c = make(db, fake);
    addTearDown(c.dispose);

    final card = _conversationCard();
    final notifier = c.read(flowRunnerSessionProvider(card.id).notifier);

    // start: opener appended, phase running, no answer leaked.
    notifier.start(card: card, skill: skill, frontier: frontier);
    var state = c.read(flowRunnerSessionProvider(card.id));
    expect(state.phase, MockPhase.running);
    expect(state.messages, hasLength(1));
    expect(state.messages.single.text, isNot(contains('water')));

    // send: a learner turn + an interlocutor reply, still running.
    await notifier.send('안녕하세요', card: card, skill: skill, frontier: frontier);
    state = c.read(flowRunnerSessionProvider(card.id));
    expect(state.phase, MockPhase.running);
    expect(state.messages, hasLength(3)); // opener + user + reply
    expect(state.messages.last.role, CoachRole.assistant);
    expect(state.messages.last.text, contains('continue'));

    // endAndGrade: phase done, a reconciled grade, applied attempt recorded, and
    // the recognition ("mock") clock now has a state for this card.
    await notifier.endAndGrade(card: card, skill: skill, frontier: frontier);
    state = c.read(flowRunnerSessionProvider(card.id));
    expect(state.phase, MockPhase.done);
    expect(state.grade, isNotNull);
    expect(state.grade!.appliedScore, 72);

    // The applied attempt is tagged with the card TYPE as its source.
    final attempts = await c.read(appliedRepositoryProvider).attempts();
    expect(attempts, hasLength(1));
    expect(attempts.single.source, 'conversation');
    expect(attempts.single.cardId, 'order-water');
    expect(attempts.single.appliedScore, 72);

    // A recognition state exists at "<id>::mock".
    final recog = await c.read(recognitionRepositoryProvider).loadStates();
    expect(recog.containsKey('order-water::mock'), isTrue);

    // The grader was actually consulted (panel of independent graders).
    expect(
      fake.systemsSeen
          .where((s) => s != null && s.contains('<grade>{"appliedScore"'))
          .length,
      greaterThanOrEqualTo(1),
    );
  });
}
