import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onyx/core/ai/claude_service.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/providers/ai.dart';
import 'package:onyx/shared/providers/card_generation.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/vault.dart';

const _parser = CardParser();

/// A canned `<cards>` reply from the model — one line of prose + the tagged block.
const _reply = 'Made 2 cards on TCP.\n'
    '<cards>{"name":"TCP basics","cards":['
    '{"title":"TCP handshake","tags":["tcp","networking"],"sections":['
    '{"heading":"When to Use","content":"Reliable, ordered delivery."}]},'
    '{"title":"Flow control","tags":["tcp"],"sections":['
    '{"heading":"Key idea","content":"The receiver advertises a window."}]}'
    ']}</cards>';

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

ProviderContainer _container(
        ClaudeService? claude, DesktopVaultSource? source) =>
    ProviderContainer(overrides: [
      claudeServiceProvider.overrideWithValue(claude),
      // Always override the source (even to null) so the real provider can't fall
      // back to ONYX_VAULT_PATH from the dev-shell environment.
      vaultSourceProvider.overrideWithValue(source),
      clockProvider.overrideWith((ref) async => Clock.real),
    ]);

void main() {
  group('CardGeneration.generate', () {
    late Directory root;
    late DesktopVaultSource source;

    setUp(() {
      root = Directory.systemTemp.createTempSync('onyx_gen_svc_');
      source = DesktopVaultSource(root.path);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('writes the cards + returns the count', () async {
      String? body;
      final c = _container(_replying(_reply, onBody: (b) => body = b), source);
      addTearDown(c.dispose);

      final count = await c
          .read(cardGenerationProvider.notifier)
          .generate('teach me TCP');
      expect(count, 2);

      // The learner's input went in the USER message (not the system prompt).
      final sent = jsonDecode(body!) as Map<String, dynamic>;
      expect((sent['messages'] as List).single['content'], 'teach me TCP');
      expect(sent['model'], 'claude-sonnet-4-6');

      // The files were actually written as local drafts.
      final paths = await source.listCardPaths();
      expect(paths.length, 2);
      for (final path in paths) {
        final card =
            _parser.parse(await source.readCard(path), filePath: path)!;
        expect(card.isDraft, isTrue);
        expect(card.deckId, '');
      }
    });

    test('no API key → clear typed error, nothing written', () async {
      final c = _container(null, source);
      addTearDown(c.dispose);
      await expectLater(
        c.read(cardGenerationProvider.notifier).generate('x'),
        throwsA(isA<CardGenerationException>()
            .having((e) => e.message, 'message', contains('AI key'))),
      );
      expect(await source.listCardPaths(), isEmpty);
    });

    test('no folder → clear typed error', () async {
      final c = _container(_replying(_reply), null);
      addTearDown(c.dispose);
      await expectLater(
        c.read(cardGenerationProvider.notifier).generate('x'),
        throwsA(isA<CardGenerationException>()
            .having((e) => e.message, 'message', contains('study folder'))),
      );
    });

    test('empty input → error before any network call', () async {
      var called = false;
      final c = _container(
        _replying(_reply, onBody: (_) => called = true),
        source,
      );
      addTearDown(c.dispose);
      await expectLater(
        c.read(cardGenerationProvider.notifier).generate('   '),
        throwsA(isA<CardGenerationException>()),
      );
      expect(called, isFalse);
    });

    test('reply with no <cards> block → "try rephrasing" error', () async {
      final c = _container(_replying('I need more detail first.'), source);
      addTearDown(c.dispose);
      await expectLater(
        c.read(cardGenerationProvider.notifier).generate('vague'),
        throwsA(isA<CardGenerationException>()
            .having((e) => e.message, 'message', contains('rephrasing'))),
      );
      expect(await source.listCardPaths(), isEmpty);
    });

    test('a Claude API failure surfaces its message', () async {
      final claude = ClaudeService(
        apiKey: 'bad',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': {'type': 'authentication_error', 'message': 'bad key'},
              }),
              401,
            )),
      );
      final c = _container(claude, source);
      addTearDown(c.dispose);
      await expectLater(
        c.read(cardGenerationProvider.notifier).generate('x'),
        throwsA(isA<CardGenerationException>()
            .having((e) => e.message, 'message', contains('bad key'))),
      );
    });
  });
}
