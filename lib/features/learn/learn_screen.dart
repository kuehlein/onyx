// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/srs/learn_queue.dart';
import '../../shared/providers/backup.dart';
import '../../shared/providers/learn.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/fading_scroll_edges.dart';

/// Learn mode: first exposure to never-studied sections, grouped by family.
/// Conditional sections use a guess-then-reveal attempt; declarative sections
/// are read. Good/Easy graduates a section into the FSRS review schedule; lower
/// grades re-queue it. Nothing here writes a review-log row.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  bool _attempted = false;

  void _grade(int grade) {
    setState(() => _attempted = false);
    ref.read(learnSessionProvider.notifier).grade(grade);
    ref.read(backupProvider.notifier).schedule();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(learnSessionProvider);
    final s = session.asData?.value;
    final showProgress = s != null && !s.isDone && s.total > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
        bottom: showProgress
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: s.graduated / s.total,
                  minHeight: 4,
                ),
              )
            : null,
      ),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not start learning:\n$e',
              textAlign: TextAlign.center),
        ),
        data: (s) {
          if (s.total == 0) return const _EmptyState();
          if (s.isDone) return _CompleteState(learned: s.graduated);
          return _LearnView(
            item: s.current!,
            graduated: s.graduated,
            total: s.total,
            attempted: _attempted,
            onReveal: () => setState(() => _attempted = true),
            onGrade: _grade,
          );
        },
      ),
    );
  }
}

class _LearnView extends StatelessWidget {
  const _LearnView({
    required this.item,
    required this.graduated,
    required this.total,
    required this.attempted,
    required this.onReveal,
    required this.onGrade,
  });

  final LearnItem item;
  final int graduated;
  final int total;
  final bool attempted;
  final VoidCallback onReveal;
  final void Function(int grade) onGrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section = item.section;
    final pretest = isPretestSection(section.heading);
    // Read sections show content immediately; pretest sections wait for a guess.
    final revealed = attempted || !pretest;

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
                        Text('${graduated + 1} / $total',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        _Pill(pretest ? 'Learn · recall' : 'Learn · study'),
                        if (item.card.domain != null) ...[
                          const SizedBox(width: 8),
                          _Pill(item.card.domain!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(item.card.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(section.heading,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.primary)),
                    if (!revealed) ...[
                      const SizedBox(height: 20),
                      Text(
                        'New to you. Take a guess at what this covers, then reveal.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (revealed) ...[
                      const SizedBox(height: 12),
                      CardMarkdown(section.content),
                    ],
                  ],
                ),
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

/// Reveal before attempting; after, a grade bar. Again/Hard re-study this
/// session; Good/Easy graduate the section into review.
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: revealed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Good or Easy adds it to your review schedule.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Row(
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
                  ),
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
            Icon(Icons.auto_stories_outlined,
                size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('No new material', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text("You've started every card. Keep reviewing to lock it in.",
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
  const _CompleteState({required this.learned});
  final int learned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined,
                size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Nice work', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
                '$learned section${learned == 1 ? '' : 's'} added to your review schedule',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ref.read(backupProvider.notifier).flush();
                ref.invalidate(learnQueueProvider);
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
