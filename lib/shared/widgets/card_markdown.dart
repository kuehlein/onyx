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
/// panels. Links into the vault glossary note (`[TCP](_meta/glossary.md#tcp)`)
/// render as discreet dotted terms and, on tap, show a small definition popover
/// anchored to the term (Wikipedia-style) rather than navigating.
class CardMarkdown extends ConsumerStatefulWidget {
  const CardMarkdown(this.data, {super.key});

  final String data;

  @override
  ConsumerState<CardMarkdown> createState() => _CardMarkdownState();
}

class _CardMarkdownState extends ConsumerState<CardMarkdown> {
  // Last pointer-down position, used to anchor the glossary popover to the term
  // (onTapLink doesn't report coordinates).
  Offset? _tapDown;

  @override
  Widget build(BuildContext context) {
    final glossary = ref.watch(glossaryProvider).asData?.value ?? const {};
    final segments = _splitCallouts(widget.data);

    final Widget content;
    if (segments.length == 1 && !segments.first.isCallout) {
      content = _markdown(context, segments.first.content, glossary);
    } else {
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
      content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }

    return Listener(
      onPointerDown: (event) => _tapDown = event.position,
      child: content,
    );
  }

  Widget _markdown(
    BuildContext context,
    String data,
    Map<String, String> glossary,
  ) {
    final sheet = _styleSheet(context);
    final scheme = Theme.of(context).colorScheme;
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: sheet,
      builders: {
        'code': CodeBlockBuilder(),
        // Custom link rendering: a real bottom border lets the underline sit
        // lower and thicker than a text-decoration underline (which Flutter
        // can't offset, so it collides with the glyphs).
        'a': _LinkBuilder(
          textStyle: sheet.p ?? const TextStyle(),
          underlineColor: scheme.onSurfaceVariant,
          onTap: (text, href) => _handleLink(context, text, href, glossary),
        ),
      },
      // GitHub-flavored so pipe tables, strikethrough, and ```lang fences parse.
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
  }

  /// A link whose path ends in the glossary note pops a definition (its anchor
  /// is the term slug); any other link opens externally.
  Future<void> _handleLink(
    BuildContext context,
    String text,
    String href,
    Map<String, String> glossary,
  ) async {
    final hash = href.indexOf('#');
    if (hash != -1) {
      final path = href.substring(0, hash).toLowerCase();
      if (path.endsWith('glossary.md')) {
        var anchor = href.substring(hash + 1).toLowerCase();
        if (anchor.startsWith('^')) anchor = anchor.substring(1); // block-ref
        final definition = glossary[anchor];
        if (definition != null) {
          _showGlossaryPopover(
              context, text.isEmpty ? anchor : text, definition);
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

  /// A small floating card near the tapped term; tap outside to dismiss.
  void _showGlossaryPopover(
      BuildContext context, String term, String definition) {
    final overlay = Overlay.of(context);
    final theme = Theme.of(context);
    final screen = MediaQuery.of(context).size;
    final tap = _tapDown ?? Offset(screen.width / 2, screen.height / 2);

    const width = 300.0;
    const estHeight = 160.0;
    final left = (tap.dx - width / 2).clamp(8.0, screen.width - width - 8);
    final below = tap.dy + 16;
    final flipAbove = below + estHeight > screen.height - 16;
    final top = flipAbove
        ? (tap.dy - estHeight - 16).clamp(8.0, screen.height - 16)
        : below;

    late OverlayEntry entry;
    void dismiss() {
      if (entry.mounted) entry.remove();
    }

    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismiss,
              child: const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: GestureDetector(
              onTap: () {}, // absorb taps on the card so it doesn't dismiss
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: width, maxHeight: screen.height * 0.5),
                child: Material(
                  elevation: 8,
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(term,
                              style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(definition,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.4,
                                  color: theme.colorScheme.onSurface)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
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
      // Links are rendered by _LinkBuilder (custom underline), so this style is
      // unused for `a`; keep it plain.
      a: body,
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

/// Renders a Markdown link (`a`) with a custom underline that can sit lower and
/// thicker than a text-decoration underline, and routes taps to [onTap].
class _LinkBuilder extends MarkdownElementBuilder {
  _LinkBuilder({
    required this.textStyle,
    required this.underlineColor,
    required this.onTap,
  });

  final TextStyle textStyle;
  final Color underlineColor;
  final void Function(String text, String href) onTap;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final href = element.attributes['href'];
    if (href == null) return null;
    final label = element.textContent;
    return _LinkText(
      text: label,
      style: textStyle,
      underlineColor: underlineColor,
      onTap: () => onTap(label, href),
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({
    required this.text,
    required this.style,
    required this.underlineColor,
    required this.onTap,
  });

  final String text;
  final TextStyle style;
  final Color underlineColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        // Dotted line painted in the reserved bottom padding — control over
        // dots, thickness, and offset that a text-decoration underline lacks.
        foregroundPainter: _DottedUnderline(color: underlineColor),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(text, style: style),
        ),
      ),
    );
  }
}

/// A thin dotted line along the bottom edge of the paint area.
class _DottedUnderline extends CustomPainter {
  _DottedUnderline({required this.color});

  final Color color;
  static const _stroke = 1.0;
  static const _dash = 1.0;
  static const _gap = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    final y = size.height - _stroke / 2;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(Offset(x, y), Offset(x + _dash, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DottedUnderline old) => old.color != color;
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
