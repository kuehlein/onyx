import '../vault/vault_source.dart';
import 'target.dart';

/// Persists the [ReadinessTarget] to a small JSON file in the vault's `_meta/`
/// folder, so the chosen level/company/track and interview date sync across
/// devices via Obsidian — the same durability guarantee as the progress
/// snapshot, but kept in its own file since it isn't derived from the database.
class TargetService {
  TargetService(this._source);

  final VaultSource _source;

  static const fileName = 'onyx-target.json';

  Future<ReadinessTarget?> load() async =>
      ReadinessTarget.tryDecode(await _source.readMeta(fileName));

  Future<void> save(ReadinessTarget target) =>
      _source.writeMeta(fileName, target.encode());
}
