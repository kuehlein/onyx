import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/glossary.dart';
import 'vault.dart';

part 'glossary.g.dart';

/// The term→definition glossary loaded from the vault (`_meta/glossary.json`).
/// Empty until generated (Settings → Generate glossary). Read-only here;
/// generation is an explicit AI action. Invalidate after generating.
@riverpod
Future<Map<String, String>> glossary(Ref ref) async {
  final source = ref.watch(vaultSourceProvider);
  if (source == null) return const {};
  return GlossaryService(source: source).load();
}
