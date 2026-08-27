import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
// The extension set (for GFM tables etc.) comes from the markdown package, a
// transitive dep of flutter_markdown_plus.
// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import 'code_block.dart';

/// Renders card Markdown with a stylesheet tuned for reading/retention:
/// 16px body at 1.5 line-height, generous spacing between blocks, off-white
/// (not pure-white) body text, primary-tinted headings for signaling, and
/// syntax-highlighted code blocks. Text is selectable; external links open in
/// the browser. Line length is meant to be constrained by the caller (~66ch).
class CardMarkdown extends StatelessWidget {
  const CardMarkdown(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: _styleSheet(context),
      builders: {'code': CodeBlockBuilder()},
      // GitHub-flavored so pipe tables, strikethrough, and ```lang fences parse.
      extensionSet: md.ExtensionSet.gitHubFlavored,
      onTapLink: (text, href, title) => _onTapLink(href),
    );
  }

  Future<void> _onTapLink(String? href) async {
    if (href == null) return;
    final uri = Uri.tryParse(href);
    if (uri == null || !uri.hasScheme) return; // ignore bare/relative refs
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
      pPadding: const EdgeInsets.only(top: 13, bottom: 2),
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
      // Fallback for fenced blocks without a language (CodeBlockBuilder handles
      // the highlighted case); keep it a calm rounded panel.
      codeblockPadding: const EdgeInsets.all(14),
      codeblockDecoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
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
