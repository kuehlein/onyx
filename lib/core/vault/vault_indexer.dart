import 'dart:convert';

import 'package:drift/drift.dart';

import '../../shared/models/card.dart';
import '../database/database.dart';
import '../query/card_query.dart';
import '../template/active_template.dart';
import '../template/template_registry.dart';
import 'card_parser.dart';
import 'vault_source.dart';

/// Outcome of a [VaultIndexer.reindex] pass.
class IndexResult {
  const IndexResult({
    required this.cards,
    required this.malformed,
    required this.skipped,
    this.unresolvedLinks = const [],
    this.conflictCopies = const [],
    this.collisions = const [],
    this.unlensed = 0,
  });

  /// Successfully parsed cards — the in-memory index the app reads from.
  final List<Card> cards;

  /// Files that are cards (valid type) but structurally invalid.
  final int malformed;

  /// Non-card files skipped (no recognized `type`).
  final int skipped;

  /// Dangling `[[wikilinks]]` — targets with no matching `.md` file (task #20).
  final List<UnresolvedLink> unresolvedLinks;

  /// Folder-syncer **conflict-copy** files detected during the walk (relative
  /// paths). Skipped — never parsed into cards, so they can't mint a duplicate card
  /// id — and surfaced so the user can review/delete them (ADR-0019/0021).
  final List<String> conflictCopies;

  /// Relative paths of cards that collided on `cardId` — a second (or later) file
  /// resolving to a `cardId` already claimed by an earlier one (ADR-0022: two files
  /// with the same explicit `id:`, or the same filename slug across folders). The
  /// FIRST (by sorted path) wins and indexes; the rest are **skipped, not merged** —
  /// letting both into `card_cache`/SRS would fuse their schedules under one key.
  /// Surfaced so the user can disambiguate.
  final List<String> collisions;

  /// Parsed cards that no deck's membership lens claims — not cards (ADR-0023:
  /// card-ness = deck-lens membership), dropped from the index. Surfaced as a count
  /// so a vault of notes with no matching deck reads as "0 cards, N notes present"
  /// rather than silently empty. Zero when no lens gate is applied (direct-parse
  /// tests / a fresh vault with no decks → keep-all).
  final int unlensed;

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
    TemplateRegistry? registry,
    List<CardQuery> lenses = const [],
  })  : _parser = parser,
        _registry = registry,
        _lenses = lenses;

  final VaultSource _source;
  final AppDatabase _db;
  final CardParser _parser;

  /// The membership lenses of every deck in the vault (ADR-0023). Card-ness = a
  /// parsed card matched by at least one — the union is the single grouping knob.
  /// Empty (direct-parse tests / a fresh vault with no decks) = no gate → keep all.
  final List<CardQuery> _lenses;

  /// The subjects live in this vault; each card is stamped with the subject that
  /// owns its path (task #30d). Falls back to the process-wide [activeRegistry]
  /// (a one-entry registry in single-subject vaults).
  final TemplateRegistry? _registry;

  Future<IndexResult> reindex() async {
    final cards = <Card>[];
    var malformed = 0;
    var skipped = 0;
    var unlensed = 0;
    final conflictCopies = <String>[];
    final seenIds = <String>{};
    final collisions = <String>[];

    // Card-ness = matched by some deck's membership lens (ADR-0023). Strip any
    // dynamic (study-state) leaf first: card-ness is parse-time/structural, never
    // runtime-computed, so a card never blinks in/out of existence as it's studied.
    // No lenses (direct-parse tests / a fresh vault) = no gate → keep all.
    final gates = [for (final l in _lenses) stripDynamic(l)];
    bool inSomeLens(Card c) => gates.isEmpty || gates.any((g) => g.matches(c));

    final registry = _registry ?? activeRegistry;
    final paths = await _source.listCardPaths();
    for (final path in paths) {
      // A folder-syncer conflict copy carries the original's frontmatter verbatim
      // (same id) — parsing it would duplicate a card id. Skip + report, never parse.
      if (isConflictCopy(path)) {
        conflictCopies.add(path);
        continue;
      }
      final content = await _source.readCard(path);
      try {
        final card = _parser.parse(
          content,
          filePath: path,
          templateId: registry.templateIdForPath(path),
        );
        if (card == null) {
          skipped++;
        } else if (!inSomeLens(card)) {
          // Parsed fine, but no deck's lens claims it → not a card (ADR-0023).
          // Dropped (not skipped/malformed); counted for diagnostics. Gate runs
          // before the collision check so an out-of-lens file can't shadow an
          // in-lens one that shares its id.
          unlensed++;
        } else if (!seenIds.add(card.id)) {
          // Its cardId is already claimed by an earlier (sorted-first) file —
          // indexing both would fuse their schedules under one key. Skip + report,
          // never merge (ADR-0022). `paths` is sorted, so "first wins" is stable.
          collisions.add(path);
        } else {
          cards.add(card);
        }
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
      malformed: malformed,
      skipped: skipped,
      unresolvedLinks: unresolvedLinks,
      conflictCopies: conflictCopies,
      collisions: collisions,
      unlensed: unlensed,
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
