import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/glossary.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';

void main() {
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

    test('load parses the vault note', () async {
      final source = DesktopVaultSource(root.path);
      await source.writeMeta(GlossaryService.fileName,
          '# Glossary\n\n## DNS\nDomain Name System.\n');
      final loaded = await GlossaryService(source: source).load();
      expect(loaded['dns'], contains('Domain Name System'));
    });

    test('load returns empty when no note exists', () async {
      final loaded =
          await GlossaryService(source: DesktopVaultSource(root.path)).load();
      expect(loaded, isEmpty);
    });
  });
}
