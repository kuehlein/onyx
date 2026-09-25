// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;

import '../../core/database/database.dart';
import '../design/onyx_design.dart';
import '../models/card.dart';
import 'card_markdown.dart';

/// Whether a section should open by default: supplementary sections stay
/// collapsed; a quizzable section opens if it's new (never studied) or due, and
/// collapses once it's been reviewed and scheduled into the future (mastered).
///
/// The single home for the card view's section expand policy (was
/// `card_detail._expandByDefault`). The retention-threshold-based "mastered"
/// collapse + badge is a later, ADR-backed refinement (1f.1); today this proxies
/// mastery on the due date.
bool sectionExpandDefault(CardSection section, SrsState? state, DateTime now) {
  if (section.quizzable) {
    if (state == null) return true;
    return !state.dueAt.isAfter(now);
  }
  // Non-quizzable: expand the implementation/code reference (the reason to open
  // the full card); keep other supplementary sections (resources, related)
  // collapsed.
  return implementationHeadings.contains(section.heading.trim().toLowerCase());
}

/// One collapsible H2 section — the single card-section renderer, shared across
/// the card view and (later) the study screens (ADR-0012). Whether it opens by
/// default is decided by the caller (see [sectionExpandDefault]); quizzable
/// headings are accented and flagged as study units either way.
class CardSectionPanel extends StatelessWidget {
  const CardSectionPanel(
      {super.key, required this.section, required this.initiallyExpanded});

  final CardSection section;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // A left accent rail plus a hairline border give each section a distinct
    // "region" (Gestalt common-region) without noisy dividers. The rail also
    // signals importance: primary for core/quizzable sections, muted otherwise.
    final accent = section.quizzable ? scheme.primary : scheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: Dim.space4),
      // Material (not a bare colored Container) so the ExpansionTile's inner
      // ListTile has a Material ancestor to paint its background/ink onto.
      child: Material(
        color: scheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Dim.brCard,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        // IntrinsicHeight so the accent rail can stretch to the panel's height
        // (a Row in a ListView is otherwise vertically unbounded).
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Theme(
                  // Drop the ExpansionTile's default header/body divider lines.
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: initiallyExpanded,
                    tilePadding: const EdgeInsets.fromLTRB(
                        Dim.space4, Dim.space1, Dim.space4, Dim.space1),
                    childrenPadding: const EdgeInsets.fromLTRB(
                        Dim.space4, 0, Dim.space4, Dim.space4),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            section.heading,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: section.quizzable
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        if (section.quizzable)
                          Tooltip(
                            message: 'Scheduled for review',
                            child: Icon(Icons.check_circle_outline,
                                size: Dim.iconMd, color: scheme.primary),
                          ),
                      ],
                    ),
                    children: [CardMarkdown(section.content)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
