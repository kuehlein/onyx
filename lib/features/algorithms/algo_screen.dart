// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/srs/review_queue.dart' show ReviewItem;
import '../../shared/providers/algo.dart';
import '../../shared/status_colors.dart';
import '../../shared/url.dart';
import '../../shared/widgets/card_markdown.dart';

const _outcomes = <({SolveOutcome outcome, String label, Color color})>[
  (outcome: SolveOutcome.clean, label: 'Solved it cleanly', color: statusGood),
  (
    outcome: SolveOutcome.hinted,
    label: 'Solved, needed a hint',
    color: statusWarn
  ),
  (
    outcome: SolveOutcome.struggled,
    label: 'Struggled through it',
    color: statusWarn
  ),
  (outcome: SolveOutcome.failed, label: 'Couldn’t solve it', color: statusBad),
];

final _urlRe = RegExp(r'https?://\S+');

/// The daily Algorithms session: work through the paced queue (due re-solves +
/// new problems). You solve each on NeetCode/LeetCode, then self-report how it
/// went — which both schedules the next re-solve (FSRS) and counts toward
/// readiness. No coding happens in the app.
class AlgoScreen extends ConsumerStatefulWidget {
  const AlgoScreen({super.key});

  @override
  ConsumerState<AlgoScreen> createState() => _AlgoScreenState();
}

class _AlgoScreenState extends ConsumerState<AlgoScreen> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _log(SolveOutcome outcome) async {
    final note = _note.text;
    _note.clear();
    await ref.read(algoSessionProvider.notifier).logSolve(outcome, note: note);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(algoSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Algorithms')),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (s) {
          if (s.total == 0) return const _Empty();
          if (s.isDone) return _Complete(done: s.done);
          return _ProblemView(
            item: s.current!.item,
            position: '${s.index + 1} / ${s.total}',
            note: _note,
            onLog: _log,
          );
        },
      ),
    );
  }
}

class _ProblemView extends StatelessWidget {
  const _ProblemView({
    required this.item,
    required this.position,
    required this.note,
    required this.onLog,
  });

  final ReviewItem item;
  final String position;
  final TextEditingController note;
  final void Function(SolveOutcome) onLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = _urlRe
        .firstMatch(item.section.content)
        ?.group(0)
        ?.replaceAll(RegExp(r'[)\].,]+$'), '');

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
                      Text(position,
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      _Pill(item.card.title), // the pattern
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(item.section.heading, // the problem
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  CardMarkdown(item.section.content),
                  if (url != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () => openExternalUrl(url),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Solve the problem'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _ActionBar(note: note, onLog: onLog),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.note, required this.onLog});

  final TextEditingController note;
  final void Function(SolveOutcome) onLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: note,
              minLines: 1,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Key insight / what tripped you (optional)',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Solve it, then log how it went:',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            for (final o in _outcomes) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => onLog(o.outcome),
                  style: FilledButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    backgroundColor: o.color.withValues(alpha: 0.16),
                    foregroundColor: o.color,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  child: Text(o.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 6),
            ],
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

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terminal_outlined,
                size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('No algorithms yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Add algorithm cards to your vault (a card per pattern, a section '
              'per problem) and they’ll show up here on a daily schedule.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Complete extends StatelessWidget {
  const _Complete({required this.done});
  final int done;

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
            Text(done == 0 ? 'All done for today' : 'Nice work',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              done == 0
                  ? 'No algorithms due right now — come back tomorrow.'
                  : '$done problem${done == 1 ? '' : 's'} logged. That counts '
                      'toward your readiness.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
