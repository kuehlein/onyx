import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/interview/critic.dart';
import '../../core/interview/transfer.dart';
import '../../core/readiness/readiness.dart';
import '../../core/readiness/target.dart';
import '../../core/readiness/targeting.dart';
import '../../core/deck/deck.dart';
import 'clock.dart';
import 'interview.dart';
import 'srs.dart';
import 'decks.dart';
import 'template.dart';
import 'vault.dart';

// The readiness providers are split across three files for size (S5f): this hub
// (applied evidence + the knowledge-base readiness core + targets), the derived
// ready-date/ladder forecast, and the per-aim feasibility + daily-plan emphasis.
// The two derived layers are re-exported so callers keep importing `readiness.dart`.
export 'readiness_forecast.dart';
export 'readiness_feasibility.dart';

part 'readiness.g.dart';

/// Per-domain transfer estimates from applied (mock-interview) attempts, plus
/// whether any applied evidence exists at all. When it does, the dashboard
/// graduates from knowledge-base to interview readiness and every in-scope
/// domain is transfer-gated — evidence-less domains fall back to the pessimistic
/// prior, so they're honestly capped rather than credited for unproven transfer.
@riverpod
Future<({Map<String, TransferEstimate> byDomain, bool interview})>
    appliedTransfer(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final repo = ref.watch(appliedRepositoryProvider);
  final now = (await ref.watch(clockProvider.future)).now();
  // Bound the query to a year; older attempts are recency-decayed to ~nil anyway.
  final attempts =
      await repo.attempts(since: now.subtract(const Duration(days: 365)));

  final domains = <String>{
    for (final c in index.studyCards)
      if (c.domain != null) c.domain!,
  };
  final samples = <String, List<AppliedSample>>{};
  for (final a in attempts) {
    final d = a.domain;
    if (d == null || !domains.contains(d)) continue;
    final ageDays = now.difference(a.occurredAt).inHours / 24.0;
    samples.putIfAbsent(d, () => []).add(AppliedSample(
          // Reconciled coach+critic score (mean) when a second opinion exists.
          score: effectiveApplied01(a.appliedScore, a.verifierScore),
          novel: a.novel,
          ageDays: ageDays < 0 ? 0 : ageDays,
        ));
  }
  return (
    byDomain: {
      for (final d in domains) d: computeTransfer(samples[d] ?? const []),
    },
    interview: attempts.isNotEmpty,
  );
}

/// Per-domain applied-evidence counts for a goal's dashboard decomposition: how
/// many mock attempts back a domain and how many were *contested* (the
/// adversarial critic disagreed with the coach's grade). Scoped to the goal's
/// member cards so a lane's evidence counts are its own; the whole-vault default
/// goal includes every attempt, so single-goal numbers are unchanged.
@riverpod
Future<Map<String, ({int attempts, int contested})>> deckAppliedSummary(
    Ref ref, String deckId) async {
  final memberIdsF = ref.watch(deckMemberCardIdsProvider(deckId).future);
  // The family caches its `attempts()` read, so — like the mock providers — it
  // refreshes off appliedTransfer (invalidated wherever a mock/solve is
  // recorded). Invalidating the wrapper alone wouldn't reach this instance.
  final transferF = ref.watch(appliedTransferProvider.future);
  final indexF = ref.watch(vaultIndexProvider.future);
  final clockF = ref.watch(clockProvider.future);
  final repo = ref.watch(appliedRepositoryProvider);
  await transferF;
  final memberIds = await memberIdsF;
  final index = await indexF;
  final now = (await clockF).now();
  final rows =
      await repo.attempts(since: now.subtract(const Duration(days: 365)));
  final domains = <String>{
    for (final c in index.studyCards)
      if (c.domain != null) c.domain!,
  };
  final out = <String, ({int attempts, int contested})>{};
  for (final r in rows) {
    if (!memberIds.contains(r.cardId)) continue;
    final d = r.domain;
    if (d == null || !domains.contains(d)) continue;
    final prev = out[d] ?? (attempts: 0, contested: 0);
    out[d] = (
      attempts: prev.attempts + 1,
      contested: prev.contested + (r.verified == false ? 1 : 0),
    );
  }
  return out;
}

/// Per-domain applied-evidence counts for the ACTIVE goal — see [deckAppliedSummary].
@riverpod
Future<Map<String, ({int attempts, int contested})>> appliedSummary(
    Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckAppliedSummaryProvider(goal.id).future);
}

/// Resolve a goal by id from an already-loaded list, falling back to the
/// default/first. Pure — the caller watches [decksProvider] up front so there's no
/// ref use after an await (see the note on [deckReadiness]). Shared by the split
/// forecast/feasibility layers (S5f), hence public.
Deck pickDeck(List<Deck> goals, String deckId) =>
    goals.firstWhere((g) => g.id == deckId, orElse: () => goals.first);

/// A deck's **coverage** [ReadinessTarget] — the template's fallback
/// level/context/track, no date. It's the base a deck scores against when no aim
/// is bound (a 0-aim coverage deck); a deck with aims resolves each aim's OWN
/// target instead (S5 — the target lives on the aim, ADR-0006). Byte-identical for
/// a target-less deck, whose slots were always the template fallbacks anyway.
@riverpod
Future<ReadinessTarget> targetForDeck(Ref ref, String deckId) async {
  // Register every dependency synchronously, before any await, so a mid-flight
  // invalidation (e.g. a goal edit/pause rebuilding decks) can't leave us
  // using a disposed ref after the async gap.
  final goalsF = ref.watch(decksProvider.future);
  final registryF = ref.watch(templateRegistryProvider.future);
  final goal = pickDeck(await goalsF, deckId);
  final registry = await registryF;
  return ReadinessTarget.forAim(
      const Aim(), registry.byId(goal.templateId) ?? registry.primary);
}

/// A given goal's effective [Targeting]: its base target combined with its ACTIVE
/// interviews (Phase B — the interviews live on the [Deck] now, so this is
/// uniform across the default and standalone goals). With no active interviews it
/// equals reading the base target directly.
@riverpod
Future<Targeting> targetingForDeck(Ref ref, String deckId) async {
  final goalsF = ref.watch(decksProvider.future);
  final targetF = ref.watch(targetForDeckProvider(deckId).future);
  final goal = pickDeck(await goalsF, deckId);
  final base = await targetF;
  return Targeting(
    base: base,
    aims: [
      for (final iv in goal.aims)
        if (iv.active) iv,
    ],
  );
}

/// The ACTIVE goal's base target — see [targetForDeck].
@riverpod
Future<ReadinessTarget> activeTarget(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(targetForDeckProvider(goal.id).future);
}

/// Whether the active deck has an aim set at all (vs a 0-aim coverage deck on the
/// template fallbacks) — drives the "Set your target" onboarding CTA. Post-S5 the
/// deck is a pure lens with no target slots of its own; **an active aim is the
/// signal** (the migration folded any legacy deck target into a `'target'` aim).
@riverpod
Future<bool> activeTargetIsSet(Ref ref) async =>
    (await ref.watch(activeDeckProvider.future))
        .aims
        .any((a) => a.active && !a.status.isEnded);

/// The ACTIVE goal's targeting — see [targetingForDeck]. Single default goal →
/// identical to [targeting].
@riverpod
Future<Targeting> activeTargeting(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(targetingForDeckProvider(goal.id).future);
}

/// Knowledge-base readiness (Phase A) for a SPECIFIC goal — its member cards
/// scored against its target, from `srs_state` + FSRS stability. The hub reads
/// this per lane; nothing is stored (recomputed, so it persists across devices).
@riverpod
Future<Readiness> deckReadiness(Ref ref, String deckId) async {
  // Watch every dependency synchronously (before the first await): a goal
  // edit/pause rebuilds decks and invalidates this instance, and any
  // ref.watch after an await would then throw "used after disposed".
  final goalsF = ref.watch(decksProvider.future);
  final indexF = ref.watch(vaultIndexProvider.future);
  final statesF = ref.watch(srsStatesProvider.future);
  final targetF = ref.watch(targetForDeckProvider(deckId).future);
  final registryF = ref.watch(templateRegistryProvider.future);
  final appliedF = ref.watch(appliedTransferProvider.future);
  final goal = pickDeck(await goalsF, deckId);
  final index = await indexF;
  final states = await statesF;
  final applied = await appliedF;
  final stabilityByKey = {
    for (final e in states.byKey.entries) e.key: e.value.stability,
  };
  // Scope to the goal's member cards (task #30d, G2); the whole-vault default goal
  // selects everything, so numbers are unchanged. Practice tracks (Algorithms,
  // System Design) count toward readiness via the *transfer* factor, not the
  // recall-coverage denominator — so they don't drag coverage down as unlearned
  // "concept" sections.
  final conceptCards =
      goal.select(index.studyCards).where((c) => !c.isPracticeTrack).toList();
  final domains = <String>{
    for (final c in conceptCards)
      if (c.domain != null) c.domain!,
  };

  // Score each ACTIVE aim on its OWN knobs (durability bar + domain emphasis)
  // against the deck's template, then roll up **weakest-link**: the deck's
  // readiness is its hardest-to-clear aim, never an average that hides a gap (the
  // competing-aims decision — user_stories/index.md). A deck with no active aim
  // scores against its own base target (0-aim coverage-only is a later slice). A
  // single aim reproduces the canonical single-target readiness
  // ([computeReadinessForTarget] — tier + domain weighted), so the headline agrees
  // with the ladder/forecast (S4). (#112 restored the tier weighting the targeting
  // refactor n6535fd9 dropped; invariant #8 holds against that canonical readiness.)
  final registry = await registryF;
  final template = registry.byId(goal.templateId) ?? registry.primary;

  Readiness scoreFor(ReadinessTarget base, Aim? aim) {
    final tg = Targeting(
      base: base,
      aims: aim == null ? const [] : [aim],
    );
    return computeReadiness(
      cards: conceptCards,
      stabilityByKey: stabilityByKey,
      stabilityTarget: tg.stabilityTarget,
      domainWeights: {for (final d in domains) d: tg.weightForDomain(d)},
      // Tier RELEVANCE for this target (the ladder/forecast weight on it too, via
      // computeReadinessForTarget) — peripheral-for-this-target cards barely move
      // readiness. Without it the headline disagreed with the ladder/forecast (#112).
      tierWeights: tierWeightsFor(base),
      transferByDomain: applied.interview ? applied.byDomain : null,
    );
  }

  final activeAims = [
    for (final a in goal.aims)
      if (a.active) a,
  ];
  if (activeAims.isEmpty) return scoreFor(await targetF, null);

  Readiness? binding;
  Aim? bindingAim;
  for (final aim in activeAims) {
    final r = scoreFor(ReadinessTarget.forAim(aim, template), aim);
    if (binding == null || r.overall < binding.overall) {
      binding = r;
      bindingAim = aim;
    }
  }
  // Tag the headline with the binding (weakest-link) aim so the ladder + forecast
  // can follow it and agree with this number (S4).
  return binding!.withBindingAim(bindingAim!.id);
}

/// Knowledge-base readiness for the ACTIVE goal — see [deckReadiness].
@riverpod
Future<Readiness> readiness(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckReadinessProvider(goal.id).future);
}
