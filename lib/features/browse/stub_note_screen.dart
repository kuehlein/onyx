// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/vault/card_edit.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/vault.dart';
import '../../shared/widgets/loading_view.dart';
import '../editor/card_editor_screen.dart';

/// Opens the STUB view for a broken `[[wikilink]]` [target].
Future<void> showStubNote(BuildContext context, String target) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => StubNoteScreen(target: target)),
    );

/// The STUB mode of the card (card.md / ADR-0012): a placeholder for a link
/// target that has no file yet — the de-slugged target as a heading, the
/// References that point to it (from the UNRESOLVED graph — a dangling target has
/// no resolved neighborhood), and a **Create this note** affordance that opens the
/// editor seeded so the new file's stem == the target, resolving every
/// `[[target]]` on re-index. A focused screen composing shared parts — NOT a
/// synthetic Card, so it never touches a study/id-keyed path.
class StubNoteScreen extends ConsumerWidget {
  const StubNoteScreen({super.key, required this.target});

  final String target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(unresolvedLinksProvider);
    return Scaffold(
      appBar: AppBar(title: Text(humanizeSlug(target))),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(
          child: Text('Couldn’t read links:\n$e', textAlign: TextAlign.center),
        ),
        data: (groups) {
          final refs = [
            for (final g in groups)
              if (g.target == target) ...g.refs,
          ];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Dim.maxContentWidth),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Dim.space4, Dim.space4, Dim.space4, Dim.space6),
                children: [
                  Row(
                    children: [
                      Icon(Icons.link_off,
                          size: Dim.iconMd, color: context.colors.error),
                      const SizedBox(width: Dim.space2),
                      Expanded(
                        child: Text('[[$target]]',
                            style: context.text.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dim.space3),
                  Text(
                    "This note doesn't exist yet. Create it and every link to it "
                    'resolves on the next scan.',
                    style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: Dim.space4),
                  FilledButton.icon(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create this note'),
                  ),
                  if (refs.isNotEmpty) ...[
                    const SizedBox(height: Dim.space6),
                    Text(
                      'REFERENCED BY',
                      style: context.text.labelMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6),
                    ),
                    const SizedBox(height: Dim.space1),
                    for (final r in refs)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          r.fromTitle.isEmpty ? '(untitled card)' : r.fromTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/browse/card/${r.fromCardId}'),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final navigator = Navigator.of(context);
    // Pass the target as the create slug so the new file's stem == the target and
    // the [[target]] links resolve; seed a readable title from it.
    final saved = await showCardEditor(
      context,
      initialTitle: humanizeSlug(target),
      createSlug: target,
    );
    // The target now has a file (this stub is stale) — return to the list.
    if (saved && navigator.canPop()) navigator.pop();
  }
}
