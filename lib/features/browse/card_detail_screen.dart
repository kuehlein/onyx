// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/card.dart';
import '../../shared/providers/vault.dart';
import '../../shared/widgets/card_markdown.dart';

/// Read-only view of a single card: its overview plus each H2 section, rendered
/// as Markdown with syntax-highlighted code. Reached from Browse; the card is
/// looked up in the live index by id (stable across filename changes).
///
/// Presentation follows the learning-science synthesis (docs/learning-science):
/// the line length is constrained (~66ch) for readability; content is chunked
/// into panels; the core teaching (scheduled/quizzable sections) is expanded by
/// default while supplementary sections are collapsed but clearly labelled.
class CardDetailScreen extends ConsumerWidget {
  const CardDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(vaultIndexProvider);

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
        return _CardDetail(card);
      },
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail(this.card);

  final Card card;

  @override
  Widget build(BuildContext context) {
    final isInterview = card.type == CardType.interviewQuestion;

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
                _SectionPanel(section: section),
            ],
          ),
        ),
      ),
    );
  }
}

/// One collapsible H2 section. Quizzable (scheduled) sections carry the core
/// teaching, so they open by default and their heading is accented; other
/// sections are supplementary and collapse to keep the card digestible.
class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.section});

  final CardSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      // Material (not a bare coloured Container) so the ExpansionTile's inner
      // ListTile has a Material ancestor to paint its background/ink onto.
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // Drop the ExpansionTile's default header/body divider lines.
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: section.quizzable,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    section.heading,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color:
                          section.quizzable ? scheme.primary : scheme.onSurface,
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
