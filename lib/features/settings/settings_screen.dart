import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/glossary.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/backup.dart';
import '../../shared/providers/glossary.dart';
import '../../shared/providers/settings.dart';
import '../../shared/providers/vault.dart';

/// App settings. Vault selection, the Claude API key (iOS Keychain via
/// flutter_secure_storage), and theme land here. For now it reports the
/// resolved vault so the dev ONYX_VAULT_PATH wiring is visible.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(vaultSourceProvider);
    final index = ref.watch(vaultIndexProvider);
    final apiKey = ref.watch(apiKeyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Vault'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Source'),
            subtitle: Text(source?.rootLabel ?? 'Not configured'),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Indexed cards'),
            subtitle: Text(index.when(
              loading: () => 'Indexing…',
              error: (e, _) => 'Error: $e',
              data: (r) => '${r.cardCount} cards'
                  '${r.idless > 0 ? ' · ${r.idless} missing id' : ''}'
                  '${r.malformed > 0 ? ' · ${r.malformed} malformed' : ''}',
            )),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(vaultIndexProvider),
            ),
          ),
          const _SectionHeader('Learning'),
          ref.watch(newCardLimitProvider).when(
                loading: () => const ListTile(
                  leading: Icon(Icons.auto_stories_outlined),
                  title: Text('New sections per session'),
                  subtitle: Text('Loading…'),
                ),
                error: (e, _) => ListTile(
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: const Text('New sections per session'),
                  subtitle: Text('Error: $e'),
                ),
                data: (limit) => ListTile(
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: const Text('New sections per session'),
                  subtitle: const Text(
                      'The cap on brand-new material each Learn session. Keep it '
                      'modest — cramming new items raises cognitive load and hurts '
                      'retention.'),
                  trailing: _Stepper(
                    value: limit,
                    onChanged: (v) =>
                        ref.read(newCardLimitProvider.notifier).set(v),
                  ),
                ),
              ),
          const _SectionHeader('Progress'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Back up now'),
            subtitle: const Text('Write your progress to the vault snapshot'),
            enabled: source != null,
            onTap: source == null ? null : () => _backupNow(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.settings_backup_restore,
                color: source == null
                    ? null
                    : Theme.of(context).colorScheme.error),
            title: const Text('Restore from vault'),
            subtitle: const Text(
                'Replace local progress with the vault snapshot — happens '
                'automatically on a fresh install'),
            enabled: source != null,
            onTap: source == null ? null : () => _restore(context, ref),
          ),
          const _SectionHeader('Claude'),
          ...apiKey.when(
            loading: () => const [
              ListTile(
                leading: Icon(Icons.key_outlined),
                title: Text('Anthropic API key'),
                subtitle: Text('Checking…'),
              ),
            ],
            error: (e, _) => [
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Anthropic API key'),
                subtitle: Text('Storage error: $e'),
              ),
            ],
            data: (key) {
              final isSet = key != null && key.isNotEmpty;
              // Where did the resolved key come from? The env var wins in
              // `apiKeyProvider.build`, so if it's present the app is using it —
              // this line is the definitive readout when debugging the env
              // fallback on desktop.
              final fromEnv =
                  (Platform.environment['ANTHROPIC_API_KEY'] ?? '').isNotEmpty;
              final String subtitle;
              if (isSet) {
                subtitle = fromEnv
                    ? 'Key detected · from ANTHROPIC_API_KEY (environment)'
                    : 'Key saved · stored in the Keychain';
              } else if (Platform.isLinux) {
                subtitle = 'Not set — launch with ANTHROPIC_API_KEY set '
                    '(no keychain on Linux)';
              } else {
                subtitle = 'Not set — tap to add';
              }
              return [
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Anthropic API key'),
                  subtitle: Text(subtitle),
                  trailing: isSet && !fromEnv
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove key',
                          onPressed: () => _clearApiKey(context, ref),
                        )
                      : null,
                  onTap: fromEnv ? null : () => _editApiKey(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.wifi_tethering),
                  title: const Text('Test connection'),
                  subtitle: const Text('Send a tiny request to verify the key'),
                  enabled: isSet,
                  onTap: isSet ? () => _testConnection(context, ref) : null,
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Draft glossary note'),
                  subtitle: const Text(
                      'AI writes _meta/glossary.md; edit it in Obsidian'),
                  enabled: isSet,
                  onTap: isSet ? () => _draftGlossary(context, ref) : null,
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editApiKey(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anthropic API key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'sk-ant-…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (key == null || key.isEmpty) return;
    try {
      await ref.read(apiKeyProvider.notifier).set(key);
      messenger.showSnackBar(const SnackBar(content: Text('API key saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save key: $e')));
    }
  }

  Future<void> _clearApiKey(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiKeyProvider.notifier).clear();
      messenger.showSnackBar(const SnackBar(content: Text('API key removed')));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Could not remove key: $e')));
    }
  }

  Future<void> _draftGlossary(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final claude = ref.read(claudeServiceProvider);
    final source = ref.read(vaultSourceProvider);
    final index = ref.read(vaultIndexProvider).asData?.value;
    if (claude == null || source == null || index == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Need a key, vault, and indexed cards')));
      return;
    }
    final texts = [
      for (final card in index.cards) ...[
        card.overview,
        for (final section in card.sections) section.content,
      ],
    ];
    final terms = detectGlossaryTerms(texts);
    messenger.showSnackBar(SnackBar(
        content: Text('Drafting glossary from ${terms.length} candidates…')));
    try {
      final count =
          await GlossaryService(source: source, claude: claude).draft(terms);
      ref.invalidate(glossaryProvider);
      messenger.showSnackBar(SnackBar(
          content: Text(
              'Drafted $count terms into _meta/glossary.md — edit freely')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Glossary failed: $e')));
    }
  }

  Future<void> _testConnection(BuildContext context, WidgetRef ref) async {
    final service = ref.read(claudeServiceProvider);
    if (service == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Testing…')));
    try {
      final reply = await service.complete(
          prompt: 'Reply with exactly: pong', maxTokens: 16);
      messenger.showSnackBar(
          SnackBar(content: Text('Connected — Claude replied "$reply"')));
    } on ClaudeException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: ${e.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _backupNow(BuildContext context, WidgetRef ref) async {
    await ref.read(backupProvider.notifier).flush();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress backed up to the vault')),
      );
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from vault?'),
        content: const Text(
          'This replaces your current progress with the snapshot saved in the '
          'vault. Any reviews recorded since that snapshot will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final restored = await ref.read(backupProvider.notifier).restore();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(restored == 0
              ? 'No snapshot found in the vault'
              : 'Restored $restored sections from the vault'),
        ),
      );
    }
  }
}

/// A compact −/value/+ stepper for an integer setting, clamped to the
/// NewCardLimit range and moving in its step.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          visualDensity: VisualDensity.compact,
          onPressed: value > NewCardLimit.min
              ? () => onChanged(value - NewCardLimit.step)
              : null,
        ),
        SizedBox(
          width: 26,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          visualDensity: VisualDensity.compact,
          onPressed: value < NewCardLimit.max
              ? () => onChanged(value + NewCardLimit.step)
              : null,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
