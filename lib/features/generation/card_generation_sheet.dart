import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/design/onyx_design.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/card_generation.dart';
import '../../shared/providers/vault.dart';
import '../../shared/widgets/sheet_header.dart';
import '../settings/api_key_sheet.dart';

/// Opens the "Generate cards" sheet (docs/content-creation.md §2.2): paste notes
/// or name a topic, and a capable model proposes a small batch of cards written
/// as drafts you review before they count. Gated on an AI key being present.
Future<void> showCardGenerationSheet(BuildContext context, WidgetRef ref) {
  return showOnyxSheet<void>(
    context,
    builder: (_) => const _CardGenerationSheet(),
  );
}

class _CardGenerationSheet extends ConsumerStatefulWidget {
  const _CardGenerationSheet();

  @override
  ConsumerState<_CardGenerationSheet> createState() =>
      _CardGenerationSheetState();
}

class _CardGenerationSheetState extends ConsumerState<_CardGenerationSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _busy) return;
    // Capture the router + messenger before the async gap + sheet pop, so the
    // success snackbar/navigation still work once this context is gone
    // (mirrors import_deck_sheet.dart).
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count =
          await ref.read(cardGenerationProvider.notifier).generate(input);
      // Ensure Browse/study pick up the new drafts even if the one-shot notifier
      // was disposed across the await (its own invalidate is mounted-guarded).
      ref.invalidate(vaultIndexProvider);
      navigator.maybePop();
      router.go('/draft-review');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Generated $count ${count == 1 ? 'card' : 'cards'} — '
              'review them before they count.'),
        ),
      );
    } on CardGenerationException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not generate cards: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = ref.watch(claudeServiceProvider) != null;
    final hasFolder = ref.watch(vaultSourceProvider) != null;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(
            title: 'Generate cards',
            icon: Icons.auto_awesome_outlined,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Dim.space5, Dim.space1, Dim.space5, Dim.space5),
            child: !hasKey
                ? const _NoKey()
                : !hasFolder
                    ? const _NoFolder()
                    : _Form(
                        controller: _controller,
                        busy: _busy,
                        error: _error,
                        onGenerate: _generate,
                      ),
          ),
        ],
      ),
    );
  }
}

/// The paste/topic input + Generate button + busy/error states.
class _Form extends StatelessWidget {
  const _Form({
    required this.controller,
    required this.busy,
    required this.error,
    required this.onGenerate,
  });

  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste your notes, or name a topic. AI drafts a small batch of cards — '
          'you review them before they count.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: Dim.space3),
        TextField(
          controller: controller,
          enabled: !busy,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'Paste notes, or name a topic to study…',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: Dim.space3),
          Text(
            error!,
            style:
                context.text.bodySmall?.copyWith(color: context.colors.error),
          ),
        ],
        const SizedBox(height: Dim.space4),
        FilledButton.icon(
          onPressed: busy ? null : onGenerate,
          icon: busy
              ? const Icon(Icons.hourglass_empty)
              : const Icon(Icons.auto_awesome_outlined),
          label: Text(busy ? 'Generating…' : 'Generate'),
        ),
      ],
    );
  }
}

/// Honest AI-off state: point at the other on-ramps + a one-tap way to add a key.
class _NoKey extends ConsumerWidget {
  const _NoKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add an AI key to generate cards — or import a deck. Everything else '
          'works without AI.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: Dim.space4),
        FilledButton.tonal(
          onPressed: () {
            Navigator.of(context).pop();
            showApiKeySheet(context);
          },
          child: const Text('Add AI key'),
        ),
      ],
    );
  }
}

/// No study folder yet — generation writes into a folder, so ask for one first.
class _NoFolder extends StatelessWidget {
  const _NoFolder();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Set up a study folder first, then you can generate cards into it.',
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    );
  }
}
