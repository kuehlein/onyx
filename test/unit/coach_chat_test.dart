import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onyx/core/ai/claude_service.dart';
import 'package:onyx/core/ai/coach_update_chat.dart';
import 'package:onyx/core/coach/coach_update.dart';
import 'package:onyx/shared/providers/ai.dart';
import 'package:onyx/shared/providers/coach_chat.dart';

const _update = CoachUpdate(
  kind: CoachInsightKind.overloaded,
  tone: CoachTone.caution,
  headline: 'Reviews are piling up — ease off new cards.',
  why: 'You have a lot due and recall is slipping.',
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

void main() {
  group('buildCoachChatSystem', () {
    test('seeds the nudge, the numbers, and the strategist rules', () {
      final s = buildCoachChatSystem(
        update: _update,
        overallPct: 42,
        coveragePct: 30,
        targetLabel: 'Senior · FAANG · General',
        daysToInterview: 21,
      );
      expect(s, contains('Reviews are piling up')); // the nudge
      expect(s, contains('42%'));
      expect(s, contains('30%'));
      expect(s, contains('Senior · FAANG · General'));
      expect(s, contains('interview in 21 days'));
      // Research-grounded coaching stance.
      expect(s, contains('implementation intention'));
      expect(s.toLowerCase(), contains('autonomy-supportive'));
      expect(s, contains('ONE'));
    });

    test('says when no interview date is set', () {
      final s = buildCoachChatSystem(
        update: _update,
        overallPct: 42,
        coveragePct: 30,
        targetLabel: 'goal',
      );
      expect(s, contains('no interview date set'));
    });
  });

  group('CoachChat', () {
    test('send appends the user turn and the reply', () async {
      String? body;
      final c = ProviderContainer(overrides: [
        claudeServiceProvider.overrideWithValue(
            _replying('Cut new cards to 10/day.', onBody: (b) => body = b)),
      ]);
      addTearDown(c.dispose);

      await c
          .read(coachChatProvider.notifier)
          .send('How do I catch up?', system: 'SYSTEM-PROMPT');

      final state = c.read(coachChatProvider);
      expect(state.busy, isFalse);
      expect(state.error, isNull);
      expect(state.messages, hasLength(2));
      expect(state.messages.first.role, CoachRole.user);
      expect(state.messages.first.text, 'How do I catch up?');
      expect(state.messages.last.role, CoachRole.assistant);
      expect(state.messages.last.text, contains('Cut new cards'));
      // The system prompt was actually sent.
      expect(jsonDecode(body!)['system'], 'SYSTEM-PROMPT');
    });

    test('empty input is ignored', () async {
      final c = ProviderContainer(overrides: [
        claudeServiceProvider.overrideWithValue(_replying('nope')),
      ]);
      addTearDown(c.dispose);
      await c.read(coachChatProvider.notifier).send('   ', system: 's');
      expect(c.read(coachChatProvider).isEmpty, isTrue);
    });

    test('no API key → error, no crash', () async {
      final c = ProviderContainer(overrides: [
        claudeServiceProvider.overrideWithValue(null),
      ]);
      addTearDown(c.dispose);
      await c.read(coachChatProvider.notifier).send('hi', system: 's');
      expect(c.read(coachChatProvider).error, contains('API key'));
    });

    test('surfaces a ClaudeException message', () async {
      final claude = ClaudeService(
        apiKey: 'k',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': {'message': 'rate limited'}
              }),
              429,
            )),
      );
      final c = ProviderContainer(
          overrides: [claudeServiceProvider.overrideWithValue(claude)]);
      addTearDown(c.dispose);
      await c.read(coachChatProvider.notifier).send('hi', system: 's');
      final state = c.read(coachChatProvider);
      expect(state.error, contains('rate limited'));
      // The user turn stays; only the reply is missing.
      expect(state.messages, hasLength(1));
    });
  });
}
