import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/interview/critic.dart';
import '../../core/interview/transfer.dart';
import '../../core/readiness/feasibility.dart';
import '../../core/readiness/ladder.dart';
import '../../core/readiness/pace.dart';
import '../../core/readiness/projection.dart';
import '../../core/readiness/readiness.dart';
import '../../core/readiness/target.dart';
import '../../core/readiness/targeting.dart';
import '../../core/deck/deck.dart';
import '../../core/template/deck_template.dart';
import 'clock.dart';
import 'interview.dart';
import 'srs.dart';
import 'decks.dart';
import 'template.dart';
import 'vault.dart';

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
/// default/first. (Pure — the caller watches [decksProvider] up front so
/// there's no ref use after an await; see the note on [deckReadiness].)
Deck _pick(List<Deck> goals, String deckId) =>
    goals.firstWhere((g) => g.id == deckId, orElse: () => goals.first);

/// A single [aim]'s effective [ReadinessTarget] within [goal]: the aim's own knobs
/// (S1), falling back to the deck's slots (transitional until the slots move onto
/// aims in S5) then the template's fallbacks — so a lone inherited aim resolves
/// exactly as the deck's own target did. Readiness, the ready-date forecast, and
/// feasibility all resolve an aim through here, so the headline number, the ladder,
/// and the forecast describe the SAME aim (S4).
ReadinessTarget _aimTarget(Aim aim, Deck goal, DeckTemplate template) =>
    ReadinessTarget.forAim(
      aim.copyWith(
        levelId: aim.levelId ?? goal.levelId,
        contextId: aim.contextId ?? goal.contextId,
        trackId: aim.trackId ?? goal.trackId,
      ),
      template,
    );

/// The [ReadinessTarget] of the deck's **binding** (weakest-link) aim — the aim
/// the headline readiness reflects (S2/S4) — so the ladder + ready-date forecast
/// describe the SAME aim as the number. Falls back to [fallback] (the deck's own
/// target) when no aim binds (a coverage-only deck), so a single/no-aim deck is
/// byte-identical (invariant #8).
ReadinessTarget _bindingTarget(Deck goal, Readiness readiness,
    DeckTemplate template, ReadinessTarget fallback) {
  final id = readiness.bindingAimId;
  if (id != null) {
    for (final a in goal.aims) {
      if (a.id == id) return _aimTarget(a, goal, template);
    }
  }
  return fallback;
}

/// A given goal's base [ReadinessTarget] (task #30d). Every goal — including the
/// whole-vault default — carries its own level/context/track (+ deadline); the
/// default's were seeded from the legacy saved target on first run
/// ([migratedDefaultDeck]) and are edited through [Decks] like any goal's.
///
/// NOTE (#30d multi-template): [deckReadiness] now scores each goal against its
/// OWN template (durability bar + domain weights). The remaining sliver:
/// readinessLadderPosition/readinessForecast/readinessPace (single-goal-Home
/// surfaces, via ladder.dart + projection.dart) still read the process-global
/// activeTemplate — correct for the default/active goal on the primary template;
/// thread the goal's DeckTemplate there too when a focused non-default goal needs
/// its own ladder/forecast.
@riverpod
Future<ReadinessTarget> targetForDeck(Ref ref, String deckId) async {
  // Register every dependency synchronously, before any await, so a mid-flight
  // invalidation (e.g. a goal edit/pause rebuilding decks) can't leave us
  // using a disposed ref after the async gap.
  final goalsF = ref.watch(decksProvider.future);
  final registryF = ref.watch(templateRegistryProvider.future);
  final goal = _pick(await goalsF, deckId);
  final registry = await registryF;
  return goal.toTarget(registry.byId(goal.templateId) ?? registry.primary);
}

/// A given goal's effective [Targeting]: its base target combined with its ACTIVE
/// interviews (Phase B — the interviews live on the [Deck] now, so this is
/// uniform across the default and standalone goals). With no active interviews it
/// equals reading the base target directly.
@riverpod
Future<Targeting> targetingForDeck(Ref ref, String deckId) async {
  final goalsF = ref.watch(decksProvider.future);
  final targetF = ref.watch(targetForDeckProvider(deckId).future);
  final goal = _pick(await goalsF, deckId);
  final base = await targetF;
  return Targeting(
    base: base,
    aims: [
      for (final iv in goal.aims)
        if (iv.active) iv,
    ],
    deckId: goal.id,
    deadline: goal.deadline,
  );
}

/// The ACTIVE goal's base target — see [targetForDeck].
@riverpod
Future<ReadinessTarget> activeTarget(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(targetForDeckProvider(goal.id).future);
}

/// Whether the active goal has an explicitly-chosen target (vs the template's
/// fallbacks) — drives the "Set your target" onboarding CTA. [activeTarget] always
/// resolves null slots to fallbacks, so it can't answer this; the goal's null
/// slots are the signal (Save writes all three together, so `levelId` is a
/// faithful proxy).
@riverpod
Future<bool> activeTargetIsSet(Ref ref) async =>
    (await ref.watch(activeDeckProvider.future)).levelId != null;

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
  final goal = _pick(await goalsF, deckId);
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
  // single aim reproduces the pre-S2 single-target readiness (invariant #8).
  final registry = await registryF;
  final template = registry.byId(goal.templateId) ?? registry.primary;

  Readiness scoreFor(ReadinessTarget base, Aim? aim) {
    final tg = Targeting(
      base: base,
      aims: aim == null ? const [] : [aim],
      deckId: goal.id,
      deadline: goal.deadline,
    );
    return computeReadiness(
      cards: conceptCards,
      stabilityByKey: stabilityByKey,
      stabilityTarget: tg.stabilityTarget,
      domainWeights: {for (final d in domains) d: tg.weightForDomain(d)},
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
    final r = scoreFor(_aimTarget(aim, goal, template), aim);
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

/// Where the current knowledge base sits on the level×company ladder relative
/// to the chosen goal — the "you are here vs. aiming here" gauge. Recomputes
/// from the same cards + FSRS stability, scored against every rung. Follows the
/// **binding aim** so the "aiming here" rung agrees with the headline (S4c).
@riverpod
Future<LadderPosition> readinessLadderPosition(Ref ref) async {
  // Register deps synchronously (before the first await) so a mid-flight
  // invalidation can't leave us watching through a disposed ref.
  final indexF = ref.watch(vaultIndexProvider.future);
  final statesF = ref.watch(srsStatesProvider.future);
  final appliedF = ref.watch(appliedTransferProvider.future);
  final goalF = ref.watch(activeDeckProvider.future);
  final readinessF = ref.watch(readinessProvider.future);
  final registryF = ref.watch(templateRegistryProvider.future);
  final targetF = ref.watch(activeTargetProvider.future);
  final index = await indexF;
  final states = await statesF;
  final applied = await appliedF;
  final goal = await goalF;
  final registry = await registryF;
  final template = registry.byId(goal.templateId) ?? registry.primary;
  final target =
      _bindingTarget(goal, await readinessF, template, await targetF);
  final stabilityByKey = {
    for (final e in states.byKey.entries) e.key: e.value.stability,
  };
  return computeLadderPosition(
    // The active goal's concept cards — practice tracks feed readiness via
    // transfer, not coverage (task #30d, G2).
    cards:
        goal.select(index.studyCards).where((c) => !c.isPracticeTrack).toList(),
    stabilityByKey: stabilityByKey,
    target: target,
    transferByDomain: applied.interview ? applied.byDomain : null,
  );
}

/// The role dimensions a forecast is computed against. A value-equal record so
/// [readinessForecastForProvider] memoises per role — interviews sharing a role
/// (e.g. two "senior · faang · backend" loops) reuse a single simulation.
typedef ForecastDims = ({
  SeniorityLevel level,
  CompanyTier company,
  Track track,
});

/// Projected "ready date" forecast (#49) for the SAVED top-of-form target: at
/// the recent pace, when relevance-weighted recall readiness crosses the target,
/// plus chill/current/push scenarios. Delegates to [readinessForecastForProvider]
/// so the calendar (top target) and per-interview chips (their own role) share
/// the same engine.
@riverpod
Future<ReadinessForecast?> readinessForecast(Ref ref) async {
  // Follow the binding (weakest-link) aim so Home's headline readiness and its
  // ready-date forecast describe the SAME aim (S4) — else "62% ready, ready by
  // March" could name two different aims. With no active aim (a coverage-only
  // deck) fall back to the deck's own target role. Degrades byte-identically for a
  // single/no-aim deck (invariant #8): the binding aim IS the deck's target.
  // Register deps synchronously; only the final forecast is watched post-await.
  final goalF = ref.watch(activeDeckProvider.future);
  final readinessF = ref.watch(readinessProvider.future);
  final registryF = ref.watch(templateRegistryProvider.future);
  final targetF = ref.watch(activeTargetProvider.future);
  final goal = await goalF;
  final registry = await registryF;
  final template = registry.byId(goal.templateId) ?? registry.primary;
  final target =
      _bindingTarget(goal, await readinessF, template, await targetF);
  return ref.watch(readinessForecastForProvider((
    level: target.level,
    company: target.company,
    track: target.track,
  )).future);
}

/// Projected "ready date" forecast for an ARBITRARY role — the per-interview
/// judgement lever. Same maturation model as above, weighted toward [dims]'s
/// level/company/track, so a junior · non-faang loop can read "needs a faster
/// pace" on a date the senior · faang target calls "too soon". Recall-only
/// maturation (mocks are a separate axis). Returns null with no concept cards.
/// Heavier than the other providers (a forward FSRS simulation), so it's
/// memoised per role and only recomputed when its inputs change.
@riverpod
Future<ReadinessForecast?> readinessForecastFor(
    Ref ref, ForecastDims dims) async {
  final registryF =
      ref.watch(templateRegistryProvider.future); // register first
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  final today = (await ref.watch(clockProvider.future)).today();
  final goal = await ref.watch(activeDeckProvider.future);
  // Forecast against the active goal's OWN template (#30d multi-template); the
  // dims record stays role-only so the per-role memoisation + external callers are
  // unchanged.
  final registry = await registryF;
  final target = ReadinessTarget.of(
    level: dims.level,
    company: dims.company,
    track: dims.track,
    templateTarget: registry.byId(goal.templateId)?.target,
  );

  // The active goal's concept cards — practice tracks feed readiness via transfer,
  // not recall coverage (matches the readiness provider; task #30d, G2).
  final cards =
      goal.select(index.studyCards).where((c) => !c.isPracticeTrack).toList();
  if (cards.isEmpty) return null;

  final stateByKey = {
    for (final e in states.byKey.entries)
      e.key: SectionSrsState(
        stability: e.value.stability,
        difficulty: e.value.difficulty,
        state: e.value.state,
        step: e.value.step,
        due: e.value.dueAt,
        lastReview: e.value.lastReview,
      ),
  };

  // Recent new-sections/day, computed like readinessPace. With no history yet,
  // assume a standard daily plan so we can still show an outlook.
  const window = 14;
  final repo = ref.watch(srsRepositoryProvider);
  final started = await repo
      .sectionsStartedSince(today.subtract(const Duration(days: window)));
  final first = await repo.firstLearnDate();
  final historyDays = first == null
      ? window
      : today.difference(DateTime(first.year, first.month, first.day)).inDays;
  final denom = historyDays.clamp(1, window);
  var perDay = (started / denom).round();
  if (perDay < 1) perDay = 8;

  final c = projectPaceCurve(
    cards: cards,
    stateByKey: stateByKey,
    target: target,
    currentPerDay: perDay,
    today: today,
  );
  return ReadinessForecast(
    curve: c.curve,
    currentPerDay: perDay,
    today: today,
    startReadiness: c.startReadiness,
    threshold: 0.75,
  );
}

/// Per-aim feasibility (S4b) for a deck's ACTIVE aims — for each dated aim, "can
/// you be durably ready by its date at the current pace?", classified from the
/// aim's own [ReadinessForecast] (its role + durability bar) vs that date. An aim
/// with no scheduled round reports [FeasibilityStatus.openEnded] (judged by
/// coverage, not a ready-by). Returned in the deck's active-aim order, each paired
/// with its [Aim] so consumers can name/allocate it. The daily plan weights
/// urgency on this (S3), the coach warns from it (#103 — infeasible = the
/// incoherent-cram case), and the Aims surface shows it per aim (S5).
///
/// The forecast substrate ([readinessForecastFor]) is scoped to the ACTIVE deck's
/// cards (the documented single-goal-Home sliver noted on [targetForDeck]), so
/// this is exact for the active deck; a non-active deck inherits that same sliver
/// until the forecast is threaded per-deck.
@riverpod
Future<List<({Aim aim, AimFeasibility feasibility})>> deckAimFeasibility(
    Ref ref, String deckId) async {
  final goalsF = ref.watch(decksProvider.future);
  final registryF = ref.watch(templateRegistryProvider.future);
  final goal = _pick(await goalsF, deckId);
  final registry = await registryF;
  final template = registry.byId(goal.templateId) ?? registry.primary;

  final out = <({Aim aim, AimFeasibility feasibility})>[];
  for (final aim in goal.aims) {
    if (!aim.active) continue;
    final date = aim.currentRound(goal.id, goal.deadline)?.date;
    if (date == null) {
      // Open-ended aim → coverage, not a ready-by (no forecast needed).
      out.add((aim: aim, feasibility: classifyAimFeasibility(date: null)));
      continue;
    }
    final t = _aimTarget(aim, goal, template);
    final forecast = await ref.watch(readinessForecastForProvider((
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

/// Coverage pace toward the soonest interview date (the goal's deadline or an
/// active interview round), or null when nothing is scheduled. Projects from the
/// recent new-sections-per-day rate over a 14-day window.
@riverpod
Future<PaceEstimate?> readinessPace(Ref ref) async {
  final date = (await ref.watch(activeTargetingProvider.future)).governingDate;
  if (date == null) return null;

  final r = await ref.watch(readinessProvider.future);
  final remaining = r.domains.fold(0, (a, d) => a + (d.total - d.studied));

  const window = 14;
  final today = (await ref.watch(clockProvider.future)).today();
  final repo = ref.watch(srsRepositoryProvider);
  final started = await repo
      .sectionsStartedSince(today.subtract(const Duration(days: window)));
  // Average over the ACTUAL days of history (capped at the window), not a flat
  // 14 — otherwise a short history (e.g. 5 days in) reads at a fraction of its
  // real daily rate and falsely trips "behind".
  final first = await repo.firstLearnDate();
  final historyDays = first == null
      ? window
      : today.difference(DateTime(first.year, first.month, first.day)).inDays;
  final denom = historyDays.clamp(1, window);

  return computePace(
    today: today,
    interviewDate: DateTime(date.year, date.month, date.day),
    remainingSections: remaining,
    recentPerDay: started / denom,
  );
}
