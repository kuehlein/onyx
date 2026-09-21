import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/subject/active_subject.dart';
import '../../core/subject/software_interviews.dart';
import '../../core/subject/subject_config.dart';
import '../../core/subject/subject_config_yaml.dart';
import '../../core/subject/subject_registry.dart';
import '../../core/vault/vault_source.dart';
import 'study_goals.dart';
import 'vault.dart';

part 'subject.g.dart';

/// The filename that declares a subject. At the vault root's `_meta/` it's the
/// legacy single-subject config; in any subtree it declares that subtree as a
/// concurrent subject (task #30d). The fuller `_onyx/config.md` layout in
/// docs/vault-structure.md is a later refinement.
const subjectConfigFileName = 'onyx-subject.yaml';

/// Discovers every subject config in the vault and builds the [SubjectRegistry]
/// — one entry per per-directory config, or a single built-in SWE reference when
/// the vault declares none. Also sets the process-wide [activeSubject] (the
/// registry's primary subject) that pure core still reads pre-M2. `vaultIndex`
/// awaits this so subjects are resolved before any card is parsed.
@riverpod
Future<SubjectRegistry> subjectRegistry(Ref ref) async {
  final source = ref.watch(vaultSourceProvider);
  final registry = source == null
      ? SubjectRegistry.single(softwareInterviewsConfig)
      : await _discover(source);
  activeSubject = registry.primary;
  activeRegistry = registry;
  return registry;
}

/// The primary subject config — the whole-vault subject, or the built-in SWE
/// reference as a fallback. Retained for the many call sites that need a single
/// active subject; multi-subject-aware call sites read [subjectRegistryProvider].
@riverpod
Future<SubjectConfig> activeSubjectConfig(Ref ref) async =>
    (await ref.watch(subjectRegistryProvider.future)).primary;

/// The [SubjectConfig] backing the ACTIVE study goal (its template), or the
/// primary subject when the goal names no known template. Per-goal so shared UI
/// (the Home target card, readiness/coach copy — G7) reads the RIGHT subject's
/// vocabulary/target under multi-subject, not the process-global primary.
@riverpod
Future<SubjectConfig> activeGoalSubject(Ref ref) async {
  final goal = await ref.watch(activeStudyGoalProvider.future);
  final registry = await ref.watch(subjectRegistryProvider.future);
  return registry.byId(goal.templateId) ?? registry.primary;
}

Future<SubjectRegistry> _discover(VaultSource source) async {
  final discovered = <(String, SubjectConfig)>[];
  for (final path in await source.listConfigPaths()) {
    final raw = await source.readCard(path);
    if (raw.trim().isEmpty) continue;
    try {
      discovered.add((path, subjectConfigFromYaml(raw)));
    } catch (_) {
      // Malformed config → skip it (as before, a lone bad config falls back to
      // the built-in default via SubjectRegistry.fromConfigs).
    }
  }
  return SubjectRegistry.fromConfigs(
    discovered,
    fallback: softwareInterviewsConfig,
  );
}
