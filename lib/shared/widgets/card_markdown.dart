import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// The extension set (for GFM tables etc.) comes from the markdown package, a
// transitive dep of flutter_markdown_plus.
// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../providers/glossary.dart';
import 'callout.dart';
import 'code_block.dart';

/// Renders card Markdown with a stylesheet tuned for reading/retention:
/// 16px body at 1.5 line-height, generous spacing between blocks, off-white
/// (not pure-white) body text, primary-tinted headings for signaling, and
/// syntax-highlighted code blocks. Text is selectable; external links open in
/// the browser. Line length is meant to be constrained by the caller (~66ch).
///
/// Obsidian-style callouts (`> [!tip] Title` … ) render as tinted, iconed
/// panels. Links into the vault glossary note (`[API](_meta/glossary.md#api)`)
/// pop a definition sheet instead of navigating. Everything else is normal
/// Markdown.
class CardMarkdown extends ConsumerWidget {
  const CardMarkdown(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glossary = ref.watch(glossaryProvider).asData?.value ?? const {};
    final segments = _splitCallouts(data);

    // Common case: no callouts — render the whole thing as one Markdown block.
    if (segments.length == 1 && !segments.first.isCallout) {
      return _markdown(context, segments.first.content, glossary);
    }

    final children = <Widget>[];
    for (final segment in segments) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(
        segment.isCallout
            ? Callout(
                type: segment.calloutType!,
                title: segment.calloutTitle,
                body: segment.content.isEmpty
                    ? null
                    : _markdown(context, segment.content, glossary),
              )
            : _markdown(context, segment.content, glossary),
      );
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _markdown(
    BuildContext context,
    String data,
    Map<String, String> glossary,
  ) {
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: _styleSheet(context),
      builders: {'code': CodeBlockBuilder()},
      // GitHub-flavored so pipe tables, strikethrough, and ```lang fences parse.
      extensionSet: md.ExtensionSet.gitHubFlavored,
      onTapLink: (text, href, title) =>
          _onTapLink(context, text, href, glossary),
    );
  }

  /// A link whose path ends in the glossary note is resolved to a definition
  /// sheet (the anchor is the term slug); any other link opens externally.
  Future<void> _onTapLink(
    BuildContext context,
    String text,
    String? href,
    Map<String, String> glossary,
  ) async {
    if (href == null) return;

    final hash = href.indexOf('#');
    if (hash != -1) {
      final path = href.substring(0, hash).toLowerCase();
      if (path.endsWith('glossary.md')) {
        var anchor = href.substring(hash + 1).toLowerCase();
        if (anchor.startsWith('^')) anchor = anchor.substring(1); // block-ref
        final definition = glossary[anchor];
        if (definition != null) {
          _showDefinition(context, text.isEmpty ? anchor : text, definition);
        }
        return;
      }
    }

    final uri = Uri.tryParse(href);
    if (uri == null || !uri.hasScheme) return; // ignore bare/relative refs
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showDefinition(BuildContext context, String term, String definition) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(term,
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            Text(definition,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _styleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;

    // Body: softened off-white (~87% of onSurface), never pure white — cuts
    // halation/glare on the dark surface while staying well above 4.5:1. Reserve
    // full-brightness onSurface for emphasis (see `strong`) so bold terms pop.
    final bodyColor = scheme.onSurface.withValues(alpha: 0.87);
    final body = text.bodyLarge!.copyWith(
      color: bodyColor,
      height: 1.5,
      fontSize: 16,
    );
    final mono = text.bodyMedium!.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Consolas', 'Roboto Mono'],
      fontSize: 14,
    );

    TextStyle heading(TextStyle base) => base.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          height: 1.3,
        );

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      // Gestalt proximity: flutter_markdown puts one uniform gap between *all*
      // sibling blocks, so a small blockSpacing pulls list items into a tight
      // group — then pPadding (paragraphs only; list items are exempt) and the
      // heading paddings add the breathing room back between prose blocks.
      // Net: bullets tightest, paragraphs airy, subheadings clearly separated.
      p: body,
      // Asymmetric on purpose: a small *bottom* lets a list hug the lead-in line
      // it belongs to, while a larger *top* pushes the following block away — so
      // a list groups with the sentence above it, not floating equidistant. (List
      // items carry no padding, so only paragraphs move.)
      pPadding: const EdgeInsets.only(top: 13, bottom: 0),
      blockSpacing: 4,
      h1: heading(text.headlineSmall!),
      h1Padding: const EdgeInsets.only(top: 14),
      h2: heading(text.titleLarge!),
      h2Padding: const EdgeInsets.only(top: 14),
      h3: heading(text.titleMedium!).copyWith(color: scheme.primary),
      h3Padding: const EdgeInsets.only(top: 14),
      h4: heading(text.titleSmall!).copyWith(color: scheme.primary),
      h4Padding: const EdgeInsets.only(top: 14),
      // Emphasis pops via full brightness + weight (opacity-tier signaling).
      strong: body.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      em: body.copyWith(fontStyle: FontStyle.italic),
      a: body.copyWith(
        color: scheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: scheme.primary.withValues(alpha: 0.5),
      ),
      // Accent only the bullet marker (not the item text) so lists are scannable
      // without lowering text contrast.
      listBullet: body.copyWith(color: scheme.primary),
      listIndent: 22,
      // Inline code: a subtle tinted chip, distinct from prose without shouting.
      code: mono.copyWith(
        backgroundColor: scheme.surfaceContainerHighest,
        color: scheme.onSurface,
      ),
      // CodeBlockBuilder draws the whole code panel itself, so the <pre>
      // wrapper must add nothing — otherwise it paints a grey box with padding
      // around the real (dark) panel. Zero padding + a transparent decoration.
      codeblockPadding: EdgeInsets.zero,
      codeblockDecoration: const BoxDecoration(),
      blockquote: body.copyWith(color: scheme.onSurfaceVariant),
      blockquotePadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      blockquoteDecoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
      ),
      // Tables: a real grid — visible cell borders, roomy padding, and a bold,
      // tinted header row so the structure reads at a glance. Columns flex to
      // share the width so cells wrap instead of forcing a horizontal scroll.
      tableColumnWidth: const FlexColumnWidth(),
      tableBorder: TableBorder.all(color: scheme.outlineVariant),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tableHeadAlign: TextAlign.left,
      tableHead: body.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      tableBody: body.copyWith(fontSize: 15),
    );
  }
}

/// A run of the source: either a normal Markdown chunk or a parsed callout.
class _Segment {
  const _Segment.markdown(this.content)
      : isCallout = false,
        calloutType = null,
        calloutTitle = null;

  const _Segment.callout({
    required this.calloutType,
    required this.calloutTitle,
    required this.content,
  }) : isCallout = true;

  final bool isCallout;
  final String? calloutType;
  final String? calloutTitle;
  final String content;
}

/// The head of an Obsidian callout: `> [!type]`, optional fold marker, optional
/// inline title. e.g. `> [!warning]- Careful`.
final _calloutHead = RegExp(r'^>\s?\[!(\w+)\][+-]?\s*(.*)$');
final _quoteLine = RegExp(r'^>\s?');

/// Splits the source into normal-Markdown and callout segments. Contiguous
/// `>`-quoted lines that open with `[!type]` become callouts; ordinary
/// blockquotes stay in the Markdown stream and render via the stylesheet.
List<_Segment> _splitCallouts(String source) {
  final lines = source.split('\n');
  final segments = <_Segment>[];
  final buffer = <String>[];

  void flush() {
    if (buffer.isEmpty) return;
    final text = buffer.join('\n').trim();
    if (text.isNotEmpty) segments.add(_Segment.markdown(text));
    buffer.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final head = _calloutHead.firstMatch(lines[i]);
    if (head == null) {
      buffer.add(lines[i]);
      i++;
      continue;
    }
    flush();
    final title = head.group(2)!.trim();
    final body = <String>[];
    i++;
    while (i < lines.length && lines[i].startsWith('>')) {
      body.add(lines[i].replaceFirst(_quoteLine, ''));
      i++;
    }
    segments.add(_Segment.callout(
      calloutType: head.group(1)!,
      calloutTitle: title.isEmpty ? null : title,
      content: body.join('\n').trim(),
    ));
  }
  flush();

  return segments.isEmpty ? [const _Segment.markdown('')] : segments;
}
