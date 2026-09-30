import 'package:yaml/yaml.dart';

import '../../shared/models/card.dart';
import '../template/active_template.dart';
import '../template/deck_template.dart';

/// The live card-parsing facts for the ACTIVE subject's [ParseProfile], surfaced
/// by the "How cards are read" settings sheet (docs/settings-ux.md §4). Derived
/// from the profile (never restated), so it always reflects the real rules — a
/// subject that customizes its section level or file types shows its own facts.
List<({String label, String value})> cardParsingRules() {
  final template = activeTemplate;
  final p = template.parseProfile;
  return [
    (label: 'Sections split on', value: 'Headings (H${p.sectionHeadingLevel})'),
    (
      label: 'Reads files',
      value: p.fileExtensions.map((e) => '.$e').join(', '),
    ),
    (label: 'A note is a card when it matches', value: _cardnessRule(template)),
  ];
}

/// A human summary of what makes a file a card for [template]: the distinct flow
/// selector kinds (ADR-0020 §2 / #153). The all-`type:` case (the SWE subject) reads
/// simply "type:"; a folder/tag-selector subject shows its own rule, so a
/// zero-frontmatter vault isn't told it needs `type:` it doesn't actually require.
String _cardnessRule(DeckTemplate template) {
  const phrase = {
    'type': 'type:',
    'folder': 'a card folder',
    'tag': 'a card tag'
  };
  final kinds = {
    for (final f in template.flows) f.selector.toJson()['kind'] as String,
  };
  final parts = [for (final k in kinds) phrase[k] ?? k]..sort();
  return parts.isEmpty ? 'type:' : parts.join(' or ');
}

/// Parses a single Obsidian markdown file into a [Card].
///
/// The parser is pure (no I/O): callers read the file and hand over its text
/// plus a path for diagnostics. It is fence-aware — `##` lines inside fenced
/// code blocks do not start new sections — and it distinguishes two outcomes:
///
///  * returns `null` only when the file can't become a card at all — a subject that
///    declares no flows (nothing could practice it);
///  * throws [MalformedCardException] when a `---` frontmatter block is present but
///    broken (unparseable YAML, or not a key/value map) — surfaced so the author
///    fixes it rather than silently losing the card.
///
/// Card-ness is the deck LENS now, not the parser (ADR-0023): the parser is
/// permissive and returns a *candidate* for ANY note — no frontmatter, no H1, no
/// `type:` needed — resolving only its flow (the matched flow, else the default
/// flashcard flow); the indexer keeps the candidates a deck's lens claims. Every
/// authoring field is an optional override: `id:` else the filename slug (ADR-0022),
/// `type:` else the resolved flow's, the H1 title else the filename.
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
  /// [templateId] tags the card with its owning subject (task #30d); it defaults to
  /// the active subject's id, so single-subject parsing is unchanged. In a
  /// multi-subject vault the indexer passes the per-path subject id (M2).
  Card? parse(String content, {required String filePath, String? templateId}) {
    // Normalize Windows CRLF up front so neither the frontmatter values nor the
    // line-based H1/H2/fence scan carry a trailing \r. Dart's `.` and `$` don't
    // span/precede a \r, so a CRLF-terminated `# Title` otherwise fails the heading
    // regex — the card would silently lose its H1 title (falling back to the filename)
    // and mis-split its sections.
    final normalized = content.replaceAll('\r\n', '\n');
    final match = _frontmatter.firstMatch(normalized);

    // No frontmatter is NO LONGER an automatic skip (ADR-0022 / #153): card-ness is
    // decided by the subject's flow selectors below, so a folder/tag selector can
    // claim a plain, frontmatter-less note (the zero-frontmatter vault). A file WITH
    // frontmatter still parses it — a non-YamlMap or unparseable block still skips,
    // as before. With the default TypeIs selectors a note with no `type:` matches
    // nothing → skipped, so this stays byte-identical for the shipped SWE vault.
    final Map<String, dynamic> frontmatter;
    final String body;
    if (match == null) {
      frontmatter = const {};
      body = normalized;
    } else {
      final Object? parsed;
      try {
        parsed = loadYaml(match.group(1)!);
      } on YamlException {
        // Broken YAML inside a `---` block: the author meant frontmatter and botched
        // it. Surface it (malformed) so they fix it, rather than silently dropping the
        // card (ADR-0023 repurposes `malformed` from "missing H1" to "broken YAML").
        throw MalformedCardException(filePath, 'unparseable frontmatter');
      }
      if (parsed is! YamlMap) {
        throw MalformedCardException(
            filePath, 'frontmatter is not a key/value block');
      }
      frontmatter = _yamlToMap(parsed);
      body = match.group(2) ?? '';
    }

    // Behavior (card-ness, quizzability, flow) resolves against the card's own
    // subject (task #30d); single-subject vaults resolve to the one active
    // subject. The indexer passes the per-path subject id; a null default keeps
    // direct callers/tests on the active subject.
    final subject = templateFor(templateId ?? activeTemplate.id);

    // Card-ness AND flow are decided by the subject's flow SELECTORS (ADR-0020 §2,
    // #153): a file is a card iff some flow's selector matches its structural
    // attributes (type / tags / folder). A lightweight `probe` carries just those
    // attributes, so the match runs before the expensive title/section parse. With
    // the default TypeIs(cardType) selectors this is exactly the old
    // `isCardType(type)` gate — byte-identical for SWE — while a folder/tag selector
    // lets a card belong with NO frontmatter at all.
    final rawType = (frontmatter['type'] as String?)?.trim();
    final tags = _stringList(frontmatter['tags']) ?? const <String>[];
    final tiers = _intMap(frontmatter['tiers']);
    final probe = Card(
      id: '',
      type: rawType ?? '',
      templateId: templateId ?? activeTemplate.id,
      title: '',
      overview: '',
      tags: tags,
      tiers: tiers,
      sections: const [],
      wikilinks: const [],
      filePath: filePath,
    );
    // Card-ness is decided by the indexer's deck-lens gate now (ADR-0023), not here.
    // The parser only resolves the FLOW: the first flow whose selector matches, else
    // the subject's default flashcard flow (ADR-0020 §2). So any well-formed note is a
    // candidate the deck lens can claim (the zero-frontmatter vault); only a subject
    // that declares NO flows yields null. Byte-identical for SWE — a recognized `type:`
    // matches its selector, and the dev-vault lenses union to Everything.
    FlowSpec? flow;
    for (final f in subject.flows) {
      if (f.selector.matches(probe)) {
        flow = f;
        break;
      }
    }
    flow ??= subject.defaultFlow;
    if (flow == null) {
      return null; // subject declares no flows → can't be a card
    }
    // A frontmatter-less (or type-less) card takes its type from the flow that
    // claimed it, so `Card.type` and every type-derived accessor stay consistent
    // with the resolved flow (a folder/tag selector may pick a flow over TypeIs).
    final type = rawType ?? flow.cardType;

    // Card identity (ADR-0022): the explicit `id:` when present — a durable / shareable
    // override — else the bare filename slug, so a card needs no `id:` glue. The
    // filename default aligns cardId with the wikilink / `depends-on` / `## Related`
    // namespace (all key on the filename), killing the id-vs-filename join-bug class.
    final rawId = (frontmatter['id'] as String?)?.trim();
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : slugify(
            filePath.split('/').last.replaceFirst(RegExp(r'\.[^.]+$'), ''));

    final profile = subject.parseProfile;
    final (h1Title, overview, rawSections) =
        _splitBody(body, _sectionRegex(profile.sectionHeadingLevel));
    // An H1 is no longer required (ADR-0023): a card's title falls back to its
    // FILENAME (Obsidian's convention — the filename IS the note name), so a plain
    // body-only note is a valid card. The user shapes structure via the parse
    // profile; the engine imposes none.
    final title = h1Title ??
        filePath.split('/').last.replaceFirst(RegExp(r'\.[^.]+$'), '');

    // Quizzability is purely the flow's policy now — the per-card `quiz:`/`quizzable:`
    // overrides were removed (ADR-0020 §2: thin cards carry no study-set glue; the
    // "stop testing this section" control moves to an app-state dismiss, #162).
    final sections = [
      for (final raw in rawSections)
        _buildSection(raw.heading, raw.content, subject, flow),
    ];

    return Card(
      id: id,
      type: type,
      templateId: templateId ?? activeTemplate.id,
      title: title,
      overview: overview,
      tags: tags,
      tiers: tiers,
      sections: sections,
      wikilinks: profile.wikilinks ? _extractWikilinks(body) : const [],
      filePath: filePath,
      created: _parseDate(frontmatter['created']),
      confidence: Confidence.fromString(frontmatter['confidence'] as String?),
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
    DeckTemplate subject,
    FlowSpec flow,
  ) {
    final slug = slugify(heading);
    // Which sections are quizzable is the RESOLVED flow's policy (ADR-0020 §2) — the
    // flow that actually claimed this card, not a re-lookup by `type:` (which a
    // folder/tag selector may not match).
    final policy = flow.quizzability;
    final quizzable = switch (policy) {
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
