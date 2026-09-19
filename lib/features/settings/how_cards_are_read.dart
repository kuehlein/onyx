import 'package:flutter/material.dart';

import '../../core/vault/card_parser.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/widgets/sheet_header.dart';

/// A read-only explainer of how Onyx turns notes into cards — the ship-now stub
/// for configurable parsing (docs/settings-ux.md §4). The **Now** rows are live
/// parser facts ([cardParsingRules], derived from the parser, not restated here);
/// the **Later** rows are an inert preview of the future per-folder parse profile
/// so the row isn't a dead end — they're not controls. Opened from
/// Settings → Card parsing. Mirrors [showStudyLoadHelp]'s explainer scaffold.
Future<void> showHowCardsAreReadSheet(BuildContext context) {
  return showOnyxSheet<void>(context, builder: (_) => const _HowCardsAreRead());
}

/// The future parse-profile options (docs/settings-ux.md §4), shown inert. Labels
/// are the final ones; [editor] marks the row whose future form opens an editor
/// (the dim trailing chevron).
const _later = <({String label, bool editor})>[
  (label: '--- rule', editor: false),
  (label: 'Headings (H3)', editor: false),
  (label: 'Custom start/end markers', editor: false),
  (label: 'More file types (.txt, .org)', editor: false),
  (label: 'Custom rule (advanced)', editor: true),
];

class _HowCardsAreRead extends StatelessWidget {
  const _HowCardsAreRead();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHeader(title: 'How cards are read', divider: true),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, Dim.space3, 20, 28),
            shrinkWrap: true,
            children: [
              Text(
                'Onyx turns your notes into cards using these rules. They’re the '
                'same for every folder for now — per-folder rules are coming.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 20),
              const _SectionLabel('Now'),
              for (final r in cardParsingRules) _NowRow(r.label, r.value),
              const SizedBox(height: 20),
              const _SectionLabel('Later', tagged: true),
              for (final l in _later) _LaterRow(l.label, editor: l.editor),
              const SizedBox(height: Dim.space4),
              Text(
                'Sensible defaults mean most folders never need to change these.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small uppercase group label. [tagged] adds one section-level "Later" pill
/// (calm restraint — not a badge per row).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.tagged = false});
  final String text;
  final bool tagged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Dim.space1),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6),
          ),
          if (tagged) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Dim.space2, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: Dim.brFull,
              ),
              child: Text('Later',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ],
        ],
      ),
    );
  }
}

/// A live parsing fact: filled marker, label, and the derived value.
class _NowRow extends StatelessWidget {
  const _NowRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dim.space2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: Dim.space3),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// An inert preview of a future option — hollow marker, muted label, no tap/
/// ripple. [editor] adds a dim trailing chevron (its future form opens an
/// editor). Announced to screen readers as "…, not yet available".
class _LaterRow extends StatelessWidget {
  const _LaterRow(this.label, {required this.editor});
  final String label;
  final bool editor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: '$label, not yet available',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Dim.space2),
        child: Row(
          children: [
            Icon(Icons.circle_outlined, size: 12, color: dim),
            const SizedBox(width: 14),
            Expanded(
                child: Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(color: dim))),
            if (editor) Icon(Icons.chevron_right, size: 18, color: dim),
          ],
        ),
      ),
    );
  }
}
