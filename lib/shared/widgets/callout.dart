import 'package:flutter/material.dart';

/// Visual spec for a callout type: an accent colour, an icon, and a default
/// title. Colours are muted so they read as semantic signals on the dark
/// surface, not decoration.
class CalloutSpec {
  const CalloutSpec(this.color, this.icon, this.label);

  final Color color;
  final IconData icon;
  final String label;
}

// Muted, dark-surface-friendly accents. A small vocabulary: colour maps to
// meaning (info/positive/attention/danger), aliases share a colour + icon.
const _info = Color(0xFF5AA7E6);
const _tip = Color(0xFF4CC38A);
const _amber = Color(0xFFE3B341);
const _red = Color(0xFFF07178);
const _violet = Color(0xFFB39DFF);
const _cyan = Color(0xFF56C7D4);

const Map<String, CalloutSpec> _specs = {
  'note': CalloutSpec(_info, Icons.edit_outlined, 'Note'),
  'info': CalloutSpec(_info, Icons.info_outline, 'Info'),
  'abstract': CalloutSpec(_cyan, Icons.notes_outlined, 'Abstract'),
  'summary': CalloutSpec(_cyan, Icons.notes_outlined, 'Summary'),
  'tldr': CalloutSpec(_cyan, Icons.notes_outlined, 'TL;DR'),
  'tip': CalloutSpec(_tip, Icons.lightbulb_outline, 'Tip'),
  'hint': CalloutSpec(_tip, Icons.lightbulb_outline, 'Hint'),
  'success': CalloutSpec(_tip, Icons.check_circle_outline, 'Success'),
  'check': CalloutSpec(_tip, Icons.check_circle_outline, 'Check'),
  'done': CalloutSpec(_tip, Icons.check_circle_outline, 'Done'),
  'important': CalloutSpec(_violet, Icons.priority_high, 'Important'),
  'key': CalloutSpec(_violet, Icons.vpn_key_outlined, 'Key insight'),
  'question': CalloutSpec(_cyan, Icons.help_outline, 'Question'),
  'help': CalloutSpec(_cyan, Icons.help_outline, 'Help'),
  'faq': CalloutSpec(_cyan, Icons.help_outline, 'FAQ'),
  'warning': CalloutSpec(_amber, Icons.warning_amber_outlined, 'Warning'),
  'caution': CalloutSpec(_amber, Icons.warning_amber_outlined, 'Caution'),
  'attention': CalloutSpec(_amber, Icons.warning_amber_outlined, 'Attention'),
  'danger': CalloutSpec(_red, Icons.dangerous_outlined, 'Danger'),
  'error': CalloutSpec(_red, Icons.error_outline, 'Error'),
  'bug': CalloutSpec(_red, Icons.bug_report_outlined, 'Bug'),
  'failure': CalloutSpec(_red, Icons.close, 'Failure'),
  'example': CalloutSpec(_violet, Icons.list_alt_outlined, 'Example'),
  'quote': CalloutSpec(_info, Icons.format_quote_outlined, 'Quote'),
};

/// Look up a callout's spec, or null for an unrecognised type (the widget then
/// falls back to the theme accent and a title-cased type name).
CalloutSpec? calloutSpecFor(String type) => _specs[type.toLowerCase()];

/// An Obsidian-style callout: a tinted panel with a left accent rail, an icon,
/// a title, and (optionally) a body. One semantic accent per type — signaling,
/// not decoration.
class Callout extends StatelessWidget {
  const Callout({
    super.key,
    required this.type,
    this.title,
    this.body,
  });

  final String type;
  final String? title;

  /// Rendered callout body (already-built markdown), or null for a title-only
  /// callout.
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spec = calloutSpecFor(type);
    final color = spec?.color ?? scheme.primary;
    final icon = spec?.icon ?? Icons.info_outline;
    final label =
        title?.isNotEmpty == true ? title! : (spec?.label ?? _titleCase(type));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 6),
                      body!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}
