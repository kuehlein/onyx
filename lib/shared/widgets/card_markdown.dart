import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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

    // Body: high-emphasis off-white (onSurface), never pure white, at 1.5.
    final body = text.bodyLarge!.copyWith(
      color: scheme.onSurface,
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
      p: body,
      pPadding: EdgeInsets.zero,
      blockSpacing: 14,
      h1: heading(text.headlineSmall!),
      h2: heading(text.titleLarge!),
      h3: heading(text.titleMedium!).copyWith(color: scheme.primary),
      h4: heading(text.titleSmall!).copyWith(color: scheme.primary),
      strong: body.copyWith(fontWeight: FontWeight.w700),
      em: body.copyWith(fontStyle: FontStyle.italic),
      a: body.copyWith(
        color: scheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: scheme.primary.withValues(alpha: 0.5),
      ),
      listBullet: body,
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
    );
  }
}
