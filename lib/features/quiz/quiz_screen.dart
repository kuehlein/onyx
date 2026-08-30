// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/readiness/readiness.dart';
import '../../core/srs/review_queue.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/backup.dart';
import '../../shared/providers/coach.dart';
import '../../shared/providers/practice.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/srs.dart';
import '../../shared/study_grades.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/coach_sheet.dart';
import '../../shared/widgets/confidence_badge.dart';
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
          if (s.isDone) return _CompleteState(session: s);
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
                        if (card.confidence != null) ...[
                          const SizedBox(width: 8),
                          ConfidenceBadge(card.confidence!),
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

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final weakest = ref.watch(readinessProvider).asData?.value.weakestDomain;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
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
              if (weakest != null) ...[
                const SizedBox(height: 24),
                _PracticeSuggestion(weakest),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The evidence-based "do more" offer: a small, non-grading practice set on the
/// weakest domain. Renders nothing when that domain has no practice material.
/// Applied practice (not re-drilling due cards) is the higher-leverage use of
/// extra time — and the copy is honest that going to build something is fine too.
class _PracticeSuggestion extends ConsumerWidget {
  const _PracticeSuggestion(this.domain);

  final String domain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final set =
        ref.watch(practiceSetProvider(domain)).asData?.value ?? const [];
    if (set.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final n = set.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Want to keep going?',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/practice/$domain'),
          icon: const Icon(Icons.fitness_center_outlined),
          label: Text(
              'Practice ${prettyDomain(domain)} · $n problem${n == 1 ? '' : 's'}'),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ],
    );
  }
}

/// Session summary: honest, calm feedback — how many sections were reviewed,
/// the grade mix, and the real movement toward the user's goal (per-subject and
/// overall). Deliberately no XP/points/celebration hype: it reports information
/// that supports competence, it doesn't manufacture a reward (see the
/// gamification research — extrinsic rewards can crowd out intrinsic motivation
/// for a motivated learner).
class _CompleteState extends ConsumerWidget {
  const _CompleteState({required this.session});
  final SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviewed = session.total;

    final before = session.readinessBefore;
    final after = ref.watch(readinessProvider).asData?.value;
    final target = ref.watch(readinessTargetControllerProvider).asData?.value;
    final delta =
        (before != null && after != null) ? diffReadiness(before, after) : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(28),
          children: [
            Icon(Icons.check_circle_outline,
                size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Session complete',
                textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('$reviewed section${reviewed == 1 ? '' : 's'} reviewed',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (session.grades.isNotEmpty) ...[
              const SizedBox(height: 14),
              _GradeBreakdown(session.grades),
            ],
            if (delta != null) ...[
              const SizedBox(height: 24),
              _ProgressDelta(delta: delta, targetLabel: target?.label),
            ],
            if (after?.weakestDomain != null) ...[
              const SizedBox(height: 24),
              _PracticeSuggestion(after!.weakestDomain!),
            ],
            const SizedBox(height: 28),
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

/// The grade mix for the session — plain counts, coloured by grade. Honest
/// session info, not a score to chase.
class _GradeBreakdown extends StatelessWidget {
  const _GradeBreakdown(this.grades);
  final List<int> grades;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (:value, :label, :color) in studyGrades)
          if (grades.where((g) => g == value).length case final n when n > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$label $n',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w600)),
            ),
      ],
    );
  }
}

/// The honest progress readout: overall movement + which subjects moved, framed
/// as knowledge-base (recall) progress toward the user's own goal.
class _ProgressDelta extends StatelessWidget {
  const _ProgressDelta({required this.delta, required this.targetLabel});

  final ReadinessDelta delta;
  final String? targetLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final touched = delta.touched;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  targetLabel == null
                      ? 'Progress toward your goal'
                      : 'Progress toward $targetLabel',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DeltaLine(label: 'Overall', change: delta.overallChange, bold: true),
          for (final d in touched)
            _DeltaLine(label: prettyDomain(d.domain), change: d.change),
          const SizedBox(height: 8),
          Text(
            'Recall strength toward your knowledge-base level — not a '
            'mock-validated interview score.',
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _DeltaLine extends StatelessWidget {
  const _DeltaLine(
      {required this.label, required this.change, this.bold = false});

  final String label;
  final double change;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = change * 100;
    final steady = p.abs() < 0.05;
    const green = Color(0xFF4CC38A);
    const amber = Color(0xFFE3B341);
    final color =
        steady ? theme.colorScheme.onSurfaceVariant : (p > 0 ? green : amber);
    final text = steady
        ? 'steady'
        : '${p > 0 ? '+' : '−'}${p.abs().toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          ),
          if (!steady)
            Icon(p > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                size: 13, color: color),
          const SizedBox(width: 2),
          Text(text,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
