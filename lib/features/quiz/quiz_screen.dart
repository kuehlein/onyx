// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/srs/review_queue.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/backup.dart';
import '../../shared/providers/coach.dart';
import '../../shared/providers/srs.dart';
import '../../shared/study_grades.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/coach_sheet.dart';
import '../../shared/widgets/fading_scroll_edges.dart';

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
    ref.read(backupProvider.notifier).schedule();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(studySessionProvider);
    final s = session.asData?.value;
    final showProgress = s != null && !s.isDone && s.total > 0;

    final current = (s != null && !s.isDone) ? s.current : null;
    // Keep the app-bar Coach button available throughout, matching Browse and
    // Learn. Before reveal the prominent "Answer the coach" action is the main
    // entry; this stays as the consistent secondary one (and the debrief entry
    // after reveal).
    final canCoach = current != null;
    // The coach's latest advisory grade for this section (only once revealed).
    final suggestedGrade = (current != null && _revealed)
        ? ref
            .watch(coachProvider(current.card.id, current.section.slug))
            .asData
            ?.value
            .suggestedGrade
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study'),
        actions: [
          if (canCoach)
            CoachButton(
              onPressed: () => showCoachSheet(
                context,
                card: current.card,
                section: current.section,
                revealed: _revealed,
                grading: true,
              ),
            ),
        ],
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
            suggestedGrade: suggestedGrade,
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
    required this.suggestedGrade,
    required this.onReveal,
    required this.onGrade,
  });

  final ReviewItem item;
  final int position;
  final int total;
  final bool revealed;
  final int? suggestedGrade;
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
              child: FadingScrollEdges(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Row(
                      children: [
                        Text('$position / $total',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
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
                            ? 'Recall your approach — talk it through with the '
                                'coach, or reveal.'
                            : 'Recall it — talk it through with the coach, or '
                                'reveal.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
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
            ),
            _ActionBar(
              revealed: revealed,
              suggestedGrade: suggestedGrade,
              onAnswerCoach: () => showCoachSheet(
                context,
                card: item.card,
                section: item.section,
                revealed: false,
                grading: true,
              ),
              onReveal: onReveal,
              onGrade: onGrade,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar. Before reveal: "Answer the coach" (the mock-interview path) over
/// a quieter "Reveal". After reveal: four grade buttons — when the coach has
/// offered an advisory grade, that button gets an outline (a nudge, not a
/// decision; the learner still taps).
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.revealed,
    required this.suggestedGrade,
    required this.onAnswerCoach,
    required this.onReveal,
    required this.onGrade,
  });

  final bool revealed;
  final int? suggestedGrade;
  final VoidCallback onAnswerCoach;
  final VoidCallback onReveal;
  final void Function(int grade) onGrade;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: revealed
            ? Row(
                children: [
                  for (final (:value, :label, :color) in studyGrades) ...[
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onGrade(value),
                        style: FilledButton.styleFrom(
                          backgroundColor: color.withValues(alpha: 0.18),
                          foregroundColor: color,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: suggestedGrade == value
                              ? BorderSide(color: color, width: 2)
                              : null,
                        ),
                        child: Text(label),
                      ),
                    ),
                    if (value != 4) const SizedBox(width: 8),
                  ],
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onAnswerCoach,
                      icon: const Icon(Icons.psychology_outlined),
                      label: const Text('Answer the coach'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
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
                ref.read(backupProvider.notifier).flush();
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
