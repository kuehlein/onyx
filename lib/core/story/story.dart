import 'package:yaml/yaml.dart';

/// A STAR+L behavioral story — the user's own material, kept in the vault as a
/// plain markdown note under `stories/` (Obsidian-editable, synced, second-brain
/// aligned). Deliberately a SKELETON (bullet-worthy fields), not a script:
/// over-rehearsed word-for-word answers read robotic and collapse under probing.
///
/// File shape:
/// ```
/// ---
/// title: The Kafka migration
/// competencies: [ownership, conflict]
/// level: staff
/// companies: [amazon]
/// created: 2026-09-12
/// ---
/// # The Kafka migration
/// ## Situation …
/// ## Task …
/// ## Action …
/// ## Result …
/// ## Learning …
/// ```
class Story {
  const Story({
    required this.id,
    required this.title,
    this.competencies = const [],
    this.level,
    this.companies = const [],
    this.situation = '',
    this.task = '',
    this.action = '',
    this.result = '',
    this.learning = '',
    this.created,
  });

  /// Filename slug (without `.md`) — the stable id and the vault path stem.
  final String id;
  final String title;

  /// Competency keys this story covers (see [kBehavioralCompetencies]).
  final List<String> competencies;
  final String? level;
  final List<String> companies;
  final String situation, task, action, result, learning;
  final DateTime? created;

  /// Rough "has a quantified result" check (a digit in the Result) — the single
  /// highest-signal behavioral element and the one most often missing.
  bool get hasQuantifiedResult => RegExp(r'\d').hasMatch(result);

  /// A story is "usable" once it has the load-bearing STAR pieces (S, A, R).
  bool get isComplete =>
      situation.trim().isNotEmpty &&
      action.trim().isNotEmpty &&
      result.trim().isNotEmpty;

  Story copyWith({
    String? id,
    String? title,
    List<String>? competencies,
    Object? level = _unset,
    List<String>? companies,
    String? situation,
    String? task,
    String? action,
    String? result,
    String? learning,
    Object? created = _unset,
  }) =>
      Story(
        id: id ?? this.id,
        title: title ?? this.title,
        competencies: competencies ?? this.competencies,
        level: level == _unset ? this.level : level as String?,
        companies: companies ?? this.companies,
        situation: situation ?? this.situation,
        task: task ?? this.task,
        action: action ?? this.action,
        result: result ?? this.result,
        learning: learning ?? this.learning,
        created: created == _unset ? this.created : created as DateTime?,
      );

  String toMarkdown() {
    String date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final b = StringBuffer()
      ..writeln('---')
      ..writeln('title: $title')
      ..writeln('competencies: [${competencies.join(', ')}]');
    if (level != null) {
      b.writeln('level: $level');
    }
    if (companies.isNotEmpty) {
      b.writeln('companies: [${companies.join(', ')}]');
    }
    if (created != null) {
      b.writeln('created: ${date(created!)}');
    }
    b
      ..writeln('---')
      ..writeln()
      ..writeln('# $title');
    void section(String heading, String body) {
      b
        ..writeln()
        ..writeln('## $heading')
        ..writeln(body.trim());
    }

    section('Situation', situation);
    section('Task', task);
    section('Action', action);
    section('Result', result);
    section('Learning', learning);
    return b.toString();
  }

  static final _frontmatter =
      RegExp(r'^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n?(.*)$', dotAll: true);
  static final _h1 = RegExp(r'^#[ \t]+(.+?)[ \t]*$', multiLine: true);

  /// Parses a story markdown note. [id] is the filename slug. Returns null only
  /// if the frontmatter is unparseable; missing fields default empty.
  static Story? parse(String md, {required String id}) {
    final m = _frontmatter.firstMatch(md);
    final Map fm;
    final String body;
    if (m == null) {
      fm = const {};
      body = md;
    } else {
      try {
        final loaded = loadYaml(m.group(1)!);
        fm = loaded is YamlMap ? loaded : const {};
      } on YamlException {
        return null;
      }
      body = m.group(2) ?? '';
    }

    final sections = _splitSections(body);
    final title = (fm['title'] as String?)?.trim() ??
        _h1.firstMatch(body)?.group(1)?.trim() ??
        id;
    return Story(
      id: id,
      title: title,
      competencies: _stringList(fm['competencies']),
      level: (fm['level'] as String?)?.trim(),
      companies: _stringList(fm['companies']),
      situation: sections['situation'] ?? '',
      task: sections['task'] ?? '',
      action: sections['action'] ?? '',
      result: sections['result'] ?? '',
      learning: sections['learning'] ?? '',
      created: _date(fm['created']),
    );
  }

  static Map<String, String> _splitSections(String body) {
    final out = <String, String>{};
    String? heading;
    final buf = <String>[];
    void flush() {
      final h = heading;
      if (h != null) out[h] = buf.join('\n').trim();
    }

    for (final line in body.split('\n')) {
      final h = RegExp(r'^##[ \t]+(.+?)[ \t]*$').firstMatch(line);
      if (h != null) {
        flush();
        heading = h.group(1)!.trim().toLowerCase();
        buf.clear();
      } else if (heading != null) {
        buf.add(line);
      }
    }
    flush();
    return out;
  }

  static List<String> _stringList(dynamic v) {
    if (v == null) return const [];
    if (v is List) return [for (final e in v) e.toString().trim()];
    return [v.toString().trim()];
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}

const _unset = Object();
