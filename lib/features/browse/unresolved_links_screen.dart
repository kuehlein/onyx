import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/vault/vault_indexer.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/vault.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_view.dart';
import 'stub_note_screen.dart';

/// Unresolved-links view (task #20): every `[[wikilink]]` that points to no file
/// in the vault, grouped by the missing target (most-referenced first). Each
/// target lists the cards that reference it — tap one to open and fix it, or
/// create a note with that name and every link to it resolves on re-index. A
/// target is dangling only when NO file of any type shares its name, so links to
/// plain notes or attachments aren't false-flagged.
class UnresolvedLinksScreen extends ConsumerWidget {
  const UnresolvedLinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(unresolvedLinksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Unresolved links')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Couldn’t read links',
          message: '$e',
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return const EmptyState(
              icon: Icons.link_outlined,
              title: 'No unresolved links',
              message: 'Every [[link]] in your notes points to a file that '
                  'exists. Nice and tidy.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: Dim.space6),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Dim.space4, Dim.space3, Dim.space4, Dim.space2),
                child: Text(
                  '${groups.length} link '
                  'target${groups.length == 1 ? '' : 's'} point to a note or '
                  'file that doesn’t exist yet. Create one with that name, or '
                  'fix the link in the card.',
                  style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant, height: 1.4),
                ),
              ),
              for (final g in groups)
                _TargetGroup(target: g.target, refs: g.refs),
            ],
          );
        },
      ),
    );
  }
}

/// One missing target: a header (`[[target]]` + reference count) over the cards
/// that link to it, each tappable through to the card detail to fix.
class _TargetGroup extends StatelessWidget {
  const _TargetGroup({required this.target, required this.refs});

  final String target;
  final List<UnresolvedLink> refs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The target header opens the stub (a placeholder view with a "create
        // this note" affordance); the ref rows below still jump to the source
        // card to fix the link there — two distinct intents, both kept.
        InkWell(
          onTap: () => showStubNote(context, target),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Dim.space4, Dim.space4, Dim.space4, Dim.space1),
            child: Row(
              children: [
                Icon(Icons.link_off,
                    size: Dim.iconSm, color: context.colors.error),
                const SizedBox(width: Dim.space2),
                Expanded(
                  child: Text(
                    '[[$target]]',
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${refs.length} ref${refs.length == 1 ? '' : 's'}',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(width: Dim.space1),
                Icon(Icons.chevron_right,
                    size: Dim.iconSm, color: context.colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
        for (final r in refs)
          ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.only(left: Dim.space6, right: Dim.space4),
            title: Text(
              r.fromTitle.isEmpty ? '(untitled card)' : r.fromTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/browse/card/${r.fromCardId}'),
          ),
      ],
    );
  }
}
