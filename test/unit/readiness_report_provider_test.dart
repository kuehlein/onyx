import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onyx/core/ai/claude_service.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/settings/preferences_repository.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/ai.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/readiness_report.dart';
import 'package:onyx/shared/providers/settings.dart';
import 'package:onyx/shared/providers/vault.dart';

class _FakeTarget extends ReadinessTargetController {
  @override
  Future<ReadinessTarget> build() async => const ReadinessTarget(
        level: SeniorityLevel.senior,
        company: CompanyTier.faang,
        track: Track.general,
      );
}

/// An in-memory prefs store so the report cache round-trips without a database.
class _FakePrefs implements PreferencesRepository {
  final store = <String, String>{};
  @override
  Future<String?> get(String key) async => store[key];
  @override
  Future<void> set(String key, String value) async => store[key] = value;
}

Card _card(String id, String domain, String title) => Card(
      id: id,
      type: CardType.flashcard,
      title: title,
      overview: '',
      tags: [domain],
      tiers: {domain: 1},
      sections: const [
        CardSection(heading: 's', slug: 's', content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

const _readiness = Readiness(
  domains: [
    DomainReadiness(
      domain: 'system-design',
      coverage: 0.3,
      strength: 0.5,
      score: 0.25,
      low: 0.15,
      high: 0.35,
      studied: 3,
      total: 10,
      transfer: 0.4,
      appliedN: 2,
    ),
  ],
  overall: 0.42,
  low: 0.3,
  high: 0.54,
  interview: true,
);

final _index = IndexResult(
  cards: [
    _card('a', 'system-design', 'Load balancing'),
    _card('b', 'ds-a', 'Binary search'),
  ],
  idless: 0,
  malformed: 0,
  skipped: 0,
);

ProviderContainer _container(ClaudeService? claude,
        {PreferencesRepository? prefs}) =>
    ProviderContainer(
      overrides: [
        claudeServiceProvider.overrideWithValue(claude),
        readinessProvider.overrideWith((ref) async => _readiness),
        readinessTargetControllerProvider.overrideWith(_FakeTarget.new),
        appliedSummaryProvider.overrideWith(
            (ref) async => {'system-design': (attempts: 2, contested: 1)}),
        vaultIndexProvider.overrideWith((ref) async => _index),
        clockProvider.overrideWith((ref) async => Clock.real),
        preferencesRepositoryProvider.overrideWithValue(prefs ?? _FakePrefs()),
      ],
    );

void main() {
  test('generate() gathers data, calls Claude, and stores the report',
      () async {
    String? sentBody;
    final claude = ClaudeService(
      apiKey: 'k',
      client: MockClient((req) async {
        sentBody = req.body;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': '## Verdict\nNot ready yet.'},
            ],
          }),
          200,
        );
      }),
    );
    final c = _container(claude);
    addTearDown(c.dispose);

    await c.read(readinessReportProvider.notifier).generate();

    final state = c.read(readinessReportProvider);
    expect(state.busy, isFalse);
    expect(state.error, isNull);
    expect(state.text, contains('Not ready yet.'));
    expect(state.basedOnOverall, closeTo(0.42, 1e-9));
    expect(state.generatedAt, isNotNull);

    // The prompt that went out carried the real target + deck scope, proving the
    // whole gather→prompt→call path is wired.
    expect(sentBody, isNotNull);
    final decoded = jsonEncode(jsonDecode(sentBody!)); // normalise
    expect(decoded, contains('Senior · FAANG · General'));
    expect(decoded, contains('Load balancing')); // system-design deck topic
    expect(decoded, contains('recall')); // system prompt reasoning cue
  });

  test('reuses the cached report when the data is unchanged (no 2nd call)',
      () async {
    var calls = 0;
    final claude = ClaudeService(
      apiKey: 'k',
      client: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'report v$calls'},
            ],
          }),
          200,
        );
      }),
    );
    final c = _container(claude);
    addTearDown(c.dispose);
    final notifier = c.read(readinessReportProvider.notifier);

    await notifier.generate();
    expect(calls, 1);
    expect(c.read(readinessReportProvider).text, 'report v1');

    // Same data → ensureFresh must NOT spend another call.
    await notifier.ensureFresh();
    expect(calls, 1);
    expect(c.read(readinessReportProvider).text, 'report v1');

    // The explicit Regenerate button forces a fresh call regardless.
    await notifier.generate(force: true);
    expect(calls, 2);
    expect(c.read(readinessReportProvider).text, 'report v2');
  });

  test('a cold open reuses the on-disk report across provider instances',
      () async {
    var calls = 0;
    ClaudeService claude() => ClaudeService(
          apiKey: 'k',
          client: MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({
                'content': [
                  {'type': 'text', 'text': 'the report'},
                ],
              }),
              200,
            );
          }),
        );
    final prefs = _FakePrefs(); // shared disk across both containers

    final c1 = _container(claude(), prefs: prefs);
    await c1.read(readinessReportProvider.notifier).generate();
    expect(calls, 1);
    c1.dispose();

    // A fresh container (simulating an app relaunch) with the same data reads the
    // persisted report and makes no call.
    final c2 = _container(claude(), prefs: prefs);
    addTearDown(c2.dispose);
    await c2.read(readinessReportProvider.notifier).ensureFresh();
    expect(calls, 1);
    expect(c2.read(readinessReportProvider).text, 'the report');
  });

  test('regenerates when the underlying data changes', () async {
    var calls = 0;
    ClaudeService claude() => ClaudeService(
          apiKey: 'k',
          client: MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({
                'content': [
                  {'type': 'text', 'text': 'report'},
                ],
              }),
              200,
            );
          }),
        );
    final prefs = _FakePrefs();

    final c1 = _container(claude(), prefs: prefs);
    await c1.read(readinessReportProvider.notifier).generate();
    expect(calls, 1);
    c1.dispose();

    // New container whose readiness has moved → different prompt → new call.
    final moved = ProviderContainer(overrides: [
      claudeServiceProvider.overrideWithValue(claude()),
      readinessProvider.overrideWith((ref) async => const Readiness(
            domains: [
              DomainReadiness(
                domain: 'system-design',
                coverage: 0.9, // was 0.3
                strength: 0.8,
                score: 0.72,
                low: 0.6,
                high: 0.8,
                studied: 9, // was 3
                total: 10,
                transfer: 0.7,
                appliedN: 5,
              ),
            ],
            overall: 0.8,
            low: 0.7,
            high: 0.9,
            interview: true,
          )),
      readinessTargetControllerProvider.overrideWith(_FakeTarget.new),
      appliedSummaryProvider.overrideWith(
          (ref) async => {'system-design': (attempts: 5, contested: 0)}),
      vaultIndexProvider.overrideWith((ref) async => _index),
      clockProvider.overrideWith((ref) async => Clock.real),
      preferencesRepositoryProvider.overrideWithValue(prefs),
    ]);
    addTearDown(moved.dispose);
    await moved.read(readinessReportProvider.notifier).ensureFresh();
    expect(calls, 2); // data changed → spent a fresh call
  });

  test('no API key → a helpful error, no crash', () async {
    final c = _container(null);
    addTearDown(c.dispose);

    await c.read(readinessReportProvider.notifier).generate();

    final state = c.read(readinessReportProvider);
    expect(state.hasReport, isFalse);
    expect(state.error, contains('API key'));
  });

  test('surfaces a ClaudeException message on failure', () async {
    final claude = ClaudeService(
      apiKey: 'k',
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'error': {'message': 'overloaded'}
            }),
            529,
          )),
    );
    final c = _container(claude);
    addTearDown(c.dispose);

    await c.read(readinessReportProvider.notifier).generate();

    final state = c.read(readinessReportProvider);
    expect(state.busy, isFalse);
    expect(state.error, contains('overloaded'));
    expect(state.hasReport, isFalse);
  });
}
