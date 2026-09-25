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
/// AND'd together. Filters set via chips and via query operators (`domain:`,
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

/// Parses a raw Browse query into structural [facets] (the `domain:`/`type:`/
/// `tier:`/`is:` operators, pooled into a [CardFilter] so `chip.merge(facets)`
/// gives the chip+operator same-field UNION), an [extra] `CardQuery` for the
/// non-facet operators (`tag:`/`tags:` any-tag, `folder:`/`path:`, and negated
/// `-`/`!` leaves — all AND-ed on), and the remaining free-[text]. Unrecognized or
/// empty-value operators fall through to free text.
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
/// case-sensitive). `tag:`/`tags:` → any-tag [TagIs]; `domain:` → first-tag
/// [DomainIs] (ADR-0013 §Addendum 2).
CardQuery? _opLeaf(String key, String val, String rawVal) {
  switch (key) {
    case 'tag':
    case 'tags':
      // ANY tag (ADR-0013 §Addendum 2, 2026-09-25) — the convention every
      // mainstream tool uses (Anki/Obsidian/GitHub/Gmail). `domain:` (+ the Domain
      // chip) is the first-tag selector.
      return TagIs(val);
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

// ─── Deck-lens text form (ADR-0013 §Addendum, G3.0) ─────────────────────────
//
// The deck-lens mini-language parses to ONE [CardQuery] tree — unlike Browse's
// [parseQuery], there are no chips to reconcile, so it supports full `OR`/`()`
// nesting. Grammar (precedence: OR lowest < implicit/`&&` AND < `-`/`!` NOT):
//
//   expr   := or
//   or     := and ( ('OR' | '||') and )*
//   and    := factor ( '&&'? factor )*        // juxtaposition = AND
//   factor := ('-'|'!') factor | '(' expr ')' | term
//   term   := key:value | bareword/ | «ignored»
//
// It is TOTAL (never throws; a typo degrades, never becomes a bogus match-all)
// and empty → [CardQuery.everything] (the whole-vault lens).
//
// Tag semantics (ADR-0013 §Addendum 2, 2026-09-25 — convention-aligned after the
// adversarial review): `tag:`/`tags:` = ANY tag ([TagIs]) — what Anki/Obsidian/
// GitHub/Gmail all mean, and what the deck editor's simple "Tag" pick produces.
// `domain:` = the PRIMARY domain (first tag, [DomainIs]) — the Browse "Domain"
// chip. Shared between Browse and the lens (one operator table), so `tag:` means
// the same thing everywhere.

/// Parses the deck-lens mini-language into one [CardQuery]. See the section
/// comment above for the grammar, totality, and tag semantics.
CardQuery parseLens(String input) =>
    _LensParser(_tokenizeLens(input)).parseExpr() ?? CardQuery.everything;

/// Renders a [CardQuery] back to the mini-language — the inverse of [parseLens]
/// (modulo whitespace / redundant parens), so a saved lens is editable as text.
/// Parens are added only where precedence needs them (an `Or` inside an `And`).
String renderLens(CardQuery q) => switch (q) {
      Everything() => '',
      TagIs(:final tag) => 'tag:${_qv(tag)}',
      DomainIs(:final domain) => 'domain:${_qv(domain)}',
      FolderUnder(:final path) => 'folder:${_qv(path)}',
      TypeIs(:final type) => 'type:${_qv(type)}',
      TierIs(:final tier) => 'tier:$tier',
      StateIs(:final state) => 'is:${state.name}',
      Not(:final q) => _isLeaf(q) ? '-${renderLens(q)}' : '!(${renderLens(q)})',
      And(:final of) => [
          for (final c in of) c is Or ? '(${renderLens(c)})' : renderLens(c)
        ].join(' '),
      Or(:final of) => [for (final c in of) renderLens(c)].join(' OR '),
    };

bool _isLeaf(CardQuery q) => q is! And && q is! Or && q is! Not;

/// Wraps a leaf value in `"..."` when it would otherwise break the tokenizer — it
/// contains whitespace, a paren, or a quote, or is empty. So a folder/tag with a
/// space (`folder:"Machine Learning"`) survives a `renderLens` → `parseLens`
/// round-trip (the "editable text mirror" invariant). Embedded `"` is escaped.
String _qv(String v) => v.isEmpty || v.contains(RegExp(r'[\s()"]'))
    ? '"${v.replaceAll('"', r'\"')}"'
    : v;

/// Strips the surrounding `"..."` (and unescapes `\"`) from a token value, the
/// inverse of [_qv]. A non-quoted value is returned unchanged.
String _unquoteVal(String v) =>
    v.length >= 2 && v.startsWith('"') && v.endsWith('"')
        ? v.substring(1, v.length - 1).replaceAll(r'\"', '"')
        : v;

/// Splits on whitespace, with `(` and `)` always standalone tokens (so `(a` and
/// `!(a` tokenize cleanly), and a `"..."` run kept intact (spaces/parens inside a
/// quoted value don't split it; `\"` is an escaped quote). `&&` / `||` / `OR`
/// survive as their own tokens when space-separated.
List<String> _tokenizeLens(String s) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  void flush() {
    if (buf.isNotEmpty) {
      out.add(buf.toString());
      buf.clear();
    }
  }

  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (inQuotes) {
      if (ch == r'\' && i + 1 < s.length) {
        buf.write(ch);
        buf.write(s[i + 1]);
        i++; // keep the escape verbatim; _unquoteVal resolves it
      } else {
        buf.write(ch);
        if (ch == '"') inQuotes = false;
      }
    } else if (ch == '"') {
      buf.write(ch);
      inQuotes = true;
    } else if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
      flush();
    } else if (ch == '(' || ch == ')') {
      flush();
      out.add(ch);
    } else {
      buf.write(ch);
    }
  }
  flush();
  return out;
}

class _LensParser {
  _LensParser(this._tokens);

  final List<String> _tokens;
  int _i = 0;

  String? get _peek => _i < _tokens.length ? _tokens[_i] : null;
  String _next() => _tokens[_i++];
  static bool _isOr(String t) => t == 'OR' || t == '||';

  CardQuery? parseExpr() => _parseOr();

  CardQuery? _parseOr() {
    final terms = <CardQuery>[];
    final first = _parseAnd();
    if (first != null) terms.add(first);
    while (_peek != null && _isOr(_peek!)) {
      _next(); // consume OR / ||
      final rhs = _parseAnd();
      if (rhs != null) terms.add(rhs);
    }
    if (terms.isEmpty) return null;
    return terms.length == 1 ? terms.single : Or(terms);
  }

  CardQuery? _parseAnd() {
    final terms = <CardQuery>[];
    while (_peek != null && !_isOr(_peek!) && _peek != ')') {
      if (_peek == '&&') {
        _next(); // explicit AND separator — juxtaposition already means AND
        continue;
      }
      final f = _parseFactor();
      if (f != null) terms.add(f);
    }
    if (terms.isEmpty) return null;
    return terms.length == 1 ? terms.single : And(terms);
  }

  CardQuery? _parseFactor() {
    final tok = _next();
    if (tok == '(') {
      final inner = _parseOr();
      if (_peek == ')') _next(); // tolerate a missing close paren
      return inner;
    }
    if (tok == ')') return null; // stray close — skip
    // A lone `-` / `!` negates the following factor (e.g. `! (a OR b)`).
    if (tok == '-' || tok == '!') {
      if (_peek == null || _peek == ')') return null;
      final f = _parseFactor();
      return f == null ? null : Not(f);
    }
    // A `-`/`!` prefix on a term (e.g. `!tags:hangul`).
    if ((tok.startsWith('-') || tok.startsWith('!')) && tok.length > 1) {
      final leaf = _lensTerm(tok.substring(1));
      return leaf == null ? null : Not(leaf);
    }
    return _lensTerm(tok);
  }
}

/// One lens term: an operator leaf, the `foo/` folder shorthand
/// (deck_creation.md), or null for a bare word (ignored — a structural lens has
/// no free-text membership; `TextMatches` is deferred, ADR-0013 §Addendum).
CardQuery? _lensTerm(String tok) {
  final i = tok.indexOf(':');
  if (i > 0 && i < tok.length - 1) {
    final key = tok.substring(0, i).toLowerCase();
    final rawVal = _unquoteVal(tok.substring(i + 1)); // `folder:"a b"` → `a b`
    // The lens shares Browse's operator table (`_opLeaf`) — `tag:`/`tags:` any-tag,
    // `domain:` first-tag, plus type/tier/is/folder.
    return _opLeaf(key, rawVal.toLowerCase(), rawVal);
  }
  if (tok.endsWith('/')) {
    final f = FolderUnder(tok); // trims trailing slashes
    return f.path.isEmpty ? null : f; // a bare `/` is not match-all
  }
  return null;
}
