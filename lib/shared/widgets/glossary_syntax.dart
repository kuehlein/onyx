// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;

/// Marks known glossary terms in card text as tappable links with a `gloss:`
/// href, so they render as native inline link spans (proper wrapping/baseline)
/// and route through the existing `onTapLink`. Appended AFTER the standard
/// inline syntaxes (esp. code) so it never matches inside inline code.
class GlossarySyntax extends md.InlineSyntax {
  GlossarySyntax(Set<String> terms) : super(_pattern(terms));

  static String _pattern(Set<String> terms) {
    // Longest-first alternation, word-boundaried, so "DNSSEC" wins over "DNS".
    final sorted = terms.toList()..sort((a, b) => b.length.compareTo(a.length));
    return r'\b(' + sorted.map(RegExp.escape).join('|') + r')\b';
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final term = match[1]!;
    final anchor = md.Element('a', [md.Text(term)])
      ..attributes['href'] = 'gloss:$term';
    parser.addNode(anchor);
    return true;
  }
}
