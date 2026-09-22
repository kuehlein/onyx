import '../vault/vault_source.dart';
import 'target.dart';

/// Reads the legacy [ReadinessTarget] JSON (`onyx-target.json`) from the vault's
/// `_meta/` folder. Retained as the one-time **migration** source folded into the
/// default study goal (see aim_migration.dart); the target now persists on the
/// goal via GoalStore, so this is read-only.
class TargetService {
  TargetService(this._source);

  final VaultSource _source;

  static const fileName = 'onyx-target.json';

  Future<ReadinessTarget?> load() async =>
      ReadinessTarget.tryDecode(await _source.readMeta(fileName));
}
