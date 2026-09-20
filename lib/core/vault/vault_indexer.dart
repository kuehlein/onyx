import 'dart:convert';

import 'package:drift/drift.dart';

import '../../shared/models/card.dart';
import '../database/database.dart';
import '../subject/active_subject.dart';
import '../subject/subject_registry.dart';
import 'card_parser.dart';
import 'vault_source.dart';

/// Outcome of a [VaultIndexer.reindex] pass.
class IndexResult {
  const IndexResult({
    required this.cards,
    required this.idless,
    required this.malformed,
    required this.skipped,
    this.unresolvedLinks = const [],
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

  /// Dangling `[[wikilinks]]` — targets with no matching `.md` file (task #20).
  final List<UnresolvedLink> unresolvedLinks;

  int get cardCount => cards.length;

  /// Cards eligible for scheduling + readiness — everything except unpromoted
  /// [CardStatus.draft] cards (ADR-0003). Schedulers and readiness/coverage read
  /// THIS; Browse reads [cards] (it shows drafts, marked "not counted"). Adding a
  /// new scheduler? Read [studyCards] and draft exclusion is automatic.
  List<Card> get studyCards =>
      cards.where((c) => !c.isDraft).toList(growable: false);
}

/// A `[[wikilink]]` whose target matches no `.md` file in the vault — a dangling
/// reference (a typo, or a note you meant to create). Surfaced by the
/// unresolved-links view (task #20) to keep the note graph tidy.
class UnresolvedLink {
  const UnresolvedLink({
    required this.fromCardId,
    required this.fromTitle,
    required this.target,
  });

  /// The card that contains the dangling link.
  final String fromCardId;
  final String fromTitle;

  /// The link target (a filename slug, no `.md`) that resolves to nothing.
  final String target;
}

/// Every wikilink whose [Card.wikilinks] target is absent from [fileStems] — the
/// set of ALL file name-stems in the vault (ANY extension: cards, plain notes,
/// attachments), so a link to a non-card file is NOT flagged and resolution
/// follows file-type support rather than assuming `.md`. Pure + order-preserving.
List<UnresolvedLink> computeUnresolvedLinks(
  List<Card> cards,
  Set<String> fileStems,
) =>
    [
      for (final card in cards)
        for (final target in card.wikilinks)
          if (!fileStems.contains(target))
            UnresolvedLink(
              fromCardId: card.id,
              fromTitle: card.title,
              target: target,
            ),
    ];

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
    SubjectRegistry? registry,
  })  : _parser = parser,
        _registry = registry;

  final VaultSource _source;
  final AppDatabase _db;
  final CardParser _parser;

  /// The subjects live in this vault; each card is stamped with the subject that
  /// owns its path (task #30d). Falls back to the process-wide [activeRegistry]
  /// (a one-entry registry in single-subject vaults).
  final SubjectRegistry? _registry;

  Future<IndexResult> reindex() async {
    final cards = <Card>[];
    var idless = 0;
    var malformed = 0;
    var skipped = 0;

    final registry = _registry ?? activeRegistry;
    final paths = await _source.listCardPaths();
    for (final path in paths) {
      final content = await _source.readCard(path);
      try {
        final card = _parser.parse(
          content,
          filePath: path,
          subjectId: registry.subjectIdForPath(path),
        );
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
    // card_links stores id→id edges (the card→card graph). A link whose target
    // isn't a card is omitted from card_links — but if it matches no `.md` file
    // at ALL (card or plain note) it's a dangling link, surfaced via #20.
    final idByFilename = {
      for (final card in cards) _fileStem(card.filePath): card.id,
    };
    // Resolve wikilinks against EVERY file (any extension), not just cards — a
    // link to a plain note (or a future .txt/.org card) isn't dangling. So a
    // target is unresolved only when no file of any type shares its name.
    final fileStems = {
      for (final path in await _source.listAllPaths()) _fileStem(path),
    };
    final unresolvedLinks = computeUnresolvedLinks(cards, fileStems);
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
      unresolvedLinks: unresolvedLinks,
    );
  }

  CardCacheCompanion _cacheRow(Card card, DateTime indexedAt) =>
      CardCacheCompanion.insert(
        cardId: card.id,
        title: card.title,
        cardType: card.type,
        tags: jsonEncode(card.tags),
        tiers: jsonEncode(card.tiers),
        category: Value(card.category),
        difficulty: Value(card.difficulty),
        frequency: Value(card.frequency),
        practiceUrl: Value(card.practiceUrl),
        filePath: card.filePath,
        indexedAt: indexedAt,
      );

  /// `flashcards/binary-search.md` → `binary-search` (the bare name a
  /// `[[wikilink]]` targets). Strips the folder + the LAST extension, so it works
  /// for any file type, not just `.md`.
  String _fileStem(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}
