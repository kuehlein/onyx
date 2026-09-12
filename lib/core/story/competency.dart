/// The canonical 8 behavioral competencies (see behavioral-flow-design research).
/// Shared by the behavioral question cards (their second tag is the [key]), the
/// story bank (a story tags the competencies it covers), and the coverage matrix.
/// A universal taxonomy; company-specific vocab (Amazon LPs, Google, Meta) maps
/// onto these rather than replacing them.
class BehavioralCompetency {
  const BehavioralCompetency(this.key, this.label);

  /// Short stable key, matching the behavioral card's competency tag (e.g.
  /// 'conflict') and used in story frontmatter `competencies:`.
  final String key;

  /// Human-readable label.
  final String label;
}

const kBehavioralCompetencies = <BehavioralCompetency>[
  BehavioralCompetency('ownership', 'Ownership & Results'),
  BehavioralCompetency('conflict', 'Conflict & Backbone'),
  BehavioralCompetency('ambiguity', 'Ambiguity & Judgment'),
  BehavioralCompetency('influence', 'Influence Without Authority'),
  BehavioralCompetency('growth', 'Growth & Humility'),
  BehavioralCompetency('mentoring', 'Mentoring & Developing Others'),
  BehavioralCompetency('customer', 'Customer & Impact'),
  BehavioralCompetency('failure', 'Failure & Reflection'),
];

/// The competency keys, in canonical order.
final kCompetencyKeys = [for (final c in kBehavioralCompetencies) c.key];

/// The human label for a competency [key], or the key itself if unknown.
String competencyLabel(String key) {
  for (final c in kBehavioralCompetencies) {
    if (c.key == key) return c.label;
  }
  return key;
}
