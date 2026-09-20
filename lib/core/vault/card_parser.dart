import 'package:yaml/yaml.dart';

import '../../shared/models/card.dart';
import '../subject/active_subject.dart';
import '../subject/subject_config.dart';

/// The live card-parsing facts for the ACTIVE subject's [ParseProfile], surfaced
/// by the "How cards are read" settings sheet (docs/settings-ux.md §4). Derived
/// from the profile (never restated), so it always reflects the real rules — a
/// subject that customizes its section level or file types shows its own facts.
List<({String label, String value})> cardParsingRules() {
  final p = activeSubject.parseProfile;
  return [
    (label: 'Sections split on', value: 'Headings (H${p.sectionHeadingLevel})'),
    (
      label: 'Reads files',
      value: p.fileExtensions.map((e) => '.$e').join(', '),
    ),
    (label: 'A note is a card when it has', value: 'type:'),
  ];
}

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

  /// The default section marker (H2). A subject with a different
  /// [ParseProfile.sectionHeadingLevel] gets a level-specific regex from
  /// [_sectionRegex]; kept as a field so the common level-2 case allocates none.
  static final RegExp _h2 = RegExp(r'^##[ \t]+(.+?)[ \t]*$');
  static final RegExp _fence = RegExp(r'^[ \t]*(```|~~~)');

  /// The heading regex that splits sections at [level] (2 → [_h2]). Requires
  /// EXACTLY [level] `#`s then whitespace, so a deeper heading (an extra `#`) or a
  /// shallower one (e.g. the H1 title) is treated as content rather than a split.
  static RegExp _sectionRegex(int level) =>
      level == 2 ? _h2 : RegExp('^#{$level}[ \\t]+(.+?)[ \\t]*\$');

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
    // A "Variants" list is an enumeration, not an atomic recall target —
    // testing "name every variant" is a weak, hard-to-self-grade prompt (see
    // docs/learning-science.md, minimum-information principle). Kept in the card
    // as browse/reference (visible in-flow via "View full card").
    'variants',
    // Code/implementation is study REFERENCE, not a recall target — you should
    // reconstruct it from the approach, not memorize it verbatim (see
    // docs/learning-science.md). Kept in the card and viewable in-flow via
    // "View full card"; actual implementation practice is the Solve loop.
    ...implementationHeadings,
  };

  /// Parses [content] into a [Card], or null when the file is not an Onyx card.
  ///
  /// [subjectId] tags the card with its owning subject (task #30d); it defaults to
  /// the active subject's id, so single-subject parsing is unchanged. In a
  /// multi-subject vault the indexer passes the per-path subject id (M2).
  Card? parse(String content, {required String filePath, String? subjectId}) {
    // Normalize Windows CRLF up front so neither the frontmatter values nor the
    // line-based H1/H2/fence scan carry a trailing \r. Dart's `.` and `$` don't
    // span/precede a \r, so a CRLF-terminated `# Title` otherwise fails the
    // heading regex and the whole card is rejected (MalformedCardException).
    final normalized = content.replaceAll('\r\n', '\n');
    final match = _frontmatter.firstMatch(normalized);
    if (match == null) return null; // no frontmatter → not a card

    final Map<String, dynamic> frontmatter;
    try {
      final loaded = loadYaml(match.group(1)!);
      if (loaded is! YamlMap) return null;
      frontmatter = _yamlToMap(loaded);
    } on YamlException {
      return null; // unparseable frontmatter → skip rather than crash indexing
    }

    // Behavior (card-ness, quizzability, flow) resolves against the card's own
    // subject (task #30d); single-subject vaults resolve to the one active
    // subject. The indexer passes the per-path subject id; a null default keeps
    // direct callers/tests on the active subject.
    final subject = subjectFor(subjectId ?? activeSubject.id);

    final type = (frontmatter['type'] as String?)?.trim();
    // A file is an Onyx card iff its `type:` matches one of the subject's
    // configured flows; everything else (config, `_meta/`, ordinary notes) is
    // skipped. (Was: CardType.fromString != null — a no-op for the SWE subject.)
    if (type == null || !subject.isCardType(type)) return null;

    final id = (frontmatter['id'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw MissingCardIdException(filePath);
    }

    final profile = subject.parseProfile;
    final body = match.group(2) ?? '';
    final (title, overview, rawSections) =
        _splitBody(body, _sectionRegex(profile.sectionHeadingLevel));
    if (title == null) {
      throw MalformedCardException(filePath, 'missing H1 title');
    }

    final quizOverride = _stringList(frontmatter['quiz']);
    final sections = [
      for (final raw in rawSections)
        _buildSection(raw.heading, raw.content, subject, type, quizOverride),
    ];

    return Card(
      id: id,
      type: type,
      subjectId: subjectId ?? activeSubject.id,
      title: title,
      overview: overview,
      tags: _stringList(frontmatter['tags']) ?? const [],
      tiers: _intMap(frontmatter['tiers']),
      sections: sections,
      wikilinks: profile.wikilinks ? _extractWikilinks(body) : const [],
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
      dependsOn: _stringList(frontmatter['depends-on']) ?? const [],
      priority: Priority.fromString(frontmatter['priority'] as String?) ??
          Priority.normal,
      estMinutes: _positiveNum(frontmatter['est_minutes']),
      status: CardStatus.fromString(frontmatter['status'] as String?),
      deckId: (frontmatter['deck'] as String?) ?? '',
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
    SubjectConfig subject,
    String type,
    List<String>? quizOverride,
  ) {
    final slug = slugify(heading);
    final bool quizzable;
    if (quizOverride != null && quizOverride.isNotEmpty) {
      quizzable = quizOverride.contains(slug);
    } else {
      // Which sections are quizzable is the flow's policy (task #30 Phase 3),
      // configured per card type; unknown types fall back to the concept blocklist.
      final policy = subject.flowForType(type)?.quizzability ??
          QuizzabilityPolicy.blocklist;
      quizzable = switch (policy) {
        // Every section is a problem = its own practice unit (algorithms).
        QuizzabilityPolicy.allSections => true,
        // Whole card is one mock unit; no section is scheduled (SD / behavioral).
        QuizzabilityPolicy.noSections => false,
        // Interview questions default to quizzing only the Approach section.
        QuizzabilityPolicy.approachOnly => slug == 'approach',
        // Concept cards: everything but the shared reference/blocklist headings.
        // A subject may override the never-quizzed set via its parse profile.
        QuizzabilityPolicy.blocklist =>
          !(subject.parseProfile.neverQuizzed ?? _blocklist)
              .contains(heading.trim().toLowerCase()),
      };
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
  (String?, String, List<_RawSection>) _splitBody(
      String body, RegExp sectionRe) {
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
        final h2 = sectionRe.firstMatch(line);
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

  /// A positive number from frontmatter (int or double, or a numeric string),
  /// or null. Used for `est_minutes:`; non-positive or unparseable → null so the
  /// plan falls back to its default estimate.
  static double? _positiveNum(dynamic value) {
    if (value == null) return null;
    final n =
        value is num ? value.toDouble() : double.tryParse(value.toString());
    return (n != null && n > 0) ? n : null;
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
