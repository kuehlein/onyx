import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onyx/core/ai/claude_service.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/ai.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/readiness_report.dart';
import 'package:onyx/shared/providers/vault.dart';

class _FakeTarget extends ReadinessTargetController {
  @override
  Future<ReadinessTarget> build() async => const ReadinessTarget(
        level: SeniorityLevel.senior,
        company: CompanyTier.faang,
        track: Track.general,
      );
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

ProviderContainer _container(ClaudeService? claude) => ProviderContainer(
      overrides: [
        claudeServiceProvider.overrideWithValue(claude),
        readinessProvider.overrideWith((ref) async => _readiness),
        readinessTargetControllerProvider.overrideWith(_FakeTarget.new),
        appliedSummaryProvider.overrideWith(
            (ref) async => {'system-design': (attempts: 2, contested: 1)}),
        vaultIndexProvider.overrideWith((ref) async => _index),
        clockProvider.overrideWith((ref) async => Clock.real),
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
