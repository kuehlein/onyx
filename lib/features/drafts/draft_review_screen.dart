// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/design/onyx_design.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/drafts.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fading_scroll_edges.dart';
import '../../shared/widgets/loading_view.dart';
import '../editor/card_editor_screen.dart';

/// The draft-review gate: a bounded self-test-then-promote session over
/// `status: draft` cards (docs/content-creation.md §3–§4). For each draft you see
/// the title as a CUE, attempt recall, reveal the body, then decide per card —
/// Keep (promote to active), Skip (leave a draft), or Discard (delete the file).
///
/// The same recall→reveal shape as [QuizScreen]; only the terminal actions differ
/// (keep/skip/discard vs the FSRS grades). No bulk accept — the first pass is a
/// retrieval rep (the generation-effect law, §4.2).
class DraftReviewScreen extends ConsumerStatefulWidget {
  const DraftReviewScreen({super.key});

  @override
  ConsumerState<DraftReviewScreen> createState() => _DraftReviewScreenState();
}

class _DraftReviewScreenState extends ConsumerState<DraftReviewScreen> {
  bool _revealed = false;

  Future<void> _keep() async {
    setState(() => _revealed = false);
    await ref.read(draftReviewProvider.notifier).keep();
  }

  Future<void> _discard() async {
    setState(() => _revealed = false);
    await ref.read(draftReviewProvider.notifier).discard();
  }

  void _skip() {
    setState(() => _revealed = false);
    ref.read(draftReviewProvider.notifier).skip();
  }

  /// Open the in-app editor on the current draft, then refresh the session's
  /// snapshot so the reveal reflects the edit. The card stays a draft (edit
  /// preserves status), so the user can still Keep it after editing.
  Future<void> _edit(Card card) async {
    final saved = await showCardEditor(context, card: card);
    if (saved) await ref.read(draftReviewProvider.notifier).refreshCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(draftReviewProvider);
    final s = session.asData?.value;
    final showProgress = s != null && !s.isDone && s.total > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review drafts'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
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
          child:
              Text('Could not load drafts:\n$e', textAlign: TextAlign.center),
        ),
        data: (s) {
          if (s.total == 0) return const _EmptyState();
          if (s.isDone) return _CompleteState(session: s);
          return _ReviewView(
            card: s.current!,
            position: s.index + 1,
            total: s.total,
            revealed: _revealed,
            onReveal: () => setState(() => _revealed = true),
            onKeep: _keep,
            onSkip: _skip,
            onDiscard: _discard,
            onEdit: () => _edit(s.current!),
          );
        },
      ),
    );
  }
}

/// One draft: the title as the recall cue, a Reveal button, then the card body
/// (all sections) and the keep/skip/discard action bar.
class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.card,
    required this.position,
    required this.total,
    required this.revealed,
    required this.onReveal,
    required this.onKeep,
    required this.onSkip,
    required this.onDiscard,
    required this.onEdit,
  });

  final Card card;
  final int position;
  final int total;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback onKeep;
  final VoidCallback onSkip;
  final VoidCallback onDiscard;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: [
            Expanded(
              child: FadingScrollEdges(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Dim.space4, Dim.space4, Dim.space4, Dim.space5),
                  children: [
                    Text('$position / $total',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: Dim.space3),
                    // The CUE: the card title. Recall what's on it, then reveal.
                    Text(card.title, style: theme.textTheme.headlineSmall),
                    if (!revealed) ...[
                      const SizedBox(height: 20),
                      Text(
                        "Recall what's on this card, then reveal to check.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (revealed) ...[
                      const SizedBox(height: Dim.space4),
                      const Divider(),
                      const SizedBox(height: Dim.space2),
                      if (card.overview.isNotEmpty) ...[
                        CardMarkdown(card.overview),
                        const SizedBox(height: Dim.space2),
                      ],
                      for (final section in card.sections) ...[
                        Text(section.heading,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary)),
                        const SizedBox(height: 6),
                        CardMarkdown(section.content),
                        const SizedBox(height: Dim.space3),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            _ActionBar(
              revealed: revealed,
              onReveal: onReveal,
              onKeep: onKeep,
              onSkip: onSkip,
              onDiscard: onDiscard,
              onEdit: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Before reveal: just Reveal. After reveal: Keep (primary) with Skip and a
/// destructive-styled Discard beneath.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.revealed,
    required this.onReveal,
    required this.onKeep,
    required this.onSkip,
    required this.onDiscard,
    required this.onEdit,
  });

  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback onKeep;
  final VoidCallback onSkip;
  final VoidCallback onDiscard;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Dim.space4, Dim.space2, Dim.space4, Dim.space3),
        child: revealed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onKeep,
                      icon: const Icon(Icons.check),
                      label: const Text('Keep'),
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: Dim.space4),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dim.space2),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: onSkip,
                          child: const Text('Skip'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onDiscard,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Discard'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                        ),
                      ),
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
                    padding: const EdgeInsets.symmetric(vertical: Dim.space4),
                  ),
                ),
              ),
      ),
    );
  }
}

/// No drafts to review on entry — a calm, honest empty state.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No drafts to review',
        message: 'New cards from an import or generation land here to review '
            'before they count.',
        action: FilledButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          child: const Text('Done'),
        ),
      );
}

/// Session summary: a calm count of what happened — no celebration hype.
class _CompleteState extends StatelessWidget {
  const _CompleteState({required this.session});
  final DraftReviewSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 44, color: theme.colorScheme.primary),
              const SizedBox(height: Dim.space3),
              Text('Review complete',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: Dim.space2),
              Text(
                'Promoted ${session.promoted} · '
                'Discarded ${session.discarded} · '
                'Skipped ${session.skipped}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (session.skipped > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Skipped drafts stay in Browse to review later.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
