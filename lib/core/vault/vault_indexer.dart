import 'dart:convert';

import 'package:drift/drift.dart';

import '../../shared/models/card.dart';
import '../database/database.dart';
import 'card_parser.dart';
import 'vault_source.dart';

/// Outcome of a [VaultIndexer.reindex] pass.
class IndexResult {
  const IndexResult({
    required this.cards,
    required this.idless,
    required this.malformed,
    required this.skipped,
  });

  /// Successfully parsed cards — the in-memory index the app reads from.
  final List<Card> cards;

  /// Files with a valid card `type` but no `id`. Surfaced in Settings so the
  /// user can add UUIDs; skipped for now.
  final int idless;

  /// Files that are cards (valid type + id) but structurally invalid.
  final int malformed;

  /// Non-card files skipped (no recognized `type`).
  final int skipped;

  int get cardCount => cards.length;
}

/// Walks a [VaultSource], parses every file, and rebuilds the derived SQLite
/// caches (`card_cache` + `card_links`) in a single transaction.
///
/// The vault remains the source of truth — this only populates fast-query
/// metadata and graph edges, both fully reconstructable from the files.
class VaultIndexer {
  VaultIndexer(
    this._source,
    this._db, {
    CardParser parser = const CardParser(),
  }) : _parser = parser;

  final VaultSource _source;
  final AppDatabase _db;
  final CardParser _parser;

  Future<IndexResult> reindex() async {
    final cards = <Card>[];
    var idless = 0;
    var malformed = 0;
    var skipped = 0;

    for (final path in await _source.listCardPaths()) {
      final content = await _source.readCard(path);
      try {
        final card = _parser.parse(content, filePath: path);
        if (card == null) {
          skipped++;
        } else {
          cards.add(card);
        }
      } on MissingCardIdException {
        idless++;
      } on MalformedCardException {
        malformed++;
      }
    }

    // Wikilinks target filenames (without `.md`); resolve them to card ids so
    // card_links stores id→id edges. Unresolved links (e.g. to notes outside
    // Flashcards/) are simply omitted, matching the documented behavior.
    final idByFilename = {
      for (final card in cards) _filenameSlug(card.filePath): card.id,
    };
    final indexedAt = DateTime.now();

    await _db.transaction(() async {
      await _db.delete(_db.cardCache).go();
      await _db.delete(_db.cardLinks).go();

      for (final card in cards) {
        await _db.into(_db.cardCache).insert(_cacheRow(card, indexedAt));
        for (final target in card.wikilinks) {
          final toId = idByFilename[target];
          if (toId != null && toId != card.id) {
            await _db.into(_db.cardLinks).insert(
                  CardLinksCompanion.insert(fromCard: card.id, toCard: toId),
                  mode: InsertMode.insertOrIgnore,
                );
          }
        }
      }
    });

    return IndexResult(
      cards: cards,
      idless: idless,
      malformed: malformed,
      skipped: skipped,
    );
  }

  CardCacheCompanion _cacheRow(Card card, DateTime indexedAt) =>
      CardCacheCompanion.insert(
        cardId: card.id,
        title: card.title,
        cardType: card.type.value,
        tags: jsonEncode(card.tags),
        tiers: jsonEncode(card.tiers),
        category: Value(card.category),
        difficulty: Value(card.difficulty),
        frequency: Value(card.frequency),
        practiceUrl: Value(card.practiceUrl),
        filePath: card.filePath,
        indexedAt: indexedAt,
      );

  /// `flashcards/binary-search.md` → `binary-search` (the wikilink target form).
  String _filenameSlug(String path) {
    final name = path.split('/').last;
    return name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
  }
}
