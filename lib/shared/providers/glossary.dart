import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/glossary.dart';
import 'vault.dart';

part 'glossary.g.dart';

/// The term→definition glossary loaded from the vault note `_meta/glossary.md`.
/// Human-authored in Obsidian and versioned with the vault — the single source
/// of truth for tap-to-define. Empty if the note is absent.
@riverpod
Future<Map<String, String>> glossary(Ref ref) async {
  final source = ref.watch(vaultSourceProvider);
  if (source == null) return const {};
  return GlossaryService(source: source).load();
}
