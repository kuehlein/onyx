import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/interview/critic.dart';
import '../../core/interview/transfer.dart';
import '../../core/readiness/ladder.dart';
import '../../core/readiness/pace.dart';
import '../../core/readiness/projection.dart';
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
    interviews: [
      for (final iv in goal.interviews)
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
  final targetingF = ref.watch(targetingForDeckProvider(deckId).future);
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

  // Score against the goal's OWN template (durability bar + domain weights). The
  // default goal keeps the full targeting (base target + active interview boosts,
  // primary template); any other goal uses its template's TargetSpec directly, so
  // a Korean goal isn't scored with SWE's durability/weights (multi-template).
  final double stabilityTarget;
  final Map<String, double> domainWeights;
  if (goal.id == defaultDeckId) {
    final targeting = await targetingF;
    stabilityTarget = targeting.stabilityTarget;
    domainWeights = {for (final d in domains) d: targeting.weightForDomain(d)};
  } else {
    final registry = await registryF;
    final spec = (registry.byId(goal.templateId) ?? registry.primary).target;
    final t = await targetF;
    stabilityTarget = spec.stabilityTargetDays(t.contextId);
    domainWeights = {
      for (final d in domains) d: spec.domainWeight(t.trackId, d),
    };
  }

  return computeReadiness(
    cards: conceptCards,
    stabilityByKey: stabilityByKey,
    stabilityTarget: stabilityTarget,
    domainWeights: domainWeights,
    transferByDomain: applied.interview ? applied.byDomain : null,
  );
}

/// Knowledge-base readiness for the ACTIVE goal — see [deckReadiness].
@riverpod
Future<Readiness> readiness(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckReadinessProvider(goal.id).future);
}

/// Where the current knowledge base sits on the level×company ladder relative
/// to the chosen goal — the "you are here vs. aiming here" gauge. Recomputes
/// from the same cards + FSRS stability, scored against every rung.
@riverpod
Future<LadderPosition> readinessLadderPosition(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  final target = await ref.watch(activeTargetProvider.future);
  final applied = await ref.watch(appliedTransferProvider.future);
  final goal = await ref.watch(activeDeckProvider.future);
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
  final target = await ref.watch(activeTargetProvider.future);
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
