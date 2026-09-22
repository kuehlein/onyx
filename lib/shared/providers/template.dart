import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/template/active_template.dart';
import '../../core/template/builtin_templates.dart';
import '../../core/template/neutral_template.dart';
import '../../core/template/deck_template.dart';
import '../../core/template/template_registry.dart';
import '../../core/vault/vault_source.dart';
import 'study_goals.dart';
import 'vault.dart';

part 'template.g.dart';

/// Discovers every subject config in the vault and builds the [TemplateRegistry]
/// — one entry per per-directory config, or a single built-in SWE reference when
/// the vault declares none. Also sets the process-wide [activeTemplate] (the
/// registry's primary subject) that pure core still reads pre-M2. `vaultIndex`
/// awaits this so subjects are resolved before any card is parsed.
@riverpod
Future<TemplateRegistry> templateRegistry(Ref ref) async {
  final source = ref.watch(vaultSourceProvider);
  final registry = source == null
      ? TemplateRegistry.single(neutralTemplate)
      : await _discover(source);
  activeTemplate = registry.primary;
  activeRegistry = registry;
  return registry;
}

/// The primary subject config — the whole-vault subject, or the built-in SWE
/// reference as a fallback. Retained for the many call sites that need a single
/// active subject; multi-subject-aware call sites read [templateRegistryProvider].
@riverpod
Future<DeckTemplate> activeTemplateConfig(Ref ref) async =>
    (await ref.watch(templateRegistryProvider.future)).primary;

/// The [DeckTemplate] backing the ACTIVE study goal (its template), or the
/// primary subject when the goal names no known template. Per-goal so shared UI
/// (the Home target card, readiness/coach copy — G7) reads the RIGHT subject's
/// vocabulary/target under multi-subject, not the process-global primary.
@riverpod
Future<DeckTemplate> activeGoalTemplate(Ref ref) async {
  final goal = await ref.watch(activeStudyGoalProvider.future);
  final registry = await ref.watch(templateRegistryProvider.future);
  return registry.byId(goal.templateId) ?? registry.primary;
}

Future<TemplateRegistry> _discover(VaultSource source) async {
  final discovered = <(String, DeckTemplate)>[];
  for (final path in await source.listConfigPaths()) {
    final raw = await source.readCard(path);
    if (raw.trim().isEmpty) continue;
    // A config may name a built-in template by id (e.g. `id: software-interviews`)
    // to opt in without re-specifying it; else it's a full custom config. A
    // malformed config resolves to null and is skipped (falls back below).
    final config = resolveDeckTemplate(raw);
    if (config != null) discovered.add((path, config));
  }
  return TemplateRegistry.fromConfigs(
    discovered,
    fallback: neutralTemplate,
  );
}
