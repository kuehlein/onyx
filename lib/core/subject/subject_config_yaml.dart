import 'package:yaml/yaml.dart';

import 'subject_config.dart';

/// Parses a subject config from YAML (the `_meta/onyx-subject.yaml` file, or the
/// frontmatter of `_onyx/config.md` in the fuller vault layout) into a
/// [SubjectConfig] — task #30 Phase 5. Pure; throws [FormatException] on invalid
/// input so the loader can fall back to the built-in default.
///
/// Schema (see docs/vault-structure.md; this is the minimal machine form):
/// ```yaml
/// id: demo-lang
/// target:
///   levels:  [{id: a1, label: A1, tierCurve: [1.0, 0.7, 0.4]}, ...]  # ordered
///   contexts:[{id: casual, label: Casual, stabilityTargetDays: 90}, ...]
///   tracks:  [{id: speaking, label: Speaking, familyWeights: {grammar: 1.2}}, ...]
///   families:[{id: grammar, exact: [grammar], contains: [grammar]}, ...]
///   fallback: {level: a1, context: casual, track: speaking}   # optional
/// flows:     [{cardType: flashcard, scheduling: recall, quizzability: blocklist}, ...]
/// ```
SubjectConfig subjectConfigFromYaml(String yaml) {
  final root = loadYaml(yaml);
  if (root is! Map) {
    throw const FormatException('subject config must be a YAML map');
  }
  return SubjectConfig(
    id: (root['id'] as String?) ?? 'subject',
    target: _target(root['target']),
    flows: _list(root['flows']).map(_flow).toList(),
  );
}

TargetSpec _target(Object? node) {
  if (node is! Map) throw const FormatException('`target` must be a map');
  final levels = _list(node['levels']).map(_level).toList();
  final contexts = _list(node['contexts']).map(_context).toList();
  final tracks = _list(node['tracks']).map(_track).toList();
  if (levels.isEmpty || contexts.isEmpty || tracks.isEmpty) {
    throw const FormatException(
        '`target` needs at least one level, context, and track');
  }
  final fb = node['fallback'];
  String fallback(String key, String dflt) =>
      (fb is Map ? fb[key] as String? : null) ?? dflt;
  return TargetSpec(
    levels: levels,
    contexts: contexts,
    tracks: tracks,
    families: _list(node['families']).map(_family).toList(),
    fallbackLevelId: fallback('level', levels.first.id),
    fallbackContextId: fallback('context', contexts.first.id),
    fallbackTrackId: fallback('track', tracks.first.id),
  );
}

LevelValue _level(Object? m) {
  final map = _map(m);
  // An empty or missing curve becomes the default — never [] , which would parse
  // fine here but crash later in TargetSpec.tierRelevance (curve.first), AFTER the
  // loader's try/catch has already accepted the config.
  final curve = _doubles(map['tierCurve']);
  return LevelValue(
    id: _id(map),
    label: _label(map),
    tierCurve: (curve == null || curve.isEmpty) ? const [1.0] : curve,
  );
}

ContextValue _context(Object? m) {
  final map = _map(m);
  return ContextValue(
    id: _id(map),
    label: _label(map),
    stabilityTargetDays: _double(map['stabilityTargetDays']) ?? 90,
  );
}

TrackValue _track(Object? m) {
  final map = _map(m);
  final weights = <String, double>{};
  final w = map['familyWeights'];
  if (w is Map) {
    w.forEach((k, v) {
      final d = _double(v);
      if (d != null) weights['$k'] = d;
    });
  }
  return TrackValue(id: _id(map), label: _label(map), familyWeights: weights);
}

DomainFamily _family(Object? m) {
  final map = _map(m);
  return DomainFamily(
    id: _id(map),
    exact: {for (final e in _list(map['exact'])) '$e'.toLowerCase()},
    contains: [for (final e in _list(map['contains'])) '$e'.toLowerCase()],
  );
}

FlowSpec _flow(Object? m) {
  final map = _map(m);
  return FlowSpec(
    cardType: (map['cardType'] as String?) ?? 'flashcard',
    scheduling: _enum(
        SchedulingModel.values, map['scheduling'], SchedulingModel.recall),
    quizzability: _enum(QuizzabilityPolicy.values, map['quizzability'],
        QuizzabilityPolicy.blocklist),
    label: (map['label'] as String?) ?? '',
    iconKey: (map['iconKey'] as String?) ?? 'card',
    colorKey: (map['colorKey'] as String?) ?? 'default',
  );
}

// ── coercion helpers (YAML → Dart) ──────────────────────────────────────────

Map _map(Object? o) {
  if (o is Map) return o;
  throw const FormatException('expected a map entry');
}

List<Object?> _list(Object? o) => o is List ? o : const [];

String _id(Map m) {
  final id = m['id'];
  if (id is String && id.isNotEmpty) return id;
  throw const FormatException('every entry needs a non-empty `id`');
}

String _label(Map m) => (m['label'] as String?) ?? _id(m);

double? _double(Object? o) => o is num ? o.toDouble() : null;

List<double>? _doubles(Object? o) {
  if (o is! List) return null;
  return [
    for (final e in o)
      if (e is num)
        e.toDouble()
      else
        throw const FormatException('expected a list of numbers'),
  ];
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
