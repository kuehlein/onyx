import '../../shared/models/card.dart';

/// Study-state buckets a card can fall into, derived from its sections' FSRS
/// schedule.
enum MasteryFilter { fresh, due, strong }

extension MasteryFilterLabel on MasteryFilter {
  String get label => switch (this) {
        MasteryFilter.fresh => 'New',
        MasteryFilter.due => 'Due',
        MasteryFilter.strong => 'Strong',
      };
}

extension CardTypeLabel on CardType {
  String get label => switch (this) {
        CardType.flashcard => 'Flashcard',
        CardType.interviewQuestion => 'Interview question',
      };
}

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

  final Set<CardType> types;
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
    Set<CardType>? types,
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
}

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

/// Whether [card] passes [filter], given its precomputed [mastery] set.
bool matchesFilter(Card card, CardFilter filter, Set<MasteryFilter> mastery) {
  if (filter.types.isNotEmpty && !filter.types.contains(card.type)) {
    return false;
  }
  if (filter.domains.isNotEmpty &&
      !(card.domain != null && filter.domains.contains(card.domain))) {
    return false;
  }
  if (filter.tiers.isNotEmpty &&
      !card.tiers.values.any(filter.tiers.contains)) {
    return false;
  }
  if (filter.mastery.isNotEmpty &&
      mastery.intersection(filter.mastery).isEmpty) {
    return false;
  }
  return true;
}

/// Splits a raw query into a filter (from `key:value` operators) and the
/// remaining free-text terms. Unrecognised operators fall through to free text.
({CardFilter filter, String text}) parseSearchQuery(String query) {
  final types = <CardType>{};
  final domains = <String>{};
  final tiers = <int>{};
  final mastery = <MasteryFilter>{};
  final free = <String>[];

  for (final tok in query.split(RegExp(r'\s+'))) {
    if (tok.isEmpty) continue;
    final i = tok.indexOf(':');
    if (i > 0 && i < tok.length - 1) {
      final key = tok.substring(0, i).toLowerCase();
      final val = tok.substring(i + 1).toLowerCase();
      var handled = true;
      switch (key) {
        case 'type':
          final t = _parseType(val);
          if (t != null) {
            types.add(t);
          } else {
            handled = false;
          }
        case 'tag':
        case 'domain':
          domains.add(val);
        case 'tier':
          final n = int.tryParse(val);
          if (n != null) {
            tiers.add(n);
          } else {
            handled = false;
          }
        case 'is':
        case 'mastery':
          final m = _parseMastery(val);
          if (m != null) {
            mastery.add(m);
          } else {
            handled = false;
          }
        default:
          handled = false;
      }
      if (handled) continue;
    }
    free.add(tok);
  }

  return (
    filter: CardFilter(
        types: types, domains: domains, tiers: tiers, mastery: mastery),
    text: free.join(' '),
  );
}

CardType? _parseType(String v) => switch (v) {
      'interview' ||
      'interviewquestion' ||
      'iq' ||
      'question' =>
        CardType.interviewQuestion,
      'flashcard' || 'concept' || 'card' => CardType.flashcard,
      _ => null,
    };

MasteryFilter? _parseMastery(String v) => switch (v) {
      'new' || 'fresh' || 'unstudied' => MasteryFilter.fresh,
      'due' => MasteryFilter.due,
      'strong' || 'known' || 'mastered' => MasteryFilter.strong,
      _ => null,
    };
