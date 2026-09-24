import 'dart:convert';

import '../vault/vault_source.dart';
import 'deck.dart';

/// Persists the user's study goals as app-managed state in the vault's `_meta/`
/// (task #30d) — the deadline, budget split, target selection, and membership
/// query per goal. This is *not* hand-edited content (per the vault conventions),
/// so it lives in `_meta/`, unlike the authored subject templates and cards.
///
/// The implicit default (whole-vault) goal is synthesized from the primary
/// template, so an empty/absent file means "single default goal", identical to
/// pre-#30d behavior. Once the user sets a target/interview on that default goal
/// (Phase B), it persists here like any goal (keyed by [defaultDeckId]).
class DeckStore {
  DeckStore(this._source);

  final VaultSource _source;

  static const fileName = 'study-goals.json';

  Future<List<Deck>> load() async {
    final raw = await _source.readMeta(fileName);
    if (raw == null || raw.trim().isEmpty) return const [];
    final List<dynamic> list;
    try {
      list = jsonDecode(raw) as List;
    } catch (_) {
      return const []; // whole file unparseable → fall back to the default goal
    }
    // Parse PER-ENTRY: skip a single malformed deck rather than dropping the
    // whole list — one bad/hand-edited row (a synced vault is user-editable) must
    // never erase every deck (which the next save would then persist). Defensive
    // reads in Deck.fromJson mean most bad *fields* degrade rather than throw.
    final out = <Deck>[];
    for (final e in list) {
      if (e is! Map) continue;
      try {
        out.add(Deck.fromJson(e.cast<String, dynamic>()));
      } catch (_) {
        // Drop only this entry; keep the rest.
      }
    }
    return out;
  }

  Future<void> save(List<Deck> goals) => _source.writeMeta(
        fileName,
        jsonEncode([for (final g in goals) g.toJson()]),
      );
}
