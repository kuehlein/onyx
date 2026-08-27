import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onyx/core/ai/claude_service.dart';
import 'package:onyx/core/ai/glossary.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';

http.Client _client(String replyText) => MockClient((_) async => http.Response(
      jsonEncode({
        'content': [
          {'type': 'text', 'text': replyText},
        ],
      }),
      200,
    ));

void main() {
  group('detectGlossaryTerms', () {
    test('finds acronyms, skips stopwords and single letters', () {
      final terms = detectGlossaryTerms([
        'Use HTTP over TCP; the API resolves via DNS.',
        'A note: OK, TODO later. A single X, and O(1).',
      ]);
      expect(terms, containsAll({'HTTP', 'TCP', 'API', 'DNS'}));
      expect(terms.contains('OK'), isFalse); // stop word
      expect(terms.contains('TODO'), isFalse);
      expect(terms.contains('A'), isFalse); // single letter
      expect(terms.contains('X'), isFalse);
    });
  });

  group('GlossaryService', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('onyx_gloss_'));
    tearDown(() => root.deleteSync(recursive: true));

    test('generate writes the vault file; load reads it back', () async {
      final source = DesktopVaultSource(root.path);
      final claude = ClaudeService(
        apiKey: 'k',
        client: _client(jsonEncode({
          'HTTP': 'HyperText Transfer Protocol.',
          'TCP': 'Transmission Control Protocol.',
        })),
      );

      final map = await GlossaryService(source: source, claude: claude)
          .generate({'HTTP', 'TCP'});
      expect(map['HTTP'], contains('HyperText'));
      expect(
        File('${root.path}/_meta/${GlossaryService.fileName}').existsSync(),
        isTrue,
      );

      final loaded = await GlossaryService(source: source).load();
      expect(loaded['TCP'], contains('Transmission'));
    });

    test('tolerates a ```json fence around the reply', () async {
      final source = DesktopVaultSource(root.path);
      final claude = ClaudeService(
        apiKey: 'k',
        client: _client('```json\n{"DNS": "Domain Name System."}\n```'),
      );
      final map = await GlossaryService(source: source, claude: claude)
          .generate({'DNS'});
      expect(map['DNS'], 'Domain Name System.');
    });

    test('load returns empty when no glossary exists', () async {
      final loaded =
          await GlossaryService(source: DesktopVaultSource(root.path)).load();
      expect(loaded, isEmpty);
    });
  });
}
