// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/srs/review_queue.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/srs.dart';
import '../../shared/widgets/card_markdown.dart';

/// Study session: recall → reveal → self-grade, one section at a time.
/// Interview-question cards lead with the problem statement as the cue; concept
/// cards use the section heading. Grading runs FSRS and advances.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  bool _revealed = false;

  void _grade(int grade) {
    setState(() => _revealed = false);
    ref.read(studySessionProvider.notifier).grade(grade);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(studySessionProvider);
    final s = session.asData?.value;
    final showProgress = s != null && !s.isDone && s.total > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study'),
        bottom: showProgress
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: s.index / s.total,
                  minHeight: 4,
                ),
              )
            : null,
      ),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not build a session:\n$e',
              textAlign: TextAlign.center),
        ),
        data: (s) {
          if (s.total == 0) return const _EmptyState();
          if (s.isDone) return _CompleteState(reviewed: s.total);
          return _ReviewView(
            item: s.current!,
            position: s.index + 1,
            total: s.total,
            revealed: _revealed,
            onReveal: () => setState(() => _revealed = true),
            onGrade: _grade,
          );
        },
      ),
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.item,
    required this.position,
    required this.total,
    required this.revealed,
    required this.onReveal,
    required this.onGrade,
  });

  final ReviewItem item;
  final int position;
  final int total;
  final bool revealed;
  final VoidCallback onReveal;
  final void Function(int grade) onGrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = item.card;
    final isInterview = card.type == CardType.interviewQuestion;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Row(
                    children: [
                      Text('$position / $total',
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      if (item.isNew) const _Pill('New'),
                      if (card.domain != null) ...[
                        const SizedBox(width: 8),
                        _Pill(card.domain!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(card.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  // The cue: problem statement for interview cards, else the
                  // section heading you're recalling.
                  if (isInterview && card.overview.isNotEmpty)
                    CardMarkdown(card.overview)
                  else
                    Text(item.section.heading,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.primary)),
                  if (!revealed) ...[
                    const SizedBox(height: 20),
                    Text(
                      isInterview
                          ? 'Recall your approach, then reveal.'
                          : 'Recall it, then reveal.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  if (revealed) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (isInterview)
                      Text(item.section.heading,
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary)),
                    if (isInterview) const SizedBox(height: 6),
                    CardMarkdown(item.section.content),
                  ],
                ],
              ),
            ),
            _ActionBar(
              revealed: revealed,
              onReveal: onReveal,
              onGrade: onGrade,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar: a Reveal button before, four grade buttons after.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.revealed,
    required this.onReveal,
    required this.onGrade,
  });

  final bool revealed;
  final VoidCallback onReveal;
  final void Function(int grade) onGrade;

  static const _grades = [
    (1, 'Again', Color(0xFFF07178)),
    (2, 'Hard', Color(0xFFE3B341)),
    (3, 'Good', Color(0xFF4CC38A)),
    (4, 'Easy', Color(0xFF5AA7E6)),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: revealed
            ? Row(
                children: [
                  for (final (grade, label, color) in _grades) ...[
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onGrade(grade),
                        style: FilledButton.styleFrom(
                          backgroundColor: color.withValues(alpha: 0.18),
                          foregroundColor: color,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(label),
                      ),
                    ),
                    if (grade != 4) const SizedBox(width: 8),
                  ],
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onReveal,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Reveal'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.onSecondaryContainer)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Nothing due right now', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('New cards and reviews will appear here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _CompleteState extends ConsumerWidget {
  const _CompleteState({required this.reviewed});
  final int reviewed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration_outlined,
                size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Session complete', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('$reviewed section${reviewed == 1 ? '' : 's'} reviewed',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                // Fresh queue next time (reflecting the reviews just recorded).
                ref.invalidate(reviewQueueProvider);
                context.go('/');
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
