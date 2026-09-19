import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
// highlight's language registry — used to check a fence's language is known
// before highlighting (an unknown/null language makes parse() throw).
// ignore: depend_on_referenced_packages
import 'package:highlight/languages/all.dart' show allLanguages;
// The `code` element type comes from the markdown package (a transitive dep of
// flutter_markdown_plus); we reference it directly in the builder signature.
// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;

import '../design/onyx_design.dart';

/// Renders fenced code blocks with syntax highlighting on a distinct panel
/// background that separates code from prose. Inline code falls through to the
/// stylesheet.
///
/// Registered on the `code` element, which Markdown uses for both inline spans
/// and fenced blocks; we only take over multi-line / language-tagged blocks.
/// Common fence aliases → the canonical name the highlight registry uses.
const Map<String, String> _languageAliases = {
  'js': 'javascript',
  'jsx': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'py': 'python',
  'sh': 'bash',
  'shell': 'bash',
  'zsh': 'bash',
  'console': 'bash',
  'yml': 'yaml',
  'md': 'markdown',
  'c++': 'cpp',
  'cs': 'csharp',
  'rb': 'ruby',
  'rs': 'rust',
  'kt': 'kotlin',
  'golang': 'go',
  'html': 'xml',
  'plaintext': '',
  'text': '',
  'txt': '',
};

/// Maps a fence tag to a highlight language the registry knows, resolving
/// aliases; returns null for bare/unknown/plain-text fences (render plain).
String? _resolveLanguage(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final key = raw.toLowerCase();
  final canonical = _languageAliases[key] ?? key;
  if (canonical.isEmpty) return null; // explicitly plain (e.g. ```text)
  return allLanguages.containsKey(canonical) ? canonical : null;
}

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

    final rawLang =
        hasLanguage ? className.substring('language-'.length) : null;
    // Resolve common aliases the registry is keyed by canonical name only
    // (e.g. ```js -> javascript), then only highlight a language it actually
    // knows — a bare fence (null) or unknown tag renders plain rather than
    // making highlight.parse() throw.
    final language = _resolveLanguage(rawLang);
    final code = content.replaceFirst(RegExp(r'\n$'), '');
    const background = onyxCodePanel;
    const foreground = onyxCodeInk;
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: Dim.space3);

    // Soft-wrap rather than scroll horizontally: on a phone, panning long lines
    // is a real irritant while studying. Both HighlightView's RichText and the
    // plain Text wrap once given a bounded width (no horizontal scroll view).
    final Widget body = language != null
        ? HighlightView(
            code,
            language: language,
            theme: onyxCodeTheme,
            padding: padding,
            textStyle: _monospace,
          )
        : Padding(
            padding: padding,
            child: Text(code, style: _monospace.copyWith(color: foreground)),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dim.space2),
      child: ClipRRect(
        borderRadius: Dim.brChip,
        child: Container(
          width: double.infinity,
          color: background,
          child: body,
        ),
      ),
    );
  }
}
