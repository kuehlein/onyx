// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/srs/algo_queue.dart';
import '../../shared/providers/algo.dart';
import '../../shared/status_colors.dart';
import '../../shared/study_grades.dart' show gradeColor;
import '../../shared/url.dart';
import '../../shared/widgets/card_markdown.dart';
import 'explain_sheet.dart';

// Colour comes from each outcome's FSRS grade (clean=4 … failed=1) via
// [gradeColor], so these buttons share the quiz's four-colour grade scale.
const _outcomes = <({SolveOutcome outcome, String label})>[
  (outcome: SolveOutcome.clean, label: 'Solved it cleanly'),
  (outcome: SolveOutcome.hinted, label: 'Solved, needed a hint'),
  (outcome: SolveOutcome.struggled, label: 'Struggled through it'),
  (outcome: SolveOutcome.failed, label: 'Couldn’t solve it'),
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

  /// For an explain-nudged problem, the key the learner tapped "solve instead"
  /// on — so we reveal the solve controls only for that problem. Cleared
  /// implicitly when the session advances to a new key.
  String? _solveForKey;

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
          final task = s.current!;
          return _ProblemView(
            task: task,
            position: '${s.index + 1} / ${s.total}',
            note: _note,
            // In explain mode the solve controls stay hidden until asked for,
            // so the nudged mode isn't drowned out by four solve buttons.
            showSolve: task.mode == AlgoMode.solve || _solveForKey == task.key,
            onLog: _log,
            onWantSolve: () => setState(() => _solveForKey = task.key),
            onExplain: () => showExplainSheet(
              context,
              card: task.item.card,
              section: task.item.section,
            ),
          );
        },
      ),
    );
  }
}

class _ProblemView extends StatelessWidget {
  const _ProblemView({
    required this.task,
    required this.position,
    required this.note,
    required this.showSolve,
    required this.onLog,
    required this.onWantSolve,
    required this.onExplain,
  });

  final AlgoTask task;
  final String position;
  final TextEditingController note;
  final bool showSolve;
  final void Function(SolveOutcome) onLog;
  final VoidCallback onWantSolve;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = task.item;
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
                      const Spacer(),
                      _ReasonChip(task.reason, task.mode),
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
            _ActionArea(
              mode: task.mode,
              showSolve: showSolve,
              note: note,
              onLog: onLog,
              onWantSolve: onWantSolve,
              onExplain: onExplain,
            ),
          ],
        ),
      ),
    );
  }
}

/// The bottom action area. The preferred [mode] decides which path leads; the
/// other is a quiet one-line alternative — the nudge. Solve = execution clock
/// (needs a computer); explain = recognition clock (phone-doable). In explain
/// mode the four solve buttons stay hidden until [showSolve] (the learner tapped
/// "solve instead"), so the nudged mode isn't buried under them.
class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.mode,
    required this.showSolve,
    required this.note,
    required this.onLog,
    required this.onWantSolve,
    required this.onExplain,
  });

  final AlgoMode mode;
  final bool showSolve;
  final TextEditingController note;
  final void Function(SolveOutcome) onLog;
  final VoidCallback onWantSolve;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children;
    if (mode == AlgoMode.explain) {
      children = [
        _ExplainCta(prominent: true, onExplain: onExplain),
        const SizedBox(height: 10),
        if (showSolve)
          _SolveBlock(note: note, onLog: onLog)
        else
          _AltButton(
            icon: Icons.computer_outlined,
            label: 'At a computer? Solve it instead',
            onPressed: onWantSolve,
          ),
      ];
    } else {
      children = [
        _SolveBlock(note: note, onLog: onLog),
        const SizedBox(height: 4),
        _AltButton(
          icon: Icons.record_voice_over_outlined,
          label: 'Away from a computer? Explain it instead',
          onPressed: onExplain,
        ),
      ];
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// A quiet, full-width text button for the non-preferred mode.
class _AltButton extends StatelessWidget {
  const _AltButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
}

/// The solve-and-log block: an optional insight note + the four outcome
/// buttons, coloured by the FSRS grade they map to.
class _SolveBlock extends StatelessWidget {
  const _SolveBlock({
    required this.note,
    required this.onLog,
  });

  final TextEditingController note;
  final void Function(SolveOutcome) onLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
          () {
            final color = gradeColor(o.outcome.spec.grade);
            return SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => onLog(o.outcome),
                style: FilledButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  backgroundColor: color.withValues(alpha: 0.16),
                  foregroundColor: color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(o.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            );
          }(),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

/// The explain-mode call to action: the phone-doable primary on an explain-due
/// day.
class _ExplainCta extends StatelessWidget {
  const _ExplainCta({required this.prominent, required this.onExplain});

  final bool prominent; // reserved; currently always the prominent form
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Due to explain — no computer needed.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: onExplain,
          icon: const Icon(Icons.record_voice_over_outlined),
          label: const Text('Explain to the coach'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// A small color-coded chip showing why this problem surfaced today.
class _ReasonChip extends StatelessWidget {
  const _ReasonChip(this.reason, this.mode);
  final String reason;
  final AlgoMode mode;

  @override
  Widget build(BuildContext context) {
    final color = mode == AlgoMode.explain ? statusWarn : statusGood;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(reason,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
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
