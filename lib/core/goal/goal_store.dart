import 'dart:convert';

import '../vault/vault_source.dart';
import 'study_goal.dart';

/// Persists the user's study goals as app-managed state in the vault's `_meta/`
/// (task #30d) — the deadline, budget split, target selection, and membership
/// query per goal. This is *not* hand-edited content (per the vault conventions),
/// so it lives in `_meta/`, unlike the authored subject templates and cards.
///
/// The implicit default (whole-vault) goal is never stored — it's synthesized from
/// the primary template — so an empty/absent file means "single default goal",
/// identical to pre-#30d behavior.
class GoalStore {
  GoalStore(this._source);

  final VaultSource _source;

  static const fileName = 'study-goals.json';

  Future<List<StudyGoal>> load() async {
    final raw = await _source.readMeta(fileName);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          StudyGoal.fromJson((e as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return const []; // malformed → fall back to the default goal
    }
  }

  Future<void> save(List<StudyGoal> goals) => _source.writeMeta(
        fileName,
        jsonEncode([for (final g in goals) g.toJson()]),
      );
}
