/// The ONE query language over the vault — behind both deck membership (a saved
/// *lens*) and Browse filtering (ADR-0013). A `CardQuery` is a boolean tree: leaf
/// predicates over card attributes, composed with [And] / [Or] / [Not].
///
/// Leaves split two ways (ADR-0013):
///  - **structural** ([TagIs], [FolderUnder], [TypeIs], [TierIs]) read stable card
///    attributes — usable in a persisted deck lens (a stable member set).
///  - **dynamic** ([StateIs]) reads FSRS study-state via a [QueryContext] — a
///    Browse-only filter, never persisted into a lens (would make membership drift
///    daily and break readiness/plan/analytics denominators).
///
/// G1 folded the former `MembershipQuery` in ([Everything]/[TagIs]/[FolderUnder]);
/// G2 adds the combinators + Browse's leaves. The text mini-language that builds
/// these arrives with Browse in G2b.
library;

import '../../shared/models/card.dart';

/// The runtime data a [StateIs] leaf needs — the per-section due dates + "now".
/// Structural leaves ignore it, so deck membership evaluates with none.
class QueryContext {
  const QueryContext({this.dueByKey = const {}, required this.now});

  /// `"cardId::sectionSlug"` → dueAt for *studied* sections (absent = never
  /// studied). Same shape the Browse mastery filter has always used.
  final Map<String, DateTime> dueByKey;
  final DateTime now;
}

sealed class CardQuery {
  const CardQuery();

  /// Whether [card] matches. Structural leaves read card attributes only; a
  /// dynamic leaf ([StateIs]) needs [ctx] and matches nothing without it.
  bool matches(Card card, [QueryContext? ctx]);

  Map<String, dynamic> toJson();

  /// The whole vault — a lens with no constraint. The canonical "match anything"
  /// node; serializes as the legacy `{'kind': 'all'}` so existing decks' JSON is
  /// unchanged on re-save.
  static const CardQuery everything = Everything();

  /// Rebuilds a query from its JSON. Back-compat: the legacy membership shapes
  /// (`{'kind': 'all' | 'tag' | 'folder'}`) still parse. Unknown/malformed →
  /// [everything] (safe: a lens falls back to the whole vault rather than
  /// silently selecting nothing).
  static CardQuery fromJson(Map<String, dynamic> json) =>
      switch (json['kind']) {
        'all' => everything,
        'tag' => TagIs((json['value'] ?? '') as String),
        'folder' => FolderUnder((json['value'] ?? '') as String),
        'domain' => DomainIs((json['value'] ?? '') as String),
        'type' => TypeIs((json['value'] ?? '') as String),
        'tier' => TierIs(_int(json['value'])),
        'state' => StateIs(_mastery(json['value']) ?? MasteryFilter.due),
        'and' => And(_children(json['of'])),
        'or' => Or(_children(json['of'])),
        'not' => Not(fromJson(_child(json['q']))),
        _ => everything,
      };

  static int _int(Object? v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  static List<CardQuery> _children(Object? v) => [
        if (v is List)
          for (final e in v)
            if (e is Map) fromJson(e.cast<String, dynamic>()),
      ];

  static Map<String, dynamic> _child(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : const {'kind': 'all'};
}

/// Every card in the vault (the single-deck / whole-vault case).
class Everything extends CardQuery {
  const Everything();

  @override
  bool matches(Card card, [QueryContext? ctx]) => true;

  @override
  Map<String, dynamic> toJson() => {'kind': 'all'};
}

/// Cards carrying [tag] (case-insensitive, leading `#` ignored) — the
/// cross-cutting selector that ignores folder structure entirely.
class TagIs extends CardQuery {
  TagIs(String tag) : tag = _normalize(tag);

  /// The tag to match, normalized (lowercase, no leading `#`).
  final String tag;

  static String _normalize(String raw) {
    final t = raw.trim();
    return (t.startsWith('#') ? t.substring(1) : t).toLowerCase();
  }

  @override
  bool matches(Card card, [QueryContext? ctx]) =>
      card.tags.any((t) => _normalize(t) == tag);

  @override
  Map<String, dynamic> toJson() => {'kind': 'tag', 'value': tag};
}

/// Cards under a vault subtree [path] (POSIX, relative to the root). An empty
/// path matches everything.
class FolderUnder extends CardQuery {
  FolderUnder(String path) : path = _trim(path);

  final String path;

  static String _trim(String raw) {
    var p = raw.trim();
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  @override
  bool matches(Card card, [QueryContext? ctx]) =>
      path.isEmpty ||
      card.filePath == path ||
      card.filePath.startsWith('$path/');

  @override
  Map<String, dynamic> toJson() => {'kind': 'folder', 'value': path};
}

/// Cards whose PRIMARY domain (`card.domain` = the first tag) is [domain]. This is
/// the Browse "Domain" facet + the `domain:` operator — deliberately first-tag, NOT
/// any-tag (`TagIs`, `tag:`/`tags:`): the vault is full of multi-tag cards, so
/// matching any tag would silently widen the filter (ADR-0013 §Addendum 2).
///
/// The match is **case-insensitive** (like [TagIs]) — so it doesn't matter that the
/// `domain:` operator lowercases its value while the Domain chip passes it raw, and
/// a rendered `domain:Graphs` re-parses to the same member set. (Vault domains are
/// lowercase in practice, so this is byte-identical for the shipped content; it only
/// matters once a card's first tag is mixed-case, where raw `==` used to corrupt the
/// member set on a renderLens→parseLens round-trip — the post-review fix.)
class DomainIs extends CardQuery {
  const DomainIs(this.domain);

  final String domain;

  @override
  bool matches(Card card, [QueryContext? ctx]) =>
      card.domain?.toLowerCase() == domain.toLowerCase();

  @override
  Map<String, dynamic> toJson() => {'kind': 'domain', 'value': domain};
}

/// Cards of a card [type] (a flow id, e.g. `flashcard` / `interview-question`).
class TypeIs extends CardQuery {
  const TypeIs(this.type);

  final String type;

  @override
  bool matches(Card card, [QueryContext? ctx]) => card.type == type;

  @override
  Map<String, dynamic> toJson() => {'kind': 'type', 'value': type};
}

/// Cards carrying [tier] in any of their per-domain tier assignments.
class TierIs extends CardQuery {
  const TierIs(this.tier);

  final int tier;

  @override
  bool matches(Card card, [QueryContext? ctx]) =>
      card.tiers.values.contains(tier);

  @override
  Map<String, dynamic> toJson() => {'kind': 'tier', 'value': tier};
}

/// Cards in a study [state] (fresh / due / strong). **Dynamic** — needs a
/// [QueryContext]; matches nothing without one. Browse-only (never a lens leaf).
class StateIs extends CardQuery {
  const StateIs(this.state);

  final MasteryFilter state;

  @override
  bool matches(Card card, [QueryContext? ctx]) =>
      ctx != null && cardMastery(card, ctx.dueByKey, ctx.now).contains(state);

  @override
  Map<String, dynamic> toJson() => {'kind': 'state', 'value': state.name};
}

/// All of [of] match (an empty conjunction is vacuously true — cf. [Everything]).
class And extends CardQuery {
  const And(this.of);

  final List<CardQuery> of;

  @override
  bool matches(Card card, [QueryContext? ctx]) =>
      of.every((q) => q.matches(card, ctx));

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'and',
        'of': [for (final q in of) q.toJson()]
      };
}

/// Any of [of] match (an empty disjunction is vacuously false).
class Or extends CardQuery {
  const Or(this.of);

  final List<CardQuery> of;

  @override
  bool matches(Card card, [QueryContext? ctx]) =>
      of.any((q) => q.matches(card, ctx));

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'or',
        'of': [for (final q in of) q.toJson()]
      };
}

/// The negation of [q].
class Not extends CardQuery {
  const Not(this.q);

  final CardQuery q;

  @override
  bool matches(Card card, [QueryContext? ctx]) => !q.matches(card, ctx);

  @override
  Map<String, dynamic> toJson() => {'kind': 'not', 'q': q.toJson()};
}

/// Study-state buckets a card can fall into, derived from its sections' FSRS
/// schedule. The [StateIs] leaf + Browse's mastery filter share this. (Moved here
/// from `core/search/card_filter.dart` in G2 — it's a query concept.)
enum MasteryFilter { fresh, due, strong }

extension MasteryFilterLabel on MasteryFilter {
  String get label => switch (this) {
        MasteryFilter.fresh => 'New',
        MasteryFilter.due => 'Due',
        MasteryFilter.strong => 'Strong',
      };
}

MasteryFilter? _mastery(Object? v) => switch (v) {
      'fresh' => MasteryFilter.fresh,
      'due' => MasteryFilter.due,
      'strong' => MasteryFilter.strong,
      _ => null,
    };

/// The study-state buckets a card currently occupies — a card with a mix of new
/// and due sections is in both. Uses [dueByKey] (`"cardId::slug"` → dueAt for
/// *studied* sections; absent = never studied).
Set<MasteryFilter> cardMastery(
  Card card,
  Map<String, DateTime> dueByKey,
  DateTime now,
) {
  final out = <MasteryFilter>{};
  for (final s in card.quizzableSections) {
    final due = dueByKey['${card.id}::${s.slug}'];
    if (due == null) {
      out.add(MasteryFilter.fresh);
    } else if (!due.isAfter(now)) {
      out.add(MasteryFilter.due);
    } else {
      out.add(MasteryFilter.strong);
    }
  }
  return out;
}

/// Strips the dynamic ([StateIs]) leaves from [q], returning a purely structural
/// query safe to persist as a deck lens (ADR-0013 §Addendum). Deck membership is
/// evaluated with NO [QueryContext], so a persisted [StateIs] matches nothing —
/// dropping it degrades a study-state constraint to "no constraint" (a wider
/// lens) rather than silently emptying the deck. An all-dynamic query (e.g. just
/// `is:due`, or `-is:due`) → [CardQuery.everything], never the empty set.
CardQuery stripDynamic(CardQuery q) => _strip(q) ?? CardQuery.everything;

/// The structural core of [q], or null when [q] constrains ONLY by study state —
/// so a parent [And]/[Or] drops it as "no constraint" instead of keeping a leaf
/// that can never match a lens (which has no context).
CardQuery? _strip(CardQuery q) => switch (q) {
      StateIs() => null,
      And(:final of) => _stripJoin(of, and: true),
      Or(:final of) => _stripJoin(of, and: false),
      // A negation is kept ONLY if its whole subtree is structural. If it contains
      // any StateIs, reducing the inner tree would flip the negation's meaning and
      // could *narrow* the lens (e.g. `Not(And([type, is:due]))` → `Not(type)`
      // excludes not-due type cards the original kept) — so drop the whole Not,
      // which widens to no-constraint (the stripDynamic contract).
      Not(:final q) => _hasStateIs(q) ? null : Not(q),
      _ => q, // structural leaf (incl. Everything)
    };

/// Whether any [StateIs] appears anywhere in [q] (the dynamic-leaf test).
bool _hasStateIs(CardQuery q) => switch (q) {
      StateIs() => true,
      And(:final of) => of.any(_hasStateIs),
      Or(:final of) => of.any(_hasStateIs),
      Not(:final q) => _hasStateIs(q),
      _ => false,
    };

CardQuery? _stripJoin(List<CardQuery> of, {required bool and}) {
  final kept = [
    for (final c in of)
      if (_strip(c) case final s?) s,
  ];
  if (kept.isEmpty) return null;
  if (kept.length == 1) return kept.single;
  return and ? And(kept) : Or(kept);
}
