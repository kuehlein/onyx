import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onyx/core/ai/claude_service.dart';
import 'package:onyx/core/ai/coach.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/ai.dart';
import 'package:onyx/shared/providers/coach.dart';
import 'package:onyx/shared/providers/database.dart';

Card _card() => const Card(
      id: 'c1',
      type: CardType.flashcard,
      title: 'Binary Search',
      overview: 'Halve the search space.',
      tags: ['ds-a'],
      tiers: {'ds-a': 1},
      sections: [
        CardSection(
          heading: 'Complexity',
          slug: 'complexity',
          content: 'O(log n).',
          quizzable: true,
        ),
      ],
      wikilinks: [],
      filePath: 'binary-search.md',
    );

ClaudeService _replying(String text) => ClaudeService(
      apiKey: 'k',
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': text},
              ],
            }),
            200,
          )),
    );

ProviderContainer _container({
  required ClaudeService? claude,
  required AppDatabase db,
}) =>
    ProviderContainer(overrides: [
      claudeServiceProvider.overrideWithValue(claude),
      appDatabaseProvider.overrideWithValue(db),
    ]);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.withExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('send persists both turns and they reload on a fresh container',
      () async {
    final c = _container(
      claude: _replying('Solid.\n<suggest-grade>3</suggest-grade>'),
      db: db,
    );
    addTearDown(c.dispose);

    await c.read(coachProvider('c1', 'complexity').future); // load (empty)
    await c.read(coachProvider('c1', 'complexity').notifier).send(
          'I said log n',
          card: _card(),
          section: _card().sections.first,
          revealed: true,
          grading: true,
        );

    final state = c.read(coachProvider('c1', 'complexity')).asData!.value;
    expect(state.messages.map((m) => m.role),
        [CoachRole.user, CoachRole.assistant]);
    expect(state.messages.last.text, 'Solid.'); // tag stripped
    expect(state.suggestedGrade, 3);
    expect(state.busy, isFalse);

    // A new container over the same DB rebuilds from persistence.
    final c2 = _container(claude: _replying('x'), db: db);
    addTearDown(c2.dispose);
    final reloaded = await c2.read(coachProvider('c1', 'complexity').future);
    expect(reloaded.messages.length, 2);
    expect(reloaded.suggestedGrade, 3);
  });

  test('no API key → error surfaced, nothing persisted', () async {
    final c = _container(claude: null, db: db);
    addTearDown(c.dispose);

    await c.read(coachProvider('c1', null).future);
    await c.read(coachProvider('c1', null).notifier).send(
          'hi',
          card: _card(),
          revealed: true,
          grading: false,
        );

    final state = c.read(coachProvider('c1', null)).asData!.value;
    expect(state.messages, isEmpty);
    expect(state.error, contains('API key'));
    expect(await db.select(db.coachMessages).get(), isEmpty);
  });

  test('clearTestCoachConversations drops per-section chats, keeps Browse',
      () async {
    final c = _container(claude: _replying('ok'), db: db);
    addTearDown(c.dispose);

    // A test chat (section slug set) and a Browse chat (section null).
    await c.read(coachProvider('c1', 'complexity').notifier).send('test q',
        card: _card(),
        section: _card().sections.first,
        revealed: true,
        grading: true);
    await c
        .read(coachProvider('c1', null).notifier)
        .send('browse q', card: _card(), revealed: true, grading: false);
    expect((await db.select(db.coachMessages).get()).length, 4); // 2 + 2

    await clearTestCoachConversations(db);

    final remaining = await db.select(db.coachMessages).get();
    expect(remaining.every((m) => m.sectionSlug == null), isTrue);
    expect(remaining.length, 2); // only the Browse turns survive
  });

  test('network failure keeps the user turn (persisted) and a friendly message',
      () async {
    final offline = ClaudeService(
      apiKey: 'k',
      client: MockClient((_) async => throw Exception('no route to host')),
    );
    final c = _container(claude: offline, db: db);
    addTearDown(c.dispose);

    await c.read(coachProvider('c1', 'complexity').future);
    await c.read(coachProvider('c1', 'complexity').notifier).send(
          'hint please',
          card: _card(),
          section: _card().sections.first,
          revealed: false,
          grading: true,
        );

    final state = c.read(coachProvider('c1', 'complexity')).asData!.value;
    expect(state.messages.length, 1); // the user's turn remains
    expect(state.error, contains("Couldn't reach Claude"));
    expect(state.busy, isFalse);
  });
}
