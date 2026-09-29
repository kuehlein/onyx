import '../models/card.dart';

/// Per-concept comfort for prerequisite gating — shared by the daily plan and the
/// flow runner (it was duplicated, near-identically, in both). For each
/// foundational **concept card**, the fraction of its quizzable sections that have
/// SRS state; plus a filename→id index, because `## Related` wikilinks and the
/// `depends-on` field name a concept by its FILE, not its id (and the vault mixes
/// id conventions), so a filename→id hop is needed for gating to see the prereq.
///
/// The "concept card" predicate is config-driven (invariant #2): a card whose flow
/// uses the **blocklist** quizzability policy — the foundational concept-recall flow —
/// resolved via [Card.flow], not a `type == flashcard` branch. `stateKeys` is the set
/// of `cardId::sectionSlug` keys that have SRS state.
class ConceptComfort {
  const ConceptComfort(this.comfort, this.idByFile, this.label);

  /// concept card id → studied fraction (0..1).
  final Map<String, double> comfort;

  /// filename slug (no `.md`) → concept card id.
  final Map<String, String> idByFile;

  /// concept card id → title.
  final Map<String, String> label;

  /// Comfort for a dependency named by id OR by filename slug (0 if unknown).
  double of(String dep) => comfort[dep] ?? comfort[idByFile[dep] ?? ''] ?? 0.0;

  /// Display label for a dependency named by id OR filename slug (else the dep).
  String labelOf(String dep) => label[dep] ?? label[idByFile[dep] ?? ''] ?? dep;
}

ConceptComfort buildConceptComfort(List<Card> cards, Set<String> stateKeys) {
  final comfort = <String, double>{};
  final idByFile = <String, String>{};
  final label = <String, String>{};
  for (final c in cards) {
    // Concept cards only: the flow whose quizzability is the blocklist policy (the
    // foundational concept-recall flow), dispatched via config — not a type branch.
    if (c.flow?.quizzability != QuizzabilityPolicy.blocklist) continue;
    final slug = c.filePath.split('/').last.replaceFirst(RegExp(r'\.md$'), '');
    idByFile[slug] = c.id;
    label[c.id] = c.title;
    final q = c.quizzableSections.toList();
    if (q.isEmpty) continue;
    final studied =
        q.where((s) => stateKeys.contains('${c.id}::${s.slug}')).length;
    comfort[c.id] = studied / q.length;
  }
  return ConceptComfort(comfort, idByFile, label);
}
