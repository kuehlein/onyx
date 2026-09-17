import 'dart:convert';

import 'package:http/http.dart' as http;

/// A failure talking to the AI backend — carries a user-presentable message and,
/// for HTTP failures, the status code (401 = key/token rejected or expired).
class ClaudeException implements Exception {
  ClaudeException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'ClaudeException: $message';
}

/// Minimal client for the Anthropic Messages API shape.
///
/// Two transports behind one interface (ADR-0004):
///
///  * The default constructor is **BYO-key** — the request goes straight from the
///    device to Anthropic with the user's own key (local-first, no Onyx server in
///    the middle). This is the v1 path.
///  * [ClaudeService.managed] routes through the hosted "Onyx AI" proxy with a
///    bearer token. **Reserved** — no server exists yet, so the resolver never
///    selects it in v1; the proxy is expected to speak the same Messages API shape.
class ClaudeService {
  /// BYO-key: device → Anthropic directly with the user's own key.
  ClaudeService({required String apiKey, http.Client? client})
      : _endpoint = _anthropicEndpoint,
        _authHeaders = {'x-api-key': apiKey, 'anthropic-version': _version},
        _client = client ?? http.Client();

  /// Managed "Onyx AI" tier: device → Onyx proxy with a bearer token. Reserved
  /// (ADR-0004) — the proxy fronts the model provider so a non-technical user
  /// needs no key of their own.
  ClaudeService.managed({
    required Uri baseUrl,
    required String token,
    http.Client? client,
  })  : _endpoint = baseUrl,
        _authHeaders = {'authorization': 'Bearer $token'},
        _client = client ?? http.Client();

  final Uri _endpoint;
  final Map<String, String> _authHeaders;
  final http.Client _client;

  /// Fast, low-cost default for the app's high-frequency AI helpers (coaching,
  /// glossary). Callers can override per request.
  static const defaultModel = 'claude-haiku-4-5-20251001';

  static final _anthropicEndpoint =
      Uri.parse('https://api.anthropic.com/v1/messages');
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
          ..._authHeaders,
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
