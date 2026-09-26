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
      type: 'flashcard',
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

  test('the adversarial critic records a second-opinion verdict', () async {
    // Distinguish the two API calls by their system prompt: the critic's carries
    // "second-opinion"; the coach's is the interviewer prompt.
    final claude = ClaudeService(
      apiKey: 'k',
      client: MockClient((req) async {
        final body = req.body;
        final isCritic = body.contains('second-opinion');
        final text = isCritic
            ? '<verdict>{"appliedScore":40,"note":"shaky"}</verdict>'
            : 'Debrief.\n<suggest-grade>3</suggest-grade>\n'
                '<assessment>{"appliedScore":80,"novel":true}</assessment>';
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': text},
            ],
          }),
          200,
        );
      }),
    );
    final c = _container(claude: claude, db: db);
    addTearDown(c.dispose);

    await c.read(coachProvider('c1', 'complexity').notifier).send(
          'my answer',
          card: _card(),
          section: _card().sections.first,
          revealed: true,
          grading: true,
        );

    final attempt = (await db.select(db.appliedAttempts).get()).single;
    expect(attempt.appliedScore, 80); // coach's raw score preserved
    expect(attempt.verifierScore, 40); // critic's independent score
    expect(attempt.verified, isFalse); // 80 vs 40 → not corroborated
  });

  test('a mock-interview assessment is logged to applied_attempts', () async {
    final c = _container(
      claude: _replying('Nice.\n<suggest-grade>3</suggest-grade>\n'
          '<assessment>{"appliedScore":68,"rubric":{"correctness":4},'
          '"novel":true,"hintLevel":1}</assessment>'),
      db: db,
    );
    addTearDown(c.dispose);

    await c.read(coachProvider('c1', 'complexity').notifier).send(
          'my answer',
          card: _card(),
          section: _card().sections.first,
          revealed: true,
          grading: true,
        );

    final attempts = await db.select(db.appliedAttempts).get();
    expect(attempts.length, 1);
    expect(attempts.single.cardId, 'c1');
    expect(attempts.single.domain, 'ds-a');
    expect(attempts.single.appliedScore, 68);
    expect(attempts.single.novel, isTrue);
    expect(attempts.single.source, 'interview-coach');
    // The assessment tag never leaks into the visible transcript.
    final state = c.read(coachProvider('c1', 'complexity')).asData!.value;
    expect(state.messages.last.text, 'Nice.');
  });

  test('tutor mode does not log an applied attempt', () async {
    final c = _container(
      claude: _replying('Here is a hint.\n'
          '<assessment>{"appliedScore":90}</assessment>'),
      db: db,
    );
    addTearDown(c.dispose);

    await c.read(coachProvider('c1', null).notifier).send(
          'help',
          card: _card(),
          revealed: true,
          grading: false, // tutor
        );

    expect(await db.select(db.appliedAttempts).get(), isEmpty);
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

    await clearTestCoachConversations(db, CoachKind.coach);

    final remaining = await db.select(db.coachMessages).get();
    expect(remaining.every((m) => m.sectionSlug == null), isTrue);
    expect(remaining.length, 2); // only the Browse turns survive
  });

  test('tutor and examiner keep separate transcripts on one section (n0015)',
      () async {
    final c = _container(claude: _replying('ok'), db: db);
    addTearDown(c.dispose);
    final card = _card();
    final section = card.sections.first;

    // A Learn tutor and a Review examiner both discuss the SAME (card, section).
    await c
        .read(coachProvider('c1', 'complexity', kind: CoachKind.tutor).notifier)
        .send('learn q',
            card: card, section: section, revealed: true, grading: false);
    await c
        .read(coachProvider('c1', 'complexity', kind: CoachKind.examiner)
            .notifier)
        .send('review q',
            card: card, section: section, revealed: true, grading: true);

    // Each surface reloads ONLY its own turns — no interleaving.
    final tutor = await c
        .read(coachProvider('c1', 'complexity', kind: CoachKind.tutor).future);
    final examiner = await c.read(
        coachProvider('c1', 'complexity', kind: CoachKind.examiner).future);
    expect(tutor.messages.any((m) => m.text == 'learn q'), isTrue);
    expect(tutor.messages.any((m) => m.text == 'review q'), isFalse);
    expect(examiner.messages.any((m) => m.text == 'review q'), isTrue);

    // A Learn session clears only tutor rows; the examiner transcript survives.
    await clearTestCoachConversations(db, CoachKind.tutor);
    final rows = await db.select(db.coachMessages).get();
    expect(rows.any((m) => m.kind == 'tutor'), isFalse); // tutor wiped
    expect(rows.any((m) => m.kind == 'examiner'), isTrue); // examiner survives
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
