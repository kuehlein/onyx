import '../models/card.dart';

/// Per-concept comfort for prerequisite gating — shared by the daily plan and the
/// flow runner (it was duplicated, near-identically, in both). For each
/// foundational **concept card**, the fraction of its quizzable sections that have
/// SRS state; plus a filename→id index, because `## Related` wikilinks and the
/// `depends-on` field name a concept by its FILE, not its id (and the vault mixes
/// id conventions), so a filename→id hop is needed for gating to see the prereq.
///
/// TODO(#87 / #32): the "concept card" predicate is still `type == flashcard` — a
/// type-branch that should become config-driven (a *foundational-recall* flow),
/// which needs the concept-vs-applied-recall model call. Centralised here so that
/// fix lands in one place. `stateKeys` is the set of `cardId::sectionSlug` keys
/// that have SRS state.
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
    if (c.type != kTypeFlashcard) continue;
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
