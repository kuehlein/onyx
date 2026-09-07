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
    test('seeds the nudge, the numbers, both tracks, and the rules', () {
      final s = buildCoachChatSystem(
        update: _update,
        overallPct: 42,
        coveragePct: 30,
        targetLabel: 'Senior · FAANG · General',
        daysToInterview: 21,
        newPerDay: 12,
        retentionPct: 88,
        reviewBacklog: 40,
        algoMin: 2,
        algoMax: 5,
      );
      expect(s, contains('Reviews are piling up')); // the nudge
      expect(s, contains('42%'));
      expect(s, contains('30%'));
      expect(s, contains('Senior · FAANG · General'));
      expect(s, contains('interview in 21 days'));
      // Both adjustable tracks are described with current load.
      expect(s, contains('12 new cards/day'));
      expect(s, contains('88%'));
      expect(s, contains('40 reviews due'));
      expect(s, contains('2–5 problems/day'));
      // It knows how to propose a change.
      expect(s, contains('<set setting='));
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
        newPerDay: 12,
        reviewBacklog: 0,
        algoMin: 2,
        algoMax: 5,
      );
      expect(s, contains('no interview date set'));
    });
  });

  group('parseCoachChatReply', () {
    test('extracts a proposed change and strips the tag', () {
      final r = parseCoachChatReply('Sounds good — I\'ll bump the floor.\n'
          '<set setting="algo-min" delta="+1"/>');
      expect(r.text, 'Sounds good — I\'ll bump the floor.');
      expect(r.proposal?.setting, CoachSetting.algoMin);
      expect(r.proposal?.delta, 1);
    });

    test('handles negative deltas and each setting', () {
      expect(
          parseCoachChatReply('x <set setting="new-per-day" delta="-5"/>')
              .proposal,
          isA<CoachProposal>()
              .having((p) => p.setting, 'setting', CoachSetting.newCardsPerDay)
              .having((p) => p.delta, 'delta', -5));
      expect(
          parseCoachChatReply('<set setting="algo-max" delta="+2"/>')
              .proposal
              ?.setting,
          CoachSetting.algoMax);
    });

    test('no tag → no proposal, text untouched', () {
      final r = parseCoachChatReply('Just some advice, no change.');
      expect(r.proposal, isNull);
      expect(r.text, 'Just some advice, no change.');
    });

    test('a zero delta is ignored', () {
      expect(
          parseCoachChatReply('<set setting="algo-min" delta="0"/>').proposal,
          isNull);
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
