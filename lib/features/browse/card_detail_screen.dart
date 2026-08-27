// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/srs.dart';
import '../../shared/providers/vault.dart';
import '../../shared/widgets/card_markdown.dart';

/// Read-only view of a single card: its overview plus each H2 section, rendered
/// as Markdown with syntax-highlighted code. Reached from Browse; the card is
/// looked up in the live index by id (stable across filename changes).
///
/// Presentation follows the learning-science synthesis (docs/learning-science):
/// line length is constrained (~66ch); content is chunked into panels. Which
/// sections open by default adapts to study state — new/due sections expand
/// (they need work), while mastered (reviewed and scheduled out) and
/// supplementary sections collapse.
class CardDetailScreen extends ConsumerWidget {
  const CardDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(vaultIndexProvider);
    final states = ref.watch(srsStatesProvider).asData?.value;

    return index.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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

/// Whether a section should open by default: supplementary sections stay
/// collapsed; a quizzable section opens if it's new (never studied) or due, and
/// collapses once it's been reviewed and scheduled into the future (mastered).
bool _expandByDefault(CardSection section, SrsState? state, DateTime now) {
  if (!section.quizzable) return false;
  if (state == null) return true;
  return !state.dueAt.isAfter(now);
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.card, required this.states});

  final Card card;
  final SectionStates? states;

  @override
  Widget build(BuildContext context) {
    final isInterview = card.type == CardType.interviewQuestion;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(card.title)),
      body: Center(
        child: ConstrainedBox(
          // Cap the measure for readable line length on wide screens.
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _MetaChip(
                    icon: isInterview
                        ? Icons.forum_outlined
                        : Icons.style_outlined,
                    label: isInterview ? 'Interview question' : 'Flashcard',
                  ),
                  if (card.domain != null) _MetaChip(label: card.domain!),
                  for (final entry in card.tiers.entries)
                    _MetaChip(label: '${entry.key} · T${entry.value}'),
                ],
              ),
              if (card.overview.isNotEmpty) ...[
                const SizedBox(height: 16),
                CardMarkdown(card.overview),
              ],
              const SizedBox(height: 16),
              for (final section in card.sections)
                _SectionPanel(
                  section: section,
                  initiallyExpanded: _expandByDefault(
                    section,
                    states?['${card.id}::${section.slug}'],
                    now,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One collapsible H2 section. Whether it opens by default is decided by the
/// caller from study state; quizzable headings are accented either way.
class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.section, required this.initiallyExpanded});

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
      padding: const EdgeInsets.only(bottom: 14),
      // Material (not a bare coloured Container) so the ExpansionTile's inner
      // ListTile has a Material ancestor to paint its background/ink onto.
      child: Material(
        color: scheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
                    tilePadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
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
                                size: 18, color: scheme.primary),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
