// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/practice/practice.dart';
import '../../core/readiness/readiness.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/practice.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/coach_sheet.dart';
import '../../shared/widgets/fading_scroll_edges.dart';

/// A short, non-grading practice run over the weakest domain — the evidence-
/// based "do more" once the day's reviews are cleared. It presents applied
/// problems (interview questions) first for attempt + coach, and never records
/// an FSRS review, so it can't corrupt the spaced-repetition schedule.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, required this.domain});

  final String domain;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  int _index = 0;
  bool _revealed = false;

  void _next(int total) {
    setState(() {
      _revealed = false;
      _index++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncSet = ref.watch(practiceSetProvider(widget.domain));
    final set = asyncSet.asData?.value ?? const [];
    final done = set.isNotEmpty && _index >= set.length;
    final card = (!done && _index < set.length) ? set[_index] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Practice · ${prettyDomain(widget.domain)}'),
        actions: [
          if (card != null)
            CoachButton(
              onPressed: () => showCoachSheet(
                context,
                card: card,
                section: practiceAnswerSection(card),
                revealed: _revealed,
                grading: true,
              ),
            ),
        ],
        bottom: card != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                    value: _index / set.length, minHeight: 4),
              )
            : null,
      ),
      body: asyncSet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not build a practice set:\n$e',
              textAlign: TextAlign.center),
        ),
        data: (set) {
          if (set.isEmpty) return _EmptyPractice(domain: widget.domain);
          if (done) return _PracticeDone(count: set.length);
          return _PracticeCard(
            card: set[_index],
            position: _index + 1,
            total: set.length,
            revealed: _revealed,
            isLast: _index == set.length - 1,
            onReveal: () => setState(() => _revealed = true),
            onNext: () => _next(set.length),
          );
        },
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.card,
    required this.position,
    required this.total,
    required this.revealed,
    required this.isLast,
    required this.onReveal,
    required this.onNext,
  });

  final Card card;
  final int position;
  final int total;
  final bool revealed;
  final bool isLast;
  final VoidCallback onReveal;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInterview = card.type == CardType.interviewQuestion;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: [
            Expanded(
              child: FadingScrollEdges(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Text('$position / $total',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Text(card.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    // The cue: the problem statement for interview cards, else
                    // the card title alone (concept recall).
                    if (isInterview && card.overview.isNotEmpty)
                      CardMarkdown(card.overview)
                    else
                      Text('Recall what you know, then reveal to check.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    if (revealed) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      for (final section in card.sections) ...[
                        Text(section.heading,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary)),
                        const SizedBox(height: 6),
                        CardMarkdown(section.content),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            _PracticeActions(
              card: card,
              revealed: revealed,
              isLast: isLast,
              onReveal: onReveal,
              onNext: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeActions extends StatelessWidget {
  const _PracticeActions({
    required this.card,
    required this.revealed,
    required this.isLast,
    required this.onReveal,
    required this.onNext,
  });

  final Card card;
  final bool revealed;
  final bool isLast;
  final VoidCallback onReveal;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: revealed
            ? SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(isLast ? 'Finish' : 'Next'),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showCoachSheet(
                        context,
                        card: card,
                        section: practiceAnswerSection(card),
                        revealed: false,
                        grading: true,
                      ),
                      icon: const Icon(Icons.psychology_outlined),
                      label: const Text('Answer the coach'),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onReveal,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Reveal'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PracticeDone extends StatelessWidget {
  const _PracticeDone({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Nice — $count practised',
                textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Applied reps only — nothing recorded to your review schedule. '
              'If you\'d rather build something instead, that\'s time well '
              'spent too.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPractice extends StatelessWidget {
  const _EmptyPractice({required this.domain});
  final String domain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No practice material in ${prettyDomain(domain)} yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
