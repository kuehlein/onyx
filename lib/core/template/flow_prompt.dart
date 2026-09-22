/// Assembles the AI system prompt for a **config-driven** practice flow from a
/// vault-authored skill file (task #30c Phase 5, see docs/practice-flow-plan.md).
///
/// The vault skill owns the persona + terminology (e.g. "you are a waiter…");
/// this owns the structure/format and injects runtime context: the problem card,
/// the covered-knowledge **frontier** the AI must stay within (the language
/// conversation constraint), and an optional level calibration. The existing SWE
/// mock builders (in-code) are untouched — a SWE flow has no `skill` and uses
/// those; a subject flow supplies its skill as a file and uses this generic path.
library;

/// Compose the system prompt. [frontier] empty → no vocabulary constraint (a
/// plain mock). Pure.
String assembleFlowPrompt({
  required String skill,
  required String problem,
  Set<String> frontier = const {},
  String? levelNote,
}) {
  final b = StringBuffer()..writeln(skill.trim());
  if (levelNote != null && levelNote.trim().isNotEmpty) {
    b
      ..writeln()
      ..writeln(levelNote.trim());
  }
  if (frontier.isNotEmpty) {
    b
      ..writeln()
      ..writeln(coveredConceptsInstruction(frontier));
  }
  b
    ..writeln()
    ..writeln('# Problem')
    ..writeln(problem.trim());
  return b.toString().trimRight();
}

/// The hard "stay within covered material" instruction fed to a conversation AI
/// so it never introduces concepts the learner hasn't studied. [covered] is the
/// frontier from `coveredFrontier` (dependency_gating.dart).
String coveredConceptsInstruction(Set<String> covered) {
  final list = (covered.toList()..sort()).join(', ');
  return 'Constraint: use ONLY these already-covered concepts, and nothing '
      'outside them — do not introduce vocabulary, grammar, or ideas the learner '
      'has not studied yet: $list.';
}

/// Load a flow's skill text via an injected [read] (the vault reader in
/// production; a fake in tests). Returns null when the flow has no skill or the
/// file is missing/unreadable — callers fall back to their in-code builder.
Future<String?> loadFlowSkill(
  Future<String?> Function(String path) read,
  String? path,
) async {
  if (path == null || path.trim().isEmpty) return null;
  try {
    final text = await read(path.trim());
    return (text == null || text.trim().isEmpty) ? null : text;
  } catch (_) {
    return null;
  }
}
