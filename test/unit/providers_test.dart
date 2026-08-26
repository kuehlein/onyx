import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/vault.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// See database_test.dart — skip when host libsqlite3 is unavailable.
final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

const _card = '''
---
id: aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa
type: flashcard
tags: [ds-a]
tiers:
  ds-a: 1
created: 2026-08-19
---

# A

x

## When to Use

y
''';

void main() {
  group('vault providers', () {
    late Directory root;

    ProviderContainer container(String? vaultPath) => ProviderContainer(
          overrides: [
            vaultSourceProvider.overrideWithValue(
              vaultPath == null ? null : DesktopVaultSource(vaultPath),
            ),
            appDatabaseProvider.overrideWith((ref) {
              final db = AppDatabase.withExecutor(NativeDatabase.memory());
              ref.onDispose(db.close);
              return db;
            }),
          ],
        );

    setUp(() {
      root = Directory.systemTemp.createTempSync('onyx_prov_');
      File(p.join(root.path, 'a.md')).writeAsStringSync(_card);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('vaultIndex composes source + db and populates the cache', () async {
      final c = container(root.path);
      addTearDown(c.dispose);

      final result = await c.read(vaultIndexProvider.future);
      expect(result.cardCount, 1);

      final db = c.read(appDatabaseProvider);
      expect((await db.select(db.cardCache).get()).length, 1);
    });

    test('vaultIndex is empty when no vault is configured', () async {
      final c = container(null);
      addTearDown(c.dispose);

      final result = await c.read(vaultIndexProvider.future);
      expect(result.cardCount, 0);
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
