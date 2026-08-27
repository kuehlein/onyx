import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onyx/core/ai/claude_service.dart';

void main() {
  group('ClaudeService', () {
    test('sends auth headers + prompt and returns the text reply', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'pong'},
            ],
          }),
          200,
        );
      });

      final reply = await ClaudeService(apiKey: 'sk-test', client: client)
          .complete(prompt: 'ping');

      expect(reply, 'pong');
      expect(captured.headers['x-api-key'], 'sk-test');
      expect(captured.headers['anthropic-version'], '2023-06-01');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect((body['messages'] as List).first['content'], 'ping');
    });

    test('concatenates multiple text blocks', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'a'},
                {'type': 'text', 'text': 'b'},
              ],
            }),
            200,
          ));
      expect(
        await ClaudeService(apiKey: 'k', client: client).complete(prompt: 'x'),
        'ab',
      );
    });

    test('throws ClaudeException with the API message on error', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'error': {
                'type': 'authentication_error',
                'message': 'invalid x-api-key',
              },
            }),
            401,
          ));

      expect(
        () =>
            ClaudeService(apiKey: 'bad', client: client).complete(prompt: 'x'),
        throwsA(isA<ClaudeException>().having(
            (e) => e.message, 'message', contains('invalid x-api-key'))),
      );
    });
  });
}
