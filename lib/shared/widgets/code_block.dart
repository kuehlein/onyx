import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
// The `code` element type comes from the markdown package (a transitive dep of
// flutter_markdown_plus); we reference it directly in the builder signature.
// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;

/// Dracula, with the comment colour lifted for contrast. The stock comment
/// (#6272A4 on #282A36) is ~2.5:1 — below WCAG's 4.5:1 and a known weak spot for
/// dark themes; in a learning tool comments carry real pedagogy, so we brighten
/// them (kept in-palette, still italic) rather than let them fade out.
final Map<String, TextStyle> _codeTheme = {
  ...draculaTheme,
  'comment':
      const TextStyle(color: Color(0xFF9BA6D6), fontStyle: FontStyle.italic),
  'quote':
      const TextStyle(color: Color(0xFF9BA6D6), fontStyle: FontStyle.italic),
};

/// Renders fenced code blocks with syntax highlighting (Dracula — its purple
/// accents suit the app's violet scheme, and its distinct panel background
/// separates code from prose). Inline code falls through to the stylesheet.
///
/// Registered on the `code` element, which Markdown uses for both inline spans
/// and fenced blocks; we only take over multi-line / language-tagged blocks.
class CodeBlockBuilder extends MarkdownElementBuilder {
  static const _monospace = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Consolas', 'Roboto Mono', 'monospace'],
    fontSize: 13,
    height: 1.45,
  );

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final content = element.textContent;
    final className = element.attributes['class']; // e.g. "language-dart"
    final hasLanguage = className != null && className.startsWith('language-');
    final isBlock = hasLanguage || content.contains('\n');
    if (!isBlock) return null; // inline code -> default stylesheet handling

    final language =
        hasLanguage ? className.substring('language-'.length) : null;
    final code = content.replaceFirst(RegExp(r'\n$'), '');
    final background =
        draculaTheme['root']?.backgroundColor ?? const Color(0xFF282A36);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          color: background,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HighlightView(
              code,
              language: language,
              theme: _codeTheme,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              textStyle: _monospace,
            ),
          ),
        ),
      ),
    );
  }
}
