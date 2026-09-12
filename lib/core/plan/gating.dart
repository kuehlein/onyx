/// Prerequisite gating for the daily plan (task #57, phase 3).
///
/// Some flows shouldn't be practiced until their foundations are in place — you
/// can't design a system (or solve a DP problem) without the building blocks.
/// This gates individual practice units on the *comfort* of their prerequisite
/// concept cards:
///  - **System design:** each problem gates on its own `## Related` concepts.
///  - **Algorithms:** foundational groups (arrays/strings, two-pointers, sliding
///    window, stack, binary search, linked list) are ungated from day one; advanced
///    groups gate on their concept card(s).
///  - **Review / Learn:** never gated.
///
/// Pure: it takes the raw availabilities plus a comfort map and a prereq map, and
/// returns availabilities with locked units removed (a track with no remaining
/// units is marked locked with a human reason). The provider computes the comfort
/// map (from SRS state) and the prereq map (SD from card wikilinks, algorithms from
/// [algoGroupPrereqs]).
library;

import 'practice_plan.dart';

/// A prerequisite concept card is "comfortable" once at least this fraction of
/// its sections have been studied.
const double kConceptComfortBar = 0.5;

/// A gated card unlocks once at least this fraction of its prerequisites are
/// comfortable.
const double kPrereqFraction = 0.6;

/// Algorithm group → prerequisite concept-card slugs. Empty = ungated (available
/// day one). Advanced groups gate on the concept they apply.
const Map<String, List<String>> algoGroupPrereqs = {
  // Foundational — no prerequisite (start immediately).
  'algo-arrays-and-hashing': [],
  'algo-two-pointers': [],
  'algo-sliding-window': [],
  'algo-stack': [],
  'algo-binary-search': [],
  'algo-linked-list': [],
  'algo-math-and-geometry': [],
  'algo-bit-manipulation': [],
  'algo-sorting': [],
  // Gated on their concept card(s).
  'algo-trees': ['binary-tree', 'bst'],
  'algo-tries': ['trie'],
  'algo-heap-priority-queue': ['heap'],
  'algo-backtracking': ['backtracking', 'recursion'],
  'algo-graphs': ['graphs', 'bfs', 'dfs'],
  'algo-advanced-graphs': [
    'dijkstra-shortest-path',
    'minimum-spanning-tree',
    'union-find',
  ],
  'algo-1d-dynamic-programming': ['dynamic-programming-1d'],
  'algo-2d-dynamic-programming': ['dynamic-programming-2d'],
  'algo-greedy': ['greedy'],
  'algo-intervals': ['intervals'],
};

/// The card id embedded in a [PracticeUnit.id] (`"cardId::slug"` or `"cardId"`).
String cardIdOf(String unitId) {
  final i = unitId.indexOf('::');
  return i < 0 ? unitId : unitId.substring(0, i);
}

/// Whether [prereqs] are satisfied given per-concept [comfort] (0..1).
bool prereqsMet(List<String> prereqs, Map<String, double> comfort) {
  if (prereqs.isEmpty) return true;
  final ok =
      prereqs.where((c) => (comfort[c] ?? 0) >= kConceptComfortBar).length;
  return ok / prereqs.length >= kPrereqFraction - 1e-9;
}

/// Applies prerequisite gating to [availabilities]: drops locked units; a track
/// left with no units becomes `unlocked: false` with a [TrackAvailability.gateReason].
/// [prereqsByCard] maps a unit's card id → prerequisite concept slugs (Review/Learn
/// cards are absent → ungated). [comfortByConcept] is per-concept comfort (0..1).
/// [labelForConcept] renders a friendly reason.
List<TrackAvailability> gatePracticeAvailabilities({
  required List<TrackAvailability> availabilities,
  required Map<String, List<String>> prereqsByCard,
  required Map<String, double> comfortByConcept,
  String Function(String slug)? labelForConcept,
}) {
  return [
    for (final a in availabilities)
      _gateTrack(a, prereqsByCard, comfortByConcept, labelForConcept),
  ];
}

TrackAvailability _gateTrack(
  TrackAvailability a,
  Map<String, List<String>> prereqsByCard,
  Map<String, double> comfort,
  String Function(String slug)? labelFor,
) {
  // Review/Learn are never gated; short-circuit.
  if (a.track == TrackId.review || a.track == TrackId.learn) return a;

  final kept = <PracticeUnit>[];
  final blockedConcepts = <String>{};
  for (final u in a.units) {
    final prereqs = prereqsByCard[cardIdOf(u.id)] ?? const [];
    if (prereqsMet(prereqs, comfort)) {
      kept.add(u);
    } else {
      for (final c in prereqs) {
        if ((comfort[c] ?? 0) < kConceptComfortBar) blockedConcepts.add(c);
      }
    }
  }
  if (kept.length == a.units.length) return a;
  if (kept.isNotEmpty) {
    return TrackAvailability(track: a.track, units: kept, unlocked: true);
  }
  // Nothing available yet — lock the track with a reason.
  final names =
      blockedConcepts.take(2).map((c) => labelFor?.call(c) ?? c).toList();
  final reason = names.isEmpty
      ? 'Unlocks as you build the foundations'
      : 'Unlocks as you get comfortable with ${names.join(' and ')}';
  return TrackAvailability(
      track: a.track, units: const [], unlocked: false, gateReason: reason);
}
