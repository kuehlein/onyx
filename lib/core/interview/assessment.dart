import 'dart:convert';

/// The structured, rubric-based assessment the interview coach produces for one
/// attempt — the applied/transfer signal FSRS recall can't measure (Phase B,
/// see docs/readiness-dashboard.md §4/§7). It is deliberately kept separate from
/// the human's FSRS self-grade: the tap still drives scheduling; this only feeds
/// the readiness *applied* dimension, and is aggregated (never trusted from one
/// attempt) with a bounded adversarial second opinion.
///
/// The rubric is an open map (dimension → 1–5) rather than fixed fields so the
/// dimensions can vary by subject (see the generalization goal, task #30). The
/// canonical SWE dimensions are in [sweRubricDimensions].
class AppliedAssessment {
  const AppliedAssessment({
    required this.appliedScore,
    this.rubric = const {},
    this.novel = false,
    this.hintLevel = 0,
    this.note,
  });

  /// Overall applied performance, 0–100.
  final int appliedScore;

  /// Per-dimension scores, each 1–5.
  final Map<String, int> rubric;

  /// Whether the probe was a novel / transfer problem.
  final bool novel;

  /// Hints leaned on (0 = fully unaided).
  final int hintLevel;

  final String? note;

  String encodeRubric() => jsonEncode(rubric);

  /// Parse a rubric JSON string back to a map (empty/invalid → {}).
  static Map<String, int> decodeRubric(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in m.entries)
          if (e.value is num) e.key: (e.value as num).round(),
      };
    } catch (_) {
      return const {};
    }
  }

  AppliedAssessment copyWith(
          {int? appliedScore, bool? novel, int? hintLevel}) =>
      AppliedAssessment(
        appliedScore: appliedScore ?? this.appliedScore,
        rubric: rubric,
        novel: novel ?? this.novel,
        hintLevel: hintLevel ?? this.hintLevel,
        note: note,
      );
}

/// The canonical SWE interview rubric dimensions.
const sweRubricDimensions = <String>[
  'communication',
  'approach',
  'correctness',
  'complexity',
  'edgeCases',
  'independence',
];

/// The system-design mock-interview rubric dimensions (flow 3). Distinct from the
/// coding [sweRubricDimensions]: a design interview grades scoping, estimation,
/// architecture, data modeling, depth, trade-off justification, and communication.
/// One holistic [AppliedAssessment.appliedScore] still drives readiness; these
/// per-dimension scores power insights (surfacing a consistently-weak dimension).
const systemDesignRubricDimensions = <String>[
  'requirements',
  'estimation',
  'highLevelDesign',
  'dataModeling',
  'deepDive',
  'tradeoffReasoning',
  'communication',
];

/// The behavioral mock-interview rubric dimensions (flow 4). STAR+L structure plus
/// the highest-signal behavioral dimensions from the research (ownership, quantified
/// result, competency/leadership signal, level-appropriate scope, reflection) and
/// communication. The starred four (ownership, result, signal, scope, reflection)
/// carry the most weight; structure & communication are hygiene.
const behavioralRubricDimensions = <String>[
  'structure',
  'ownership',
  'result',
  'signal',
  'scope',
  'reflection',
  'communication',
];

/// A human-readable label for a rubric dimension key.
String rubricLabel(String key) => switch (key) {
      'communication' => 'Communication',
      'approach' => 'Problem-solving approach',
      'correctness' => 'Correctness',
      'complexity' => 'Complexity analysis',
      'edgeCases' => 'Edge cases',
      'independence' => 'Independence',
      // System-design dimensions.
      'requirements' => 'Requirements & scoping',
      'estimation' => 'Estimation',
      'highLevelDesign' => 'High-level design',
      'dataModeling' => 'Data modeling',
      'deepDive' => 'Deep-dive depth',
      'tradeoffReasoning' => 'Trade-off reasoning',
      // Behavioral dimensions.
      'structure' => 'Structure (STAR+L)',
      'ownership' => 'Ownership',
      'result' => 'Quantified result',
      'signal' => 'Competency signal',
      'scope' => 'Scope vs level',
      'reflection' => 'Reflection & learning',
      _ => key,
    };
