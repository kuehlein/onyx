import 'package:yaml/yaml.dart';

import '../../shared/models/card.dart';

/// Parses a single Obsidian markdown file into a [Card].
///
/// The parser is pure (no I/O): callers read the file and hand over its text
/// plus a path for diagnostics. It is fence-aware — `##` lines inside fenced
/// code blocks do not start new sections — and it distinguishes three outcomes:
///
///  * returns `null` when the file is not an Onyx card (no recognized `type`),
///    which is how `_meta/` files and ordinary notes are skipped;
///  * throws [MissingCardIdException] when a valid card lacks an `id`;
///  * throws [MalformedCardException] when a card is structurally invalid.
class CardParser {
  const CardParser();

  /// Frontmatter block: a leading `---` line, YAML, then a closing `---` line.
  /// Group 1 is the YAML, group 2 is the remaining body.
  static final RegExp _frontmatter =
      RegExp(r'^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n?(.*)$', dotAll: true);
  static final RegExp _h1 = RegExp(r'^#[ \t]+(.+?)[ \t]*$');
  static final RegExp _h2 = RegExp(r'^##[ \t]+(.+?)[ \t]*$');
  static final RegExp _fence = RegExp(r'^[ \t]*(```|~~~)');

  /// `[[target]]`, `[[target|alias]]`, `[[target#heading]]`. Group 1 is the
  /// target filename (without `.md`), excluding any `#` anchor or `|` alias.
  static final RegExp _wikilink =
      RegExp(r'\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|[^\]]+)?\]\]');

  /// Headings never scheduled for review (case-insensitive, matched on the
  /// heading text). Mirrors the blocklist documented in `docs/card-schema.md`.
  static const Set<String> _blocklist = {
    'related',
    'related concepts',
    'references',
    'notes',
    'see also',
    'links',
    'overview',
    'background',
    'resources',
    'follow-up questions',
  };

  Card? parse(String content, {required String filePath}) {
    final match = _frontmatter.firstMatch(content);
    if (match == null) return null; // no frontmatter → not a card

    final Map<String, dynamic> frontmatter;
    try {
      final loaded = loadYaml(match.group(1)!);
      if (loaded is! YamlMap) return null;
      frontmatter = _yamlToMap(loaded);
    } on YamlException {
      return null; // unparseable frontmatter → skip rather than crash indexing
    }

    final type = CardType.fromString(frontmatter['type'] as String?);
    if (type == null) return null; // not an Onyx card type

    final id = (frontmatter['id'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw MissingCardIdException(filePath);
    }

    final body = match.group(2) ?? '';
    final (title, overview, rawSections) = _splitBody(body);
    if (title == null) {
      throw MalformedCardException(filePath, 'missing H1 title');
    }

    final quizOverride = _stringList(frontmatter['quiz']);
    final sections = [
      for (final raw in rawSections)
        _buildSection(raw.heading, raw.content, type, quizOverride),
    ];

    return Card(
      id: id,
      type: type,
      title: title,
      overview: overview,
      tags: _stringList(frontmatter['tags']) ?? const [],
      tiers: _intMap(frontmatter['tiers']),
      sections: sections,
      wikilinks: _extractWikilinks(body),
      filePath: filePath,
      created: _parseDate(frontmatter['created']),
      confidence: Confidence.fromString(frontmatter['confidence'] as String?),
      quizOverride:
          (quizOverride == null || quizOverride.isEmpty) ? null : quizOverride,
      category: frontmatter['category'] as String?,
      difficulty: frontmatter['difficulty'] as String?,
      frequency: frontmatter['frequency'] as String?,
      practiceUrl: frontmatter['practice_url'] as String?,
      source: frontmatter['source'] as String?,
      domains: _stringList(frontmatter['domains']) ?? const [],
      concepts: _stringList(frontmatter['concepts']) ?? const [],
      priority: Priority.fromString(frontmatter['priority'] as String?) ??
          Priority.normal,
    );
  }

  /// Converts an H2 heading to its `section_slug`: lowercase, with each run of
  /// non-alphanumeric characters collapsed to a single hyphen and leading or
  /// trailing hyphens removed. e.g. `"Time & Space Complexity"` →
  /// `"time-space-complexity"`.
  static String slugify(String heading) => heading
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  CardSection _buildSection(
    String heading,
    String content,
    CardType type,
    List<String>? quizOverride,
  ) {
    final slug = slugify(heading);
    final bool quizzable;
    if (quizOverride != null && quizOverride.isNotEmpty) {
      quizzable = quizOverride.contains(slug);
    } else if (type == CardType.interviewQuestion) {
      // Interview questions default to quizzing only the Approach section.
      quizzable = slug == 'approach';
    } else {
      quizzable = !_blocklist.contains(heading.trim().toLowerCase());
    }
    return CardSection(
      heading: heading,
      slug: slug,
      content: content,
      quizzable: quizzable,
    );
  }

  /// Splits a card body into (H1 title, pre-H2 overview, H2 sections), ignoring
  /// `#`/`##` lines that fall inside fenced code blocks.
  (String?, String, List<_RawSection>) _splitBody(String body) {
    String? title;
    final overview = <String>[];
    final sections = <_RawSection>[];

    String? currentHeading;
    var currentContent = <String>[];
    var inFence = false;

    void flush() {
      if (currentHeading != null) {
        sections.add(_RawSection(currentHeading, _joinTrimmed(currentContent)));
      }
    }

    for (final line in body.split('\n')) {
      if (_fence.hasMatch(line)) {
        inFence = !inFence;
        (currentHeading == null ? overview : currentContent).add(line);
        continue;
      }

      if (!inFence) {
        final h2 = _h2.firstMatch(line);
        if (h2 != null) {
          flush();
          currentHeading = h2.group(1)!.trim();
          currentContent = <String>[];
          continue;
        }
        final h1 = _h1.firstMatch(line);
        if (h1 != null && title == null && currentHeading == null) {
          title = h1.group(1)!.trim();
          continue;
        }
      }

      (currentHeading == null ? overview : currentContent).add(line);
    }
    flush();

    return (title, _joinTrimmed(overview), sections);
  }

  List<String> _extractWikilinks(String body) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final match in _wikilink.allMatches(body)) {
      final target = match.group(1)!.trim();
      if (target.isNotEmpty && seen.add(target)) ordered.add(target);
    }
    return ordered;
  }

  static String _joinTrimmed(List<String> lines) => lines.join('\n').trim();

  static Map<String, dynamic> _yamlToMap(YamlMap map) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      result[entry.key.toString()] = _yamlToDart(entry.value);
    }
    return result;
  }

  static dynamic _yamlToDart(dynamic value) {
    if (value is YamlMap) return _yamlToMap(value);
    if (value is YamlList) return value.map(_yamlToDart).toList();
    return value;
  }

  static List<String>? _stringList(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => e.toString()).toList();
    return [value.toString()];
  }

  static Map<String, int> _intMap(dynamic value) {
    if (value is! Map) return const {};
    final result = <String, int>{};
    value.forEach((key, dynamic raw) {
      final n = raw is int ? raw : int.tryParse(raw.toString());
      if (n != null) result[key.toString()] = n;
    });
    return result;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

/// An H2 section before quizzable/slug rules are applied.
class _RawSection {
  const _RawSection(this.heading, this.content);
  final String heading;
  final String content;
}
