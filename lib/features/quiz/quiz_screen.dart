// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import '../../shared/widgets/loading_view.dart';
import '../../shared/design/onyx_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/readiness/readiness.dart';
import '../../core/srs/review_queue.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/backup.dart';
import '../../shared/url.dart';
import '../../shared/providers/coach.dart';
import '../../shared/providers/learn.dart';
import '../../shared/providers/practice.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/settings.dart';
import '../../shared/providers/srs.dart';
import '../../shared/study_grades.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/grade_buttons.dart';
import '../../shared/widgets/coach_sheet.dart';
import '../../shared/widgets/confidence_badge.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/fading_scroll_edges.dart';
import 'rest_timer.dart';

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
    // Gym mode: a rest timer, and the coach hidden — reviews are recall-only
    // during a workout (research-backed); interview practice happens at the desk.
    final gym = ref.watch(gymModeProvider).asData?.value;
    final gymOn = gym?.enabled ?? false;
    // Keep the app-bar Coach button available throughout, matching Browse and
    // Learn. Before reveal the prominent "Answer the coach" action is the main
    // entry; this stays as the consistent secondary one (and the debrief entry
    // after reveal). Hidden in gym mode.
    final canCoach = current != null && !gymOn;
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
        title: const Text('Review'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
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
        loading: () => const LoadingView(),
        error: (e, _) => Center(
          child: Text('Could not build a session:\n$e',
              textAlign: TextAlign.center),
        ),
        data: (s) {
          if (s.total == 0) return const _EmptyState();
          if (s.isDone) return _CompleteState(session: s);
          final review = _ReviewView(
            item: s.current!,
            position: s.index + 1,
            total: s.total,
            revealed: _revealed,
            suggestedGrade: suggestedGrade,
            coachEnabled: !gymOn,
            onReveal: () => setState(() => _revealed = true),
            onGrade: _grade,
          );
          if (!gymOn) return review;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Dim.space4, Dim.space2, Dim.space4, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RestTimer(restSeconds: gym!.restSeconds),
                ),
              ),
              Expanded(child: review),
            ],
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
    this.coachEnabled = true,
  });

  final ReviewItem item;
  final int position;
  final int total;
  final bool revealed;
  final int? suggestedGrade;
  final VoidCallback onReveal;
  final void Function(int grade) onGrade;

  /// False in gym mode — reviews are recall-only (no coach).
  final bool coachEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = item.card;
    final isInterview = card.type == kTypeInterviewQuestion;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Dim.maxContentWidth),
        child: Column(
          children: [
            Expanded(
              child: FadingScrollEdges(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Dim.space4, Dim.space4, Dim.space4, Dim.space5),
                  children: [
                    Row(
                      children: [
                        Text('$position / $total',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        if (card.domain != null) ...[
                          const SizedBox(width: Dim.space2),
                          _Pill(card.domain!),
                        ],
                        if (card.confidence != null) ...[
                          const SizedBox(width: Dim.space2),
                          ConfidenceBadge(card.confidence!),
                        ],
                      ],
                    ),
                    const SizedBox(height: Dim.space3),
                    Text(card.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: Dim.space3),
                    // The cue: problem statement for interview cards, else the
                    // section heading you're recalling.
                    if (isInterview && card.overview.isNotEmpty)
                      CardMarkdown(card.overview)
                    else
                      Text(item.section.heading,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: theme.colorScheme.primary)),
                    if (!revealed) ...[
                      const SizedBox(height: Dim.space5),
                      Text(
                        !coachEnabled
                            ? (isInterview
                                ? 'Recall your approach, then reveal to check.'
                                : 'Recall it, then reveal to check.')
                            : isInterview
                                ? 'Recall your approach — talk it through with '
                                    'the coach, or reveal.'
                                : 'Recall it — talk it through with the coach, '
                                    'or reveal.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (revealed) ...[
                      const SizedBox(height: Dim.space4),
                      const Divider(),
                      const SizedBox(height: Dim.space2),
                      if (isInterview)
                        Text(item.section.heading,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary)),
                      if (isInterview) const SizedBox(height: Dim.space2),
                      CardMarkdown(item.section.content),
                      if (isInterview && card.practiceUrl != null) ...[
                        const SizedBox(height: Dim.space3),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => openExternalUrl(card.practiceUrl!),
                            icon:
                                const Icon(Icons.open_in_new, size: Dim.iconMd),
                            label: const Text('Solve the problem'),
                          ),
                        ),
                      ],
                      // Reference sections (e.g. the implementation) aren't
                      // quizzed — reach them here without leaving the flow.
                      if (card.sections.any((s) => !s.quizzable))
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => context.push('/card/${card.id}'),
                            icon: const Icon(Icons.article_outlined,
                                size: Dim.iconMd),
                            label: const Text('View full card'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            _ActionBar(
              revealed: revealed,
              suggestedGrade: suggestedGrade,
              showCoach: coachEnabled,
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
    required this.showCoach,
    required this.onAnswerCoach,
    required this.onReveal,
    required this.onGrade,
  });

  final bool revealed;
  final int? suggestedGrade;
  final bool showCoach;
  final VoidCallback onAnswerCoach;
  final VoidCallback onReveal;
  final void Function(int grade) onGrade;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Dim.space4, Dim.space2, Dim.space4, Dim.space3),
        child: revealed
            ? GradeButtons(
                buttons: [
                  for (final (:value, :label, :color) in studyGrades)
                    GradeButton(
                      label: label,
                      color: color,
                      onTap: () => onGrade(value),
                      highlighted: suggestedGrade == value,
                    ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showCoach) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onAnswerCoach,
                        icon: const Icon(Icons.psychology_outlined),
                        label: const Text('Answer the coach'),
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: Dim.space4),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dim.space2),
                  ],
                  SizedBox(
                    width: double.infinity,
                    // In gym mode (no coach) Reveal is the primary action.
                    child: showCoach
                        ? OutlinedButton.icon(
                            onPressed: onReveal,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Reveal'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: Dim.space4),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: onReveal,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Reveal'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: Dim.space4),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A calm neutral meta chip (the card's domain). Composes [StatusPill] so it
/// shares the one status-surface shape; muted tone since it carries no
/// good/attention/bad meaning.
class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => StatusPill(
        tone: StatusTone.muted,
        label: label,
        dense: true,
      );
}

/// The "no review session" state, which is context-aware:
///  - nothing studied yet → there's nothing to test on; point to Learn;
///  - studied before but nothing due → caught up for today, offer extra practice.
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(reviewQueueProvider).asData?.value;
    final hasProgress = review?.statesByKey.isNotEmpty ?? false;
    final newCount = ref.watch(learnQueueProvider).asData?.value.length ?? 0;
    final weakest = ref.watch(readinessProvider).asData?.value.weakestDomain;

    // Nothing studied yet → you can't be tested on material you haven't learned.
    if (!hasProgress) {
      return EmptyState(
        icon: Icons.auto_stories_outlined,
        title: 'Nothing to test yet',
        message: newCount > 0
            ? 'Learn some material first — once you\'ve studied a card it '
                'comes back here for review.'
            : 'Add a vault in Settings, then learn some cards to begin.',
        action: newCount > 0
            ? FilledButton.icon(
                onPressed: () => context.go('/learn'),
                icon: const Icon(Icons.auto_stories_outlined),
                label:
                    Text('Learn $newCount new card${newCount == 1 ? '' : 's'}'),
              )
            : null,
      );
    }

    // Studied before, nothing due now → caught up for today; offer extra work.
    final hasWeakest = weakest != null;
    final hasNew = newCount > 0;
    return EmptyState(
      icon: Icons.check_circle_outline,
      title: 'Caught up for today',
      message: newCount > 0
          ? 'No reviews due. $newCount new card${newCount == 1 ? '' : 's'} '
              'waiting in Learn whenever you want them.'
          : 'No reviews due right now — they\'ll reappear as they come up.',
      action: (hasWeakest || hasNew)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasWeakest) _PracticeSuggestion(weakest),
                if (hasNew) ...[
                  if (hasWeakest) const SizedBox(height: Dim.space3),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/learn'),
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: Text('Learn $newCount new'),
                  ),
                ],
              ],
            )
          : null,
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
        const SizedBox(height: Dim.space2),
        OutlinedButton.icon(
          onPressed: () => context.push('/practice/$domain'),
          icon: const Icon(Icons.fitness_center_outlined),
          label: Text(
              'Practice ${prettyDomain(domain)} · $n problem${n == 1 ? '' : 's'}'),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: Dim.space4)),
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
    final target = ref.watch(activeTargetProvider).asData?.value;
    final delta =
        (before != null && after != null) ? diffReadiness(before, after) : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Dim.maxCompactWidth),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(Dim.space6),
          children: [
            Icon(Icons.check_circle_outline,
                size: Dim.iconLg, color: theme.colorScheme.primary),
            const SizedBox(height: Dim.space3),
            Text('Session complete',
                textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: Dim.space2),
            Text('$reviewed section${reviewed == 1 ? '' : 's'} reviewed',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (session.grades.isNotEmpty) ...[
              const SizedBox(height: Dim.space4),
              _GradeBreakdown(session.grades),
            ],
            if (delta != null) ...[
              const SizedBox(height: Dim.space5),
              _ProgressDelta(delta: delta, targetLabel: target?.label),
            ],
            if (after?.weakestDomain != null) ...[
              const SizedBox(height: Dim.space5),
              _PracticeSuggestion(after!.weakestDomain!),
            ],
            const SizedBox(height: Dim.space6),
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

/// The grade mix for the session — plain counts, colored by grade. Honest
/// session info, not a score to chase.
class _GradeBreakdown extends StatelessWidget {
  const _GradeBreakdown(this.grades);
  final List<int> grades;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Dim.space2,
      runSpacing: Dim.space2,
      children: [
        for (final (:value, :label, :color) in studyGrades)
          if (grades.where((g) => g == value).length case final n when n > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Dim.space3, vertical: Dim.space1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: Dim.fill),
                borderRadius: Dim.brChip,
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
      padding: const EdgeInsets.fromLTRB(
          Dim.space4, Dim.space4, Dim.space4, Dim.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: Dim.brCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up,
                  size: Dim.iconSm, color: theme.colorScheme.primary),
              const SizedBox(width: Dim.space2),
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
          const SizedBox(height: Dim.space3),
          _DeltaLine(label: 'Overall', change: delta.overallChange, bold: true),
          for (final d in touched)
            _DeltaLine(label: prettyDomain(d.domain), change: d.change),
          const SizedBox(height: Dim.space2),
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
    const green = StatusColor.good;
    const amber = StatusColor.warn;
    final color =
        steady ? theme.colorScheme.onSurfaceVariant : (p > 0 ? green : amber);
    final text = steady
        ? 'steady'
        : '${p > 0 ? '+' : '−'}${p.abs().toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dim.space1),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          ),
          if (!steady)
            Icon(p > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                size: Dim.iconSm, color: color),
          const SizedBox(width: Dim.space1),
          Text(text,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
