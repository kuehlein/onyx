import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/deck/deck.dart';
import '../../core/plan/urgency.dart';
import '../../core/readiness/feasibility.dart';
import '../../core/readiness/target.dart';
import 'clock.dart';
import 'decks.dart';
import 'readiness.dart'; // hub re-exports readiness_forecast (readinessForecastFor)
import 'template.dart';
import 'vault.dart';

part 'readiness_feasibility.g.dart';

/// The per-aim **feasibility** + daily-plan **emphasis** derived layer (split out of
/// `readiness.dart`, S5f). Feasibility (S4b) asks "can you be durably ready by each
/// dated aim's date at your pace?"; the plan weights (S3 / ADR-0007) turn the active
/// aims — weighted by feasibility urgency — into today's per-domain emphasis.

/// Per-aim feasibility (S4b) for a deck's ACTIVE aims — for each dated aim, "can
/// you be durably ready by its date at the current pace?", classified from the
/// aim's own [ReadinessForecast] (its role + durability bar) vs that date. An aim
/// with no scheduled round reports [FeasibilityStatus.openEnded] (judged by
/// coverage, not a ready-by). Returned in the deck's active-aim order, each paired
/// with its [Aim] so consumers can name/allocate it. The daily plan weights
/// urgency on this (S3), the coach warns from it (#103 — infeasible = the
/// incoherent-cram case), and the Aims surface shows it per aim (S5).
///
/// The forecast substrate ([readinessForecastFor]) is scoped to THIS [deckId]'s
/// cards (keyed by `(deckId, role)`, #113), so per-aim feasibility is exact for any
/// deck — active or a non-active lane in the hub — not just the active one.
@riverpod
Future<List<({Aim aim, AimFeasibility feasibility})>> deckAimFeasibility(
    Ref ref, String deckId) async {
  final goalsF = ref.watch(decksProvider.future);
  final registryF = ref.watch(templateRegistryProvider.future);
  final goal = pickDeck(await goalsF, deckId);
  final registry = await registryF;
  final template = registry.byId(goal.templateId) ?? registry.primary;

  final out = <({Aim aim, AimFeasibility feasibility})>[];
  for (final aim in goal.aims) {
    if (!aim.active) continue;
    final date = aim.currentRound()?.date;
    if (date == null) {
      // Open-ended aim → coverage, not a ready-by (no forecast needed). A PAST-dated
      // round is handled downstream in [classifyAimFeasibility] (it becomes
      // open-ended too, not infeasible — see there).
      out.add((aim: aim, feasibility: classifyAimFeasibility(date: null)));
      continue;
    }
    final t = ReadinessTarget.forAim(aim, template);
    final forecast = await ref.watch(readinessForecastForProvider((
      deckId: deckId,
      level: t.level,
      company: t.company,
      track: t.track,
    )).future);
    out.add((
      aim: aim,
      feasibility: classifyAimFeasibility(
        date: DateTime(date.year, date.month, date.day),
        forecast: forecast,
      ),
    ));
  }
  return out;
}

/// Per-aim feasibility for the ACTIVE deck — see [deckAimFeasibility].
@riverpod
Future<List<({Aim aim, AimFeasibility feasibility})>> aimFeasibility(
    Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckAimFeasibilityProvider(goal.id).future);
}

/// Urgency-weighted per-domain **emphasis for the daily PLAN** (S3 / ADR-0007):
/// how much each domain should pull *today*, given the deck's active aims weighted
/// by their feasibility urgency. This is an ALLOCATION signal — deliberately
/// distinct from readiness's domain weighting, which must NOT depend on today's
/// urgency. Each active aim contributes its OWN resolved-track domain weight (+ any
/// AI-plan boost), combined as a **normalized urgency-weighted average** (ADR-0007):
/// a domain only a calm aim cares about is softened when a busy aim also needs the
/// day. No active aim → the deck's base target weights; a single aim → its own
/// weights (its urgency share is 1, so it cancels) — both byte-identical to pre-S3.
@riverpod
Future<Map<String, double>> deckPlanDomainWeights(
    Ref ref, String deckId) async {
  final goalsF = ref.watch(decksProvider.future);
  final registryF = ref.watch(templateRegistryProvider.future);
  final indexF = ref.watch(vaultIndexProvider.future);
  final feasF = ref.watch(deckAimFeasibilityProvider(deckId).future);
  final clockF = ref.watch(clockProvider.future);
  final goal = pickDeck(await goalsF, deckId);
  final registry = await registryF;
  final index = await indexF;
  final feas = await feasF;
  final today = (await clockF).today();
  final template = registry.byId(goal.templateId) ?? registry.primary;

  final domains = <String>{
    for (final c in index.studyCards)
      if (c.domain != null) c.domain!,
  };

  // No active aim → the deck's base target emphasis (byte-identical to pre-S3).
  if (feas.isEmpty) {
    final base = ReadinessTarget.forAim(const Aim(), template);
    return {for (final d in domains) d: domainWeight(base, d)};
  }

  // Normalized urgency shares across the active aims. All-ready (Σurgency 0) → equal
  // shares (a plain average) so the plan still has an emphasis to pack on.
  final urg = [for (final e in feas) aimUrgency(e.feasibility, today: today)];
  final total = urg.fold(0.0, (s, u) => s + u);
  final shares = total > 0
      ? [for (final u in urg) u / total]
      : [for (final _ in urg) 1 / urg.length];
  final targets = [
    for (final e in feas) ReadinessTarget.forAim(e.aim, template)
  ];

  final out = <String, double>{};
  for (final d in domains) {
    var w = 0.0;
    for (var i = 0; i < feas.length; i++) {
      // The aim's own-track domain weight, plus its explicit AI-plan boost.
      final aw =
          domainWeight(targets[i], d) + (feas[i].aim.domainWeights[d] ?? 0);
      w += shares[i] * aw;
    }
    out[d] = w;
  }
  return out;
}

/// Plan domain emphasis for the ACTIVE deck — see [deckPlanDomainWeights].
@riverpod
Future<Map<String, double>> activePlanDomainWeights(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckPlanDomainWeightsProvider(goal.id).future);
}
