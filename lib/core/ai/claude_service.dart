import 'dart:convert';

import 'package:http/http.dart' as http;

/// A failure talking to the Anthropic API — carries a user-presentable message
/// and, for HTTP failures, the status code (401 = key rejected/expired).
class ClaudeException implements Exception {
  ClaudeException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'ClaudeException: $message';
}

/// Minimal client for the Anthropic Messages API. Local-first: the request goes
/// straight from the device to Anthropic with the user's own key (stored in the
/// Keychain) — there is no Onyx server in the middle.
class ClaudeService {
  ClaudeService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  /// Fast, low-cost default for the app's high-frequency AI helpers (coaching,
  /// glossary). Callers can override per request.
  static const defaultModel = 'claude-haiku-4-5-20251001';

  static final _endpoint = Uri.parse('https://api.anthropic.com/v1/messages');
  static const _version = '2023-06-01';

  /// Sends a single-turn prompt and returns the concatenated text reply.
  Future<String> complete({
    required String prompt,
    String? system,
    String model = defaultModel,
    int maxTokens = 1024,
  }) =>
      chat(
        messages: [(role: 'user', content: prompt)],
        system: system,
        model: model,
        maxTokens: maxTokens,
      );

  /// Sends a multi-turn conversation and returns the concatenated text reply.
  /// [messages] must alternate/begin with a `user` turn (Anthropic's rule);
  /// the coach builds this from its running history.
  Future<String> chat({
    required List<({String role, String content})> messages,
    String? system,
    String model = defaultModel,
    int maxTokens = 1024,
  }) async {
    final http.Response response;
    try {
      response = await _client.post(
        _endpoint,
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': _version,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': maxTokens,
          if (system != null) 'system': system,
          'messages': [
            for (final m in messages) {'role': m.role, 'content': m.content},
          ],
        }),
      );
    } catch (e) {
      throw ClaudeException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw ClaudeException(_errorMessage(response),
          statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final blocks = (data['content'] as List?) ?? const [];
    return blocks
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String? ?? '')
        .join()
        .trim();
  }

  String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
    } catch (_) {
      // fall through to a generic message
    }
    return 'Request failed (HTTP ${response.statusCode})';
  }

  void dispose() => _client.close();
}
