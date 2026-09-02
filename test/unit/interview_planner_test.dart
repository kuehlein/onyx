import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onyx/core/ai/claude_service.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/ai.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/interview_planner.dart';
import 'package:onyx/shared/providers/readiness.dart';
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

class _FakeTarget extends ReadinessTargetController {
  @override
  Future<ReadinessTarget> build() async => const ReadinessTarget(
        level: SeniorityLevel.senior,
        company: CompanyTier.faang,
        track: Track.general,
      );
}

const _index = IndexResult(
  cards: [
    Card(
      id: 'a',
      type: CardType.flashcard,
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

ProviderContainer _container(ClaudeService? claude, AppDatabase db) =>
    ProviderContainer(overrides: [
      claudeServiceProvider.overrideWithValue(claude),
      vaultIndexProvider.overrideWith((ref) async => _index),
      readinessTargetControllerProvider.overrideWith(_FakeTarget.new),
      appDatabaseProvider.overrideWithValue(db),
      vaultSourceProvider.overrideWithValue(null),
      clockProvider.overrideWith((ref) async => Clock.real),
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
    const reply = 'Prioritising system design; behavioral is on you.\n'
        '<plan>{"company":"Google","role":"Senior Backend",'
        '"level":"senior","tier":"faang","track":"backend",'
        '"date":"2026-09-20","domainWeights":{"system-design":1.6},'
        '"conceptWeights":{"consistent-hashing":2.0},'
        '"appGaps":["behavioral"],"summary":"Focus system design."}</plan>';
    final c = _container(_replying(reply), db);
    addTearDown(c.dispose);

    await c
        .read(interviewPlannerProvider.notifier)
        .send('Google, senior backend, in 2 weeks');

    final s = c.read(interviewPlannerProvider);
    expect(s.messages.last.text,
        'Prioritising system design; behavioral is on you.');
    expect(s.plan, isNotNull);
    expect(s.plan!.company, 'Google');
    expect(s.plan!.appGaps, ['behavioral']);

    final goal = await c.read(interviewPlannerProvider.notifier).accept();
    expect(goal, isNotNull);
    expect(goal!.companyName, 'Google');
    expect(goal.active, isTrue);

    // It landed in the store and will drive the targeting layer.
    final goals = c.read(prepGoalsProvider).asData!.value;
    expect(goals.map((g) => g.companyName), ['Google']);
    expect(goals.single.domainWeights['system-design'], 1.6);
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
