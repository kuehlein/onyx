import 'competency.dart';
import 'story.dart';

/// The set of competency keys that have at least one COMPLETE story (S+A+R) —
/// the durable "coverage" axis of behavioral readiness (having a usable story per
/// competency), distinct from delivery/freshness. A story tagged with a competency
/// only counts once it's complete.
Set<String> coveredCompetencies(List<Story> stories) => {
      for (final s in stories)
        if (s.isComplete) ...s.competencies,
    };

/// How many stories (complete or not) tag each competency key.
Map<String, int> storyCountByCompetency(List<Story> stories) {
  final out = {for (final k in kCompetencyKeys) k: 0};
  for (final s in stories) {
    for (final c in s.competencies) {
      if (out.containsKey(c)) out[c] = out[c]! + 1;
    }
  }
  return out;
}
