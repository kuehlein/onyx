// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/interview/assessment.dart';
import '../models/card.dart';
import '../providers/analytics.dart';
import '../providers/clock.dart';
import '../providers/interview.dart';
import '../providers/readiness.dart';
import '../status_colors.dart';

/// The self-report you log after solving an interview question on your own
/// machine (LeetCode/NeetCode) — the return path Onyx can't see otherwise. Maps
/// to an applied-transfer attempt (`source: external`), so real solves count as
/// the truest transfer evidence toward readiness.
typedef _Outcome = ({String label, int score, int hint, Color color});

const _outcomes = <_Outcome>[
  (label: 'Solved it cleanly', score: 90, hint: 0, color: statusGood),
  (label: 'Solved, needed a hint', score: 65, hint: 2, color: statusWarn),
  (label: 'Struggled through it', score: 45, hint: 3, color: statusWarn),
  (label: 'Couldn’t solve it', score: 20, hint: 5, color: statusBad),
];

/// Opens the "log a solve" sheet for an interview-question [card].
Future<void> showLogSolveSheet(BuildContext context, {required Card card}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => _LogSolveSheet(card: card),
  );
}

class _LogSolveSheet extends ConsumerStatefulWidget {
  const _LogSolveSheet({required this.card});
  final Card card;

  @override
  ConsumerState<_LogSolveSheet> createState() => _LogSolveSheetState();
}

class _LogSolveSheetState extends ConsumerState<_LogSolveSheet> {
  final _insight = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _insight.dispose();
    super.dispose();
  }

  Future<void> _log(_Outcome o) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final note = _insight.text.trim();
    final now = (await ref.read(clockProvider.future)).now();
    await ref.read(appliedRepositoryProvider).record(
          cardId: widget.card.id,
          sectionSlug: null,
          domain: widget.card.domain,
          source: 'external',
          occurredAt: now,
          assessment: AppliedAssessment(
            appliedScore: o.score,
            hintLevel: o.hint,
            note: note.isEmpty ? null : note,
          ),
        );
    // Real solves are applied evidence — refresh what depends on it.
    ref.invalidate(appliedTransferProvider);
    ref.invalidate(appliedSummaryProvider);
    ref.invalidate(readinessProvider);
    ref.invalidate(mockSkillsProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
        const SnackBar(content: Text('Solve logged — nice work.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Log a solve',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(widget.card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              TextField(
                controller: _insight,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'The key insight or what tripped you (optional)',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('How did it go?',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              for (final o in _outcomes) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _log(o),
                    style: FilledButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      backgroundColor: o.color.withValues(alpha: 0.16),
                      foregroundColor: o.color,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    child: Text(o.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
