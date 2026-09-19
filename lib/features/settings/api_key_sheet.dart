import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/design/onyx_design.dart';
import '../../shared/providers/ai.dart';
import '../../shared/widgets/sheet_header.dart';

/// The BYO-key entry sheet (design-system §4.9). Replaces the bare `AlertDialog`
/// so key entry gets the same slide-up chrome as every other sheet (drag handle,
/// `radiusSheet`, `SheetHeader`) and room for the "where it's stored / where to
/// get one" copy the dialog had no space for. Keychain-backed via [apiKeyProvider]
/// and "Not now"-able (the close X or the text button both just dismiss).
Future<void> showApiKeySheet(BuildContext context) {
  return showOnyxSheet<void>(
    context,
    builder: (_) => const _ApiKeySheet(),
  );
}

class _ApiKeySheet extends ConsumerStatefulWidget {
  const _ApiKeySheet();

  @override
  ConsumerState<_ApiKeySheet> createState() => _ApiKeySheetState();
}

class _ApiKeySheetState extends ConsumerState<_ApiKeySheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (key.isEmpty) {
      nav.pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiKeyProvider.notifier).set(key);
      messenger.showSnackBar(const SnackBar(content: Text('API key saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save key: $e')));
    }
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Lift the content above the on-screen keyboard.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(
            title: 'Anthropic API key',
            icon: Icons.key_outlined,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, Dim.space1, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  enabled: !_saving,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    hintText: 'sk-ant-…',
                    labelText: 'Key',
                  ),
                ),
                const SizedBox(height: Dim.space3),
                Text(
                  'Your key stays on this device (Keychain) and is sent only to '
                  'Anthropic when a coach or mock runs. Get one at '
                  'console.anthropic.com.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Not now'),
                    ),
                    const SizedBox(width: Dim.space2),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
