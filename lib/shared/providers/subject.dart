import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/subject/active_subject.dart';
import '../../core/subject/software_interviews.dart';
import '../../core/subject/subject_config.dart';
import '../../core/subject/subject_config_yaml.dart';
import '../../core/vault/vault_source.dart';
import 'vault.dart';

part 'subject.g.dart';

/// The vault file holding the active subject config (task #30 Phase 5). Lives in
/// `_meta/` (excluded from card indexing); the fuller `_onyx/config.md` layout in
/// docs/vault-structure.md is a later refinement.
const subjectConfigFileName = 'onyx-subject.yaml';

/// Loads the active subject config from the vault, falling back to the built-in
/// SWE reference when absent or malformed, and sets the process-wide
/// [activeSubject] that pure core math (target/ladder/parser) reads. `vaultIndex`
/// awaits this so the config is in place before any card is parsed.
@riverpod
Future<SubjectConfig> activeSubjectConfig(Ref ref) async {
  final source = ref.watch(vaultSourceProvider);
  final loaded = source == null ? null : await _load(source);
  activeSubject = loaded ?? softwareInterviewsConfig;
  return activeSubject;
}

Future<SubjectConfig?> _load(VaultSource source) async {
  final raw = await source.readMeta(subjectConfigFileName);
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    return subjectConfigFromYaml(raw);
  } catch (_) {
    return null; // malformed config → fall back to the default
  }
}
