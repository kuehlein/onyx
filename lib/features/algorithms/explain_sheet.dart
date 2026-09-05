// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/coach_update_chat.dart' show CoachRole;
import '../../core/ai/explain_coach.dart';
import '../../core/srs/recognition.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/algo.dart';
import '../../shared/providers/explain_chat.dart';
import '../../shared/status_colors.dart';
import '../../shared/widgets/chat_view.dart';

/// Opens the explain-mode interviewer for one problem: talk through approach,
/// complexity, and edge cases (no coding), then self-grade recognition. Grading
/// advances the session's recognition clock only.
Future<void> showExplainSheet(
  BuildContext context, {
  required Card card,
  required CardSection section,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => _ExplainSheet(card: card, section: section),
  );
}

const _grades = <({ExplainOutcome outcome, String label, Color color})>[
  (outcome: ExplainOutcome.solid, label: 'Solid', color: statusGood),
  (outcome: ExplainOutcome.shaky, label: 'Shaky', color: statusWarn),
  (outcome: ExplainOutcome.lost, label: 'Lost it', color: statusBad),
];

class _ExplainSheet extends ConsumerWidget {
  const _ExplainSheet({required this.card, required this.section});

  final Card card;
  final CardSection section;

  String get _key => '${card.id}::${section.slug}';

  Future<void> _grade(
      BuildContext context, WidgetRef ref, ExplainOutcome o) async {
    await ref.read(algoSessionProvider.notifier).logExplain(o);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(explainChatProvider(_key));
    final hasKey = ref.watch(claudeServiceProvider) != null;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final suggested = switch (state.suggestion) {
      RecognitionSuggestion.solid => ExplainOutcome.solid,
      RecognitionSuggestion.shaky => ExplainOutcome.shaky,
      RecognitionSuggestion.lost => ExplainOutcome.lost,
      null => null,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.record_voice_over_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Explain — ${section.heading}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium),
                        Text(card.title,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: !hasKey
                  ? const _NoKey()
                  : ChatView(
                      messages: [
                        for (final m in state.messages)
                          ChatTurn(
                              isUser: m.role == CoachRole.user, text: m.text),
                      ],
                      onSend: (t) => ref
                          .read(explainChatProvider(_key).notifier)
                          .send(t, card: card, section: section),
                      busy: state.busy,
                      error: state.error,
                      hintText: 'Explain your approach…',
                      fadeColor: theme.colorScheme.surfaceContainerLow,
                      opener: Text(
                        'Talk through it out loud (no coding): the recognition '
                        'trigger, the approach, the complexity, the edge cases. '
                        'Type a line to have the coach probe you — or just '
                        'explain it to yourself and grade how it went.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
            ),
            const Divider(height: 1),
            _GradeBar(
              suggested: suggested,
              onGrade: (o) => _grade(context, ref, o),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeBar extends StatelessWidget {
  const _GradeBar({required this.suggested, required this.onGrade});

  final ExplainOutcome? suggested;
  final void Function(ExplainOutcome) onGrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              suggested == null
                  ? 'How well did you recall it?'
                  : 'How well did you recall it? (coach suggests '
                      '${suggested!.name})',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final g in _grades) ...[
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onGrade(g.outcome),
                      style: FilledButton.styleFrom(
                        backgroundColor: g.color.withValues(
                            alpha: suggested == g.outcome ? 0.28 : 0.14),
                        foregroundColor: g.color,
                        side: suggested == g.outcome
                            ? BorderSide(color: g.color, width: 1.5)
                            : null,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(g.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (g.outcome != _grades.last.outcome)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoKey extends StatelessWidget {
  const _NoKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Add your Anthropic API key in Settings to have the coach quiz you. '
          'You can still explain it to yourself and grade how it went below.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
