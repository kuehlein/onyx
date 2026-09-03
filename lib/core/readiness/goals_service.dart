import '../dev.dart';
import '../vault/vault_source.dart';
import 'prep_goal.dart';

/// Persists the list of interview [PrepGoal]s to a JSON file in the vault's
/// `_meta/` folder, so they sync across devices via Obsidian — same durability
/// as [TargetService] (which stores the base target), but its own file since a
/// learner can hold several goals.
class GoalsService {
  GoalsService(this._source);

  final VaultSource _source;

  /// Dev builds use a separate file so device/desktop testing can't pollute the
  /// real synced interviews (mirrors the study snapshot's dev isolation).
  static String get fileName =>
      isDevDataMode ? 'onyx-goals.dev.json' : 'onyx-goals.json';

  Future<List<PrepGoal>> load() async =>
      PrepGoal.decodeList(await _source.readMeta(fileName));

  Future<void> save(List<PrepGoal> goals) =>
      _source.writeMeta(fileName, PrepGoal.encodeList(goals));
}
