import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onyx/core/ai/claude_service.dart';
import 'package:onyx/core/ai/readiness_report.dart';
import 'package:onyx/shared/providers/ai.dart';
import 'package:onyx/shared/providers/readiness_report.dart';
import 'package:onyx/shared/providers/weak_area.dart';

/// Two gathered per-domain rows the drill-down reasons over — the same shape the
/// holistic report produces. `system-design` is the weak, mock-tested one;
/// `ds-a` is a stronger, recall-only one, present to prove the raw-key match.
const _data = ReadinessReportData(
  targetLabel: 'Senior · FAANG · General',
  level: 'Senior',
  company: 'FAANG',
  track: 'General',
  overall: 0.42,
  low: 0.30,
  high: 0.54,
  interviewTested: true,
  daysToInterview: 21,
  domains: [
    DomainReportRow(
      domain: 'system-design',
      name: 'System design',
      coverage: 0.3,
      strength: 0.5,
      score: 0.25,
      transfer: 0.4,
      studied: 3,
      total: 10,
      mocks: 2,
      contested: 1,
      topics: ['Load balancing', 'Caching'],
      concepts: ['consistent-hashing'],
    ),
    DomainReportRow(
      domain: 'ds-a',
      name: 'DS & A',
      coverage: 0.9,
      strength: 0.8,
      score: 0.72,
      studied: 27,
      total: 30,
      mocks: 0,
      contested: 0,
      topics: ['Binary search', 'Hash map'],
    ),
  ],
);

ProviderContainer _container(ClaudeService? claude) => ProviderContainer(
      overrides: [
        claudeServiceProvider.overrideWithValue(claude),
        readinessReportDataProvider.overrideWith((ref) async => _data),
      ],
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

/// Reads the `autoDispose` drill-down provider while holding a listener on it,
/// so it isn't disposed mid-flight before its Future settles (disposal races the
/// error and would surface a `StateError` instead of the real one). Returns the
/// resolved value.
Future<String> _run(ProviderContainer c, String domain) {
  c.listen(weakAreaAnalysisProvider(domain), (_, __) {});
  return c.read(weakAreaAnalysisProvider(domain).future);
}

/// Drives the provider to a settled state (holding a listener so it stays
/// mounted), then returns its final [AsyncValue] — used to assert error states
/// without the disposal race that awaiting `.future` on an autoDispose provider
/// hits when it ends in error.
Future<AsyncValue<String>> _settle(ProviderContainer c, String domain) async {
  c.listen(weakAreaAnalysisProvider(domain), (_, __) {});
  var state = c.read(weakAreaAnalysisProvider(domain));
  // Let the (overridden, async) data dependency + build resolve.
  for (var i = 0; i < 8 && state.isLoading; i++) {
    await Future<void>.delayed(Duration.zero);
    state = c.read(weakAreaAnalysisProvider(domain));
  }
  return state;
}

void main() {
  test('returns the model text and sends the domain data in the user message',
      () async {
    String? body;
    final c =
        _container(_replying('Coverage is the gap.', onBody: (b) => body = b));
    addTearDown(c.dispose);

    final text = await _run(c, 'system-design');
    expect(text, 'Coverage is the gap.');

    // The tapped domain's data (not the other domain's) went in the USER message,
    // proving the raw-key match + gather→prompt→call path.
    final sent = jsonDecode(body!) as Map<String, dynamic>;
    final userMsg = (sent['messages'] as List).single['content'] as String;
    expect(userMsg, contains('System design'));
    expect(userMsg, contains('3/10 sections started'));
    expect(userMsg, contains('Load balancing, Caching'));
    expect(userMsg, contains('consistent-hashing'));
    expect(userMsg, contains('Senior · FAANG · General'));
    expect(userMsg, contains('Target date in 21 days'));
    // The other domain's scope must NOT bleed into this focused prompt.
    expect(userMsg, isNot(contains('Binary search')));
    // Cheap default (Haiku) model, not the heavy report model.
    expect(sent['model'], ClaudeService.defaultModel);
  });

  test('matches a different domain by its raw key', () async {
    String? body;
    final c = _container(_replying('Strong here.', onBody: (b) => body = b));
    addTearDown(c.dispose);

    final text = await _run(c, 'ds-a');
    expect(text, 'Strong here.');
    final sent = jsonDecode(body!) as Map<String, dynamic>;
    final userMsg = (sent['messages'] as List).single['content'] as String;
    expect(userMsg, contains('DS & A'));
    expect(userMsg, contains('Binary search, Hash map'));
    // Recall-only domain → the prompt says so.
    expect(userMsg.toLowerCase(), contains('recall-only'));
  });

  test('no API key → typed error flagged as needing a key', () async {
    final c = _container(null);
    addTearDown(c.dispose);

    final state = await _settle(c, 'system-design');
    expect(state.hasError, isTrue);
    final err = state.error;
    expect(err, isA<WeakAreaException>());
    expect((err as WeakAreaException).needsKey, isTrue);
    expect(err.message, contains('API key'));
  });

  test('unknown domain → typed "no data" error', () async {
    final c = _container(_replying('unused'));
    addTearDown(c.dispose);

    final state = await _settle(c, 'nonexistent');
    expect(state.hasError, isTrue);
    final err = state.error;
    expect(err, isA<WeakAreaException>());
    expect((err as WeakAreaException).needsKey, isFalse);
    expect(err.message, contains('No readiness data'));
  });
}
