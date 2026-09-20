import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/vault/starter_deck.dart';
import '../../core/vault/vault_ref.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/vault.dart';
import '../../shared/widgets/sheet_header.dart';

// Copy/code divergence (docs/settings-ux.md §3): the user-facing noun is
// "study folder" / "folder", never "vault" — "vault" is Obsidian's word and the
// mandate is Obsidian-compatible, never Obsidian-required. The code layer keeps
// VaultSource / vaultSourceProvider / VaultRef; only the UI strings say "folder".

/// Presents the shared folder-source picker as a slide-up sheet (design-system
/// §4.9), for changing/creating the study folder from Settings. The same
/// [FolderSourceBody] renders full-page on the `/welcome` first-run gate.
Future<void> showFolderSourceSheet(BuildContext context, WidgetRef ref) {
  return showOnyxSheet<void>(
    context,
    builder: (_) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(title: 'Study folder', icon: Icons.folder_outlined),
        Padding(
          padding: EdgeInsets.fromLTRB(Dim.space5, 0, Dim.space5, Dim.space5),
          child: FolderSourceBody(),
        ),
      ],
    ),
  );
}

/// The two actions ("Choose a folder" / "Create a study folder for me") plus the
/// "What can I point it at?" in-place expander — the shared body powering both
/// the `/welcome` full page and the Settings folder-source sheet. Owns its own
/// in-progress state so buttons disable + a spinner shows while a pick/create
/// runs. On success it calls [VaultRefController.choose]; the router gate then
/// redirects to Home (a `context.go('/')` fallback is issued too, harmless once
/// the gate is already satisfied).
class FolderSourceBody extends ConsumerStatefulWidget {
  const FolderSourceBody({super.key});

  @override
  ConsumerState<FolderSourceBody> createState() => _FolderSourceBodyState();
}

class _FolderSourceBodyState extends ConsumerState<FolderSourceBody> {
  bool _busy = false;
  bool _expanded = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    // Capture before the await so we don't touch context across the async gap.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      // This is the very first write a new user hits (create+seed, or choose a
      // folder). A silent failure — permissions, disk, a stale bookmark — would
      // strand them with no recourse, so surface it and stay on the sheet.
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
              "Couldn't set up the folder — check its permissions and try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Leave after a source is chosen. In the Settings sheet (a modal we can pop)
  /// just close it — we're already in the app. On the full-page /welcome gate
  /// there's nothing to pop, so route into the app (the gate would also redirect
  /// once configured, but this is immediate + explicit).
  void _leave() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _choose() => _run(() async {
        // The button is only shown where pickExisting works (canPickExisting), so
        // a null here means the user cancelled the chooser — stay put, silently.
        final ref0 = await ref.read(folderPickerProvider).pickExisting();
        if (ref0 == null) return;
        await ref.read(vaultRefControllerProvider.notifier).choose(ref0);
        _leave();
      });

  Future<void> _create() => _run(() async {
        final picker = ref.read(folderPickerProvider);
        final controller = ref.read(vaultRefControllerProvider.notifier);
        final r = await picker.createManaged();
        final src = resolveVaultSource(r);
        await seedStarterDeck(src);
        await controller.choose(r);
        _leave();
      });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final canPick = ref.watch(folderPickerProvider).canPickExisting;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          canPick
              ? 'Onyx studies the markdown notes in a folder on this device. '
                  'Pick one you already have, or let Onyx make one for you. '
                  'Nothing leaves the folder.'
              : 'Onyx studies markdown notes in a folder on this device. Let '
                  'Onyx create one for you to start — nothing leaves the folder.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant, height: 1.4),
        ),
        SizedBox(height: t.space5),
        if (canPick) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _choose,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Choose a folder'),
          ),
          SizedBox(height: t.space3),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Create a study folder for me'),
          ),
        ] else
          // No native folder chooser here yet (iOS/Android — ADR-0002), so the
          // always-available app-managed create is the primary action.
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Create a study folder for me'),
          ),
        SizedBox(height: t.space2),
        _Expander(
          expanded: _expanded,
          canPick: canPick,
          onToggle: () => setState(() => _expanded = !_expanded),
        ),
        // A slim progress line while an action runs, so a slow create/index is
        // visibly working (buttons are already disabled above).
        AnimatedSize(
          duration: t.motionFast,
          curve: t.easeStandard,
          child: _busy
              ? Padding(
                  padding: EdgeInsets.only(top: t.space4),
                  child: const LinearProgressIndicator(),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The "What can I point it at?" in-place disclosure (AnimatedSize, never a
/// sheet-in-a-sheet — §4.9). Explains the accepted content, names Obsidian once
/// as reassurance, and points a note-less user at Create.
class _Expander extends StatelessWidget {
  const _Expander(
      {required this.expanded, required this.canPick, required this.onToggle});

  final bool expanded;
  final bool canPick;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final muted = context.text.bodySmall
        ?.copyWith(color: context.colors.onSurfaceVariant, height: 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: t.brChip,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: t.space2),
            child: Row(
              children: [
                Expanded(
                  child: Text('What can I point it at?',
                      style: context.text.bodyMedium),
                ),
                Icon(expanded ? Icons.expand_less : Icons.chevron_right,
                    color: context.colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: t.motionFast,
          curve: t.easeStandard,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: EdgeInsets.only(bottom: t.space2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  Any folder of markdown (.md) notes.',
                          style: muted),
                      SizedBox(height: t.space1),
                      if (canPick) ...[
                        Text(
                            '•  An Obsidian vault works as-is — Onyx reads it '
                            'and ignores its config files.',
                            style: muted),
                        SizedBox(height: t.space1),
                        Text(
                            '•  No notes yet? Create a study folder and Onyx '
                            'starts you with a few sample cards.',
                            style: muted),
                      ] else ...[
                        Text(
                            '•  Create a study folder and Onyx starts you with '
                            'a few sample cards.',
                            style: muted),
                        SizedBox(height: t.space1),
                        Text(
                            '•  Pointing Onyx at an existing folder (like an '
                            'Obsidian vault) is coming to mobile soon.',
                            style: muted),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
