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
      expect(terms.contains('OK'), isFalse);
      expect(terms.contains('A'), isFalse);
    });
  });

  group('parseGlossaryNote', () {
    test('parses ## Term sections into a slug→definition map', () {
      const note = '''
# Glossary

## API
Application Programming Interface — endpoints one program exposes.

## Load Balancer
Distributes traffic across servers.
''';
      final map = parseGlossaryNote(note);
      expect(map['api'], contains('Application Programming'));
      expect(map['load-balancer'], contains('Distributes traffic'));
    });

    test('glossarySlug lowercases and hyphenates', () {
      expect(glossarySlug('API'), 'api');
      expect(glossarySlug('Load Balancer'), 'load-balancer');
    });
  });

  group('GlossaryService', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('onyx_gloss_'));
    tearDown(() => root.deleteSync(recursive: true));

    test('draft writes a Markdown note; load parses it back', () async {
      final source = DesktopVaultSource(root.path);
      final claude = ClaudeService(
        apiKey: 'k',
        client: _client(
            '# Glossary\n\n## DNS\nDomain Name System.\n\n## TCP\nTransmission Control Protocol.\n'),
      );

      final count =
          await GlossaryService(source: source, claude: claude).draft({'DNS'});
      expect(count, 2);
      expect(
        File('${root.path}/_meta/${GlossaryService.fileName}').existsSync(),
        isTrue,
      );

      final loaded = await GlossaryService(source: source).load();
      expect(loaded['dns'], contains('Domain Name System'));
      expect(loaded['tcp'], contains('Transmission'));
    });

    test('draft tolerates a ```markdown fence around the reply', () async {
      final source = DesktopVaultSource(root.path);
      final claude = ClaudeService(
        apiKey: 'k',
        client: _client('```markdown\n# Glossary\n\n## DER\nDistinguished '
            'Encoding Rules.\n```'),
      );
      final count =
          await GlossaryService(source: source, claude: claude).draft({'DER'});
      expect(count, 1);
      expect((await GlossaryService(source: source).load())['der'],
          contains('Distinguished'));
    });

    test('load returns empty when no note exists', () async {
      final loaded =
          await GlossaryService(source: DesktopVaultSource(root.path)).load();
      expect(loaded, isEmpty);
    });
  });
}
