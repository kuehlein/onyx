import 'dart:convert';

import '../vault/vault_source.dart';
import 'deck.dart';

/// Persists the user's decks as app-managed config in the vault's config dir
/// (`_onyx/`, ADR-0019). Each deck is its own **cluster** — `decks/<id>/deck.json`
/// (the lens + priority + state + template ref) and `decks/<id>/aims.json` (the aims
/// as authored) — so two devices editing different decks touch different files
/// (killing the whole-blob last-write-wins the flat `study-goals.json` had), and the
/// teacher-owned aims definition sits physically apart from learner state (ADR-0021).
///
/// **Read-compat / migration:** a legacy vault stores every deck in one
/// `study-goals.json` blob. [load] prefers per-deck dirs and falls back to that blob,
/// so an un-migrated vault still reads; [save] always writes per-deck dirs and retires
/// the blob, so the first save migrates. (The provider does a proactive write-through
/// so a read-only user migrates too.) The legacy `_meta/` copy, if any, is left as a
/// read-only fallback and swept when the legacy readers are removed (ADR-0019 §4).
///
/// The implicit default (whole-vault) deck is synthesized from the primary template,
/// so an empty/absent store means "single default deck", identical to pre-#30d. Once
/// the user sets a target/interview on that default deck (Phase B), it persists here
/// like any deck (keyed by [defaultDeckId]).
class DeckStore {
  DeckStore(this._source);

  final VaultSource _source;

  /// The legacy single-blob file (pre-ADR-0019). Read as a fallback + migration
  /// source when no per-deck dirs exist; **never written** anymore.
  static const fileName = 'study-goals.json';

  /// The per-deck cluster dir under the config dir: `decks/<id>/…`.
  static const decksDir = 'decks';
  static const _deckFile = 'deck.json';
  static const _aimsFile = 'aims.json';

  static String _deckPath(String id) => '$decksDir/$id/$_deckFile';
  static String _aimsPath(String id) => '$decksDir/$id/$_aimsFile';

  Future<List<Deck>> load() async {
    // Prefer the per-deck layout (the current shape); fall back to the legacy blob.
    final ids = await _deckIds();
    return ids.isEmpty ? _loadBlob() : _loadPerDeck(ids);
  }

  /// Deck ids that have a `decks/<id>/deck.json`, sorted for determinism. A dir with
  /// only an `aims.json` (no `deck.json`) is not a deck — a deck exists iff its
  /// `deck.json` does.
  Future<List<String>> _deckIds() async {
    final files = await _source.listMeta(decksDir);
    final ids = <String>[];
    for (final path in files) {
      final parts = path.split('/'); // decks/<id>/deck.json
      if (parts.length == 3 && parts[2] == _deckFile) ids.add(parts[1]);
    }
    ids.sort();
    return ids;
  }

  Future<List<Deck>> _loadPerDeck(List<String> ids) async {
    final out = <Deck>[];
    for (final id in ids) {
      // Per-deck tolerance mirrors the blob path: skip one malformed/hand-edited
      // cluster rather than dropping every deck (which the next save would persist).
      try {
        final deckRaw = await _source.readMeta(_deckPath(id));
        if (deckRaw == null) continue;
        final deckJson = (jsonDecode(deckRaw) as Map).cast<String, dynamic>();
        final aims = _parseAims(await _source.readMeta(_aimsPath(id)));
        out.add(Deck.fromJson({
          ...deckJson,
          if (aims.isNotEmpty) 'interviews': aims,
        }));
      } catch (_) {
        // Drop only this cluster; keep the rest.
      }
    }
    return out;
  }

  /// The aims array from an `aims.json` body (empty on absent/blank/unparseable).
  List<dynamic> _parseAims(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final v = jsonDecode(raw);
      return v is List ? v : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<Deck>> _loadBlob() async {
    final raw = await _source.readMeta(fileName);
    if (raw == null || raw.trim().isEmpty) return const [];
    final List<dynamic> list;
    try {
      list = jsonDecode(raw) as List;
    } catch (_) {
      return const []; // whole file unparseable → fall back to the default deck
    }
    // Parse PER-ENTRY: skip a single malformed deck rather than dropping the whole
    // list — one bad/hand-edited row (a synced vault is user-editable) must never
    // erase every deck (which the next save would then persist). Defensive reads in
    // Deck.fromJson mean most bad *fields* degrade rather than throw.
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

  /// One-time migration: if the store is still the legacy single blob (no per-deck
  /// clusters yet) but the blob holds decks, rewrite them into per-deck clusters and
  /// retire the blob (ADR-0019 §4). Idempotent + meant to be best-effort — a no-op
  /// once clusters exist, or when there's nothing (parseable) to migrate. Returns
  /// whether it migrated. Lets a read-only user (who never triggers a [save]) still
  /// stop depending on the blob; a mutating user migrates via [save] anyway.
  Future<bool> migrateBlobToClusters() async {
    if ((await _deckIds()).isNotEmpty) return false; // already per-deck
    final blob = await _loadBlob();
    if (blob.isEmpty) return false; // nothing to migrate (empty/unparseable)
    await save(blob);
    return true;
  }

  Future<void> save(List<Deck> goals) async {
    final keep = {for (final g in goals) g.id};
    // Write each deck's cluster (each writeMeta is atomic). Skip a file whose content
    // is byte-identical to disk: editing one deck must not rewrite every *other*
    // deck's files — that's what shrinks the merge grain to a single deck so a
    // folder-syncer only conflicts on the deck two devices actually both touched
    // (ADR-0019 §3), instead of the whole-blob LWW the flat file had. aims.json is
    // always present (`[]` when empty) so a deck that loses its last aim leaves no
    // stale aims behind.
    for (final g in goals) {
      final deckJson = jsonEncode(g.copyWith(aims: const []).toJson());
      final aimsJson = jsonEncode([for (final a in g.aims) a.toJson()]);
      if (await _source.readMeta(_deckPath(g.id)) != deckJson) {
        await _source.writeMeta(_deckPath(g.id), deckJson);
      }
      if (await _source.readMeta(_aimsPath(g.id)) != aimsJson) {
        await _source.writeMeta(_aimsPath(g.id), aimsJson);
      }
    }
    // Drop clusters for decks that no longer exist — else load() re-reads a removed
    // deck straight back in.
    for (final id in await _deckIds()) {
      if (!keep.contains(id)) await _source.deleteMeta('$decksDir/$id');
    }
    // Retire the legacy blob in the current config dir now that per-deck dirs are the
    // truth (a legacy `_meta/` copy is left as a read-only fallback, ADR-0019 §4).
    await _source.deleteMeta(fileName);
  }
}
