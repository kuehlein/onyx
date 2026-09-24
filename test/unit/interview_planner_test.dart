import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onyx/core/ai/claude_service.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/core/vault/vault_source.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/ai.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/interview_planner.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/vault.dart';
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

/// A VaultSource whose meta files live in memory — so the accepted interview
/// persists onto the study goal across the notifier's rebuild.
class _FakeSource implements VaultSource {
  final Map<String, String> meta = {};
  @override
  String get rootLabel => 'fake';
  @override
  Future<List<String>> listCardPaths() async => const [];
  @override
  Future<List<String>> listAllPaths() => listCardPaths();
  @override
  Future<List<String>> listConfigPaths() async => const [];
  @override
  Future<String> readCard(String relativePath) async => '';
  @override
  Future<String?> readMeta(String name) async => meta[name];
  @override
  Future<void> writeMeta(String name, String content) async =>
      meta[name] = content;
  @override
  Future<void> writeFile(String relativePath, String content) async {}
  @override
  Future<void> deleteFile(String relativePath) async {}
}

const _index = IndexResult(
  cards: [
    Card(
      id: 'a',
      type: 'flashcard',
      title: 'Load balancing',
      overview: '',
      tags: ['system-design'],
      tiers: {'system-design': 1},
      sections: [],
      wikilinks: [],
      filePath: 'a.md',
      concepts: ['consistent-hashing'],
    ),
  ],
  idless: 0,
  malformed: 0,
  skipped: 0,
);

ClaudeService _replying(String text, {void Function(String body)? onBody}) =>
    ClaudeService(
      apiKey: 'k',
      client: MockClient((req) async {
        onBody?.call(req.body);
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

/// A fixed clock so a date-sensitive test doesn't depend on the wall-clock — a
/// hardcoded plan date must stay in the future relative to "today", else the
/// accept path treats it as a past deadline and drops it.
class _FixedClock extends Clock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

ProviderContainer _container(ClaudeService? claude, AppDatabase db,
        {Clock? clock}) =>
    ProviderContainer(overrides: [
      claudeServiceProvider.overrideWithValue(claude),
      vaultIndexProvider.overrideWith((ref) async => _index),
      appDatabaseProvider.overrideWithValue(db),
      // A real (in-memory) source so the default study goal persists the
      // accepted interview across the notifier's rebuild.
      vaultSourceProvider.overrideWithValue(_FakeSource()),
      clockProvider.overrideWith((ref) async => clock ?? Clock.real),
    ]);

void main() {
  test('a clarifying reply appends text, proposes no plan', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    String? body;
    final c = _container(
        _replying('Which team did you apply for?', onBody: (b) => body = b),
        db);
    addTearDown(c.dispose);

    await c
        .read(interviewPlannerProvider.notifier)
        .send('I have an interview at Foobar');

    final s = c.read(interviewPlannerProvider);
    expect(s.busy, isFalse);
    expect(s.plan, isNull);
    expect(s.messages.last.text, contains('Which team'));
    // The deck's keys were sent so the model can weight real material.
    expect(body, contains('system-design'));
    expect(body, contains('consistent-hashing'));
    await db.close();
  });

  test('a plan reply parses; accept() persists an active prep goal', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    const reply = 'Prioritizing system design; behavioral is on you.\n'
        '<plan>{"company":"Google","role":"Senior Backend",'
        '"level":"senior","tier":"faang","track":"backend",'
        '"date":"2026-09-20","domainWeights":{"system-design":1.6},'
        '"conceptWeights":{"consistent-hashing":2.0},'
        '"appGaps":["behavioral"],"summary":"Focus system design."}</plan>';
    // Pin "today" before the plan's date so the deadline isn't seen as past
    // (keeps this assertion stable regardless of the wall-clock date).
    final c = _container(_replying(reply), db,
        clock: _FixedClock(DateTime(2026, 9, 1)));
    addTearDown(c.dispose);

    await c
        .read(interviewPlannerProvider.notifier)
        .send('Google, senior backend, in 2 weeks');

    final s = c.read(interviewPlannerProvider);
    expect(s.messages.last.text,
        'Prioritizing system design; behavioral is on you.');
    expect(s.plan, isNotNull);
    expect(s.plan!.company, 'Google');
    expect(s.plan!.appGaps, ['behavioral']);

    final aim = await c.read(interviewPlannerProvider.notifier).accept();
    expect(aim, isNotNull);
    expect(aim!.companyName, 'Google');
    expect(aim.active, isTrue);

    // It landed on the active study goal and will drive the targeting layer.
    final goal = await c.read(activeDeckProvider.future);
    expect(goal.aims.map((iv) => iv.companyName), ['Google']);
    expect(goal.aims.single.domainWeights['system-design'], 1.6);
    // The plan's knobs + date landed on the AIM (S5 — the deck is a pure lens
    // with no target slots of its own).
    final iv = goal.aims.single;
    expect(iv.levelId, 'senior');
    expect(iv.trackId, 'backend');
    expect(iv.rounds.single.date, DateTime(2026, 9, 20));
    await db.close();
  });

  test('accept() with no plan is a no-op', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final c = _container(_replying('ask a question'), db);
    addTearDown(c.dispose);
    expect(await c.read(interviewPlannerProvider.notifier).accept(), isNull);
    await db.close();
  });

  test('no API key → error, no crash', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final c = _container(null, db);
    addTearDown(c.dispose);
    await c.read(interviewPlannerProvider.notifier).send('hi');
    expect(c.read(interviewPlannerProvider).error, contains('API key'));
    await db.close();
  });
}
