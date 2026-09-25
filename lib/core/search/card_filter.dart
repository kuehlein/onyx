import '../../shared/models/card.dart'; // re-exports the kType* value constants
import '../query/card_query.dart';
import '../template/active_template.dart';

// `MasteryFilter`/`cardMastery` moved to core/query (a query concept, shared with
// the CardQuery `StateIs` leaf); re-exported so this file's consumers are unchanged
// while Browse migrates onto the IR (G2).
export '../query/card_query.dart'
    show MasteryFilter, MasteryFilterLabel, cardMastery;

/// A composable set of Browse filters. An empty facet means "no constraint on
/// this facet"; within a facet the selected values are OR'd, and facets are
/// AND'd together. Filters set via chips and via query operators (`tag:`,
/// `type:`, `tier:`, `is:`) share this type and merge by union.
class CardFilter {
  const CardFilter({
    this.types = const {},
    this.domains = const {},
    this.tiers = const {},
    this.mastery = const {},
  });

  final Set<String> types;
  final Set<String> domains;
  final Set<int> tiers;
  final Set<MasteryFilter> mastery;

  bool get isEmpty =>
      types.isEmpty && domains.isEmpty && tiers.isEmpty && mastery.isEmpty;

  /// How many facets are constrained (for a compact "active filters" badge).
  int get activeFacetCount =>
      (types.isEmpty ? 0 : 1) +
      (domains.isEmpty ? 0 : 1) +
      (tiers.isEmpty ? 0 : 1) +
      (mastery.isEmpty ? 0 : 1);

  CardFilter copyWith({
    Set<String>? types,
    Set<String>? domains,
    Set<int>? tiers,
    Set<MasteryFilter>? mastery,
  }) =>
      CardFilter(
        types: types ?? this.types,
        domains: domains ?? this.domains,
        tiers: tiers ?? this.tiers,
        mastery: mastery ?? this.mastery,
      );

  /// Union this filter with [other] (used to combine chip and operator filters).
  CardFilter merge(CardFilter other) => CardFilter(
        types: {...types, ...other.types},
        domains: {...domains, ...other.domains},
        tiers: {...tiers, ...other.tiers},
        mastery: {...mastery, ...other.mastery},
      );

  /// Project onto the unified [CardQuery] IR (ADR-0013 §Addendum): each non-empty
  /// facet becomes an OR of its leaf values, and the facets are AND-ed together —
  /// exactly [matchesFilter]'s "OR within a facet, AND across". Empty facets
  /// contribute no conjunct; an all-empty filter is [CardQuery.everything].
  /// Domain maps to [DomainIs] (first-tag), NOT any-tag [TagIs].
  CardQuery toQuery() {
    final conj = <CardQuery>[
      if (types.isNotEmpty) _anyOf([for (final t in types) TypeIs(t)]),
      if (domains.isNotEmpty) _anyOf([for (final d in domains) DomainIs(d)]),
      if (tiers.isNotEmpty) _anyOf([for (final n in tiers) TierIs(n)]),
      if (mastery.isNotEmpty) _anyOf([for (final m in mastery) StateIs(m)]),
    ];
    if (conj.isEmpty) return CardQuery.everything;
    return conj.length == 1 ? conj.single : And(conj);
  }
}

/// A single leaf as itself, or an [Or] of several — never `Or([one])`.
CardQuery _anyOf(List<CardQuery> leaves) =>
    leaves.length == 1 ? leaves.single : Or(leaves);

/// Parses a raw Browse query into structural [facets] (the `tag`/`type`/`tier`/`is`
/// operators, pooled into a [CardFilter] exactly as the legacy parser did — so
/// `chip.merge(facets)` keeps the chip+operator same-field UNION byte-identical),
/// an [extra] `CardQuery` for the non-facet operators (`folder:`/`path:` and
/// negated `-`/`!` leaves, AND-ed on), and the remaining free-[text]. Unrecognized
/// or empty-value operators fall through to free text.
///
/// **Total** — never throws, and never builds a match-everything/‑nothing leaf
/// from a typo (`tag:`/`folder:` with no value → free text). `OR`/`()` grouping is
/// deferred to the deck-lens text form (G3); ADR-0013 §Amendment.
({CardFilter facets, CardQuery extra, String text}) parseQuery(String query) {
  final types = <String>{};
  final domains = <String>{};
  final tiers = <int>{};
  final mastery = <MasteryFilter>{};
  final extra = <CardQuery>[];
  final free = <String>[];

  for (final tok in query.split(RegExp(r'\s+'))) {
    if (tok.isEmpty) continue;
    // A leading - or ! negates the FOLLOWING operator; a bare -/! or a negated
    // non-operator (e.g. "-word") stays free text.
    final negated = tok.length > 1 && (tok[0] == '-' || tok[0] == '!');
    final body = negated ? tok.substring(1) : tok;
    final i = body.indexOf(':');
    if (i > 0 && i < body.length - 1) {
      final key = body.substring(0, i).toLowerCase();
      final rawVal = body.substring(i + 1);
      final leaf = _opLeaf(key, rawVal.toLowerCase(), rawVal);
      if (leaf != null) {
        if (negated) {
          extra.add(Not(leaf));
        } else {
          // Positive facet operators pool into the CardFilter (byte-identical);
          // a positive folder leaf is AND-ed on via [extra].
          switch (leaf) {
            case DomainIs(:final domain):
              domains.add(domain);
            case TypeIs(:final type):
              types.add(type);
            case TierIs(:final tier):
              tiers.add(tier);
            case StateIs(:final state):
              mastery.add(state);
            default:
              extra.add(leaf);
          }
        }
        continue;
      }
    }
    free.add(tok); // full token incl any -/! prefix (byte-identical to before)
  }

  return (
    facets: CardFilter(
        types: types, domains: domains, tiers: tiers, mastery: mastery),
    extra: extra.isEmpty
        ? CardQuery.everything
        : (extra.length == 1 ? extra.single : And(extra)),
    text: free.join(' '),
  );
}

/// The leaf for a `key:value` operator, or null if unrecognized / invalid. [val]
/// is lowercased; [rawVal] keeps case for the path leaf (`filePath` is
/// case-sensitive). Domain/tag both map to the first-tag [DomainIs] (ADR-0013).
CardQuery? _opLeaf(String key, String val, String rawVal) {
  switch (key) {
    case 'tag':
    case 'domain':
      return DomainIs(val);
    case 'type':
      final t = _parseType(val);
      return t == null ? null : TypeIs(t);
    case 'tier':
      final n = int.tryParse(val);
      return n == null ? null : TierIs(n);
    case 'is':
    case 'mastery':
      final m = _parseMastery(val);
      return m == null ? null : StateIs(m);
    case 'folder':
    case 'path':
      // Guard the match-everything footgun: `folder:/` trims to an empty path,
      // which FolderUnder treats as "whole vault". Degrade to free text instead.
      final f = FolderUnder(rawVal);
      return f.path.isEmpty ? null : f;
    default:
      return null;
  }
}

/// Maps free-text search aliases to a card `type:` value. The aliases are a
/// convenience layer independent of any subject's flow ids; a value that isn't an
/// alias but is itself a valid type passes through.
String? _parseType(String v) => switch (v) {
      'interview' ||
      'interviewquestion' ||
      'iq' ||
      'question' =>
        kTypeInterviewQuestion,
      'flashcard' || 'concept' || 'card' => kTypeFlashcard,
      'algorithm' || 'algo' || 'problem' => kTypeAlgorithm,
      'system-design' ||
      'systemdesign' ||
      'sd' ||
      'design' =>
        kTypeSystemDesign,
      'behavioral' ||
      'behaviour' ||
      'behavior' ||
      'star' ||
      'bq' =>
        kTypeBehavioral,
      // A raw value that is itself a configured flow id (e.g. a subject's own
      // `conversation`) filters by it; anything else is null so the token falls
      // through to free-text search (preserving the pre-#30 behavior).
      _ => activeTemplate.isCardType(v) ? v : null,
    };

MasteryFilter? _parseMastery(String v) => switch (v) {
      'new' || 'fresh' || 'unstudied' => MasteryFilter.fresh,
      'due' => MasteryFilter.due,
      'strong' || 'known' || 'mastered' => MasteryFilter.strong,
      _ => null,
    };
