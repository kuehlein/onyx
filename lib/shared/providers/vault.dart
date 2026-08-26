import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/vault/desktop_vault_source.dart';
import '../../core/vault/vault_indexer.dart';
import '../../core/vault/vault_source.dart';
import 'database.dart';

part 'vault.g.dart';

/// The current vault source, or null if none is configured yet.
///
/// Dev/desktop: set `ONYX_VAULT_PATH` (e.g. to `staging/flashcards`) and the app
/// reads that folder directly. On device the path/bookmark comes from the
/// Settings screen (persisted in `preferences`) — wired up alongside that screen.
@riverpod
VaultSource? vaultSource(Ref ref) {
  final envPath = Platform.environment['ONYX_VAULT_PATH'];
  if (envPath != null && envPath.isNotEmpty) {
    return DesktopVaultSource(envPath);
  }
  return null;
}

/// Indexes the vault and exposes the parsed cards plus diagnostic counts.
/// Re-run after edits or a re-sync with `ref.invalidate(vaultIndexProvider)`.
@riverpod
Future<IndexResult> vaultIndex(Ref ref) async {
  final source = ref.watch(vaultSourceProvider);
  if (source == null) {
    return const IndexResult(cards: [], idless: 0, malformed: 0, skipped: 0);
  }
  final db = ref.watch(appDatabaseProvider);
  return VaultIndexer(source, db).reindex();
}
