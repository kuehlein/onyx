// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/template/active_template.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/srs.dart';
import '../../shared/providers/vault.dart';
import '../../shared/url.dart';
import '../../shared/widgets/card_links.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/card_meta_chip.dart';
import '../../shared/widgets/card_section_panel.dart';
import '../../shared/widgets/coach_sheet.dart';
import '../../shared/widgets/confidence_badge.dart';
import '../../shared/widgets/fading_scroll_edges.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/log_solve_sheet.dart';
import '../editor/card_editor_screen.dart';

/// Read-only view of a single card: its overview plus each H2 section, rendered
/// as Markdown with syntax-highlighted code. Reached from Browse; the card is
/// looked up in the live index by id (stable across filename changes).
///
/// Presentation follows the learning-science synthesis (docs/learning-science):
/// line length is constrained (~66ch); content is chunked into panels. Which
/// sections open by default adapts to study state — new/due sections expand
/// (they need work), while mastered (reviewed and scheduled out) and
/// supplementary sections collapse. Composed from the shared card component layer
/// (CardMetaChip / CardSectionPanel / CardLinks — ADR-0012).
class CardDetailScreen extends ConsumerWidget {
  const CardDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(vaultIndexProvider);
    final states = ref.watch(srsStatesProvider).asData?.value;

    return index.when(
      loading: () => const Scaffold(
        body: LoadingView(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text('Index error:\n$e', textAlign: TextAlign.center),
        ),
      ),
      data: (result) {
        Card? card;
        for (final c in result.cards) {
          if (c.id == cardId) {
            card = c;
            break;
          }
        }
        if (card == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not found')),
            body: const Center(
              child: Text('This card is no longer in the vault.'),
            ),
          );
        }
        return _CardDetail(card: card, states: states);
      },
    );
  }
}

class _CardDetail extends ConsumerWidget {
  const _CardDetail({required this.card, required this.states});

  final Card card;
  final SectionStates? states;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isApproach = card.isApproachCard;
    final now = DateTime.now();
    // The card's type label + icon come from its flow (config), never a
    // `card.type ==` branch (invariant #2) — resolved from the active template,
    // matching Browse's resolution exactly.
    final flow = activeTemplate.flowForType(card.type);

    return Scaffold(
      appBar: AppBar(
        title: Text(card.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit card',
            onPressed: () async {
              final navigator = Navigator.of(context);
              final saved = await showCardEditor(context, card: card);
              // The editor already invalidated the index; this detail holds a
              // stale snapshot (and the file may have been renamed/deleted), so
              // pop back to the refreshed Browse list on save.
              if (saved && navigator.canPop()) navigator.pop();
            },
          ),
          CoachButton(
            onPressed: () => showCoachSheet(
              context,
              card: card,
              section: null,
              revealed: true,
              grading: false,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          // Cap the measure for readable line length on wide screens.
          constraints: const BoxConstraints(maxWidth: Dim.maxContentWidth),
          child: FadingScrollEdges(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Dim.space4, Dim.space3, Dim.space4, 40),
              children: [
                Wrap(
                  spacing: Dim.space2,
                  runSpacing: Dim.space1,
                  children: [
                    CardMetaChip(
                      icon: flowIcon(flow?.iconKey),
                      label: flow?.displayLabel ?? card.type,
                    ),
                    if (card.domain != null) CardMetaChip(label: card.domain!),
                    for (final entry in card.tiers.entries)
                      CardMetaChip(label: '${entry.key} · T${entry.value}'),
                    if (card.priority != Priority.normal)
                      CardMetaChip(
                        icon: card.priority == Priority.high
                            ? Icons.priority_high
                            : Icons.low_priority,
                        label: '${card.priority.value} priority',
                      ),
                    if (card.confidence != null)
                      ConfidenceBadge(card.confidence!),
                  ],
                ),
                if (card.overview.isNotEmpty) ...[
                  const SizedBox(height: Dim.space4),
                  CardMarkdown(card.overview),
                ],
                if (isApproach) ...[
                  const SizedBox(height: Dim.space4),
                  Wrap(
                    spacing: Dim.space2,
                    runSpacing: Dim.space2,
                    children: [
                      if (card.practiceUrl != null)
                        FilledButton.icon(
                          onPressed: () => openExternalUrl(card.practiceUrl!),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Solve the problem'),
                        ),
                      FilledButton.tonalIcon(
                        onPressed: () => showLogSolveSheet(context, card: card),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Log a solve'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: Dim.space4),
                for (final section in card.sections)
                  CardSectionPanel(
                    section: section,
                    initiallyExpanded: sectionExpandDefault(
                      section,
                      states?['${card.id}::${section.slug}'],
                      now,
                    ),
                  ),
                CardLinks(cardId: card.id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
