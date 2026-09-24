import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/deck/deck.dart';
import '../../core/readiness/ladder.dart';
import '../../core/readiness/pace.dart';
import '../../core/readiness/projection.dart';
import '../../core/readiness/readiness.dart';
import '../../core/readiness/target.dart';
import '../../core/template/deck_template.dart';
import 'clock.dart';
import 'decks.dart';
import 'readiness.dart';
import 'srs.dart';
import 'template.dart';
import 'vault.dart';

part 'readiness_forecast.g.dart';

/// The ready-date **forecast** + **ladder** derived layer (split out of
/// `readiness.dart`, S5f): the "when, at your pace, will recall cross the target"
/// projection (per role, memoised) and the level×company ladder gauge. Both follow
/// the deck's **binding aim** so they agree with the headline number.

/// The [ReadinessTarget] of the deck's **binding** (weakest-link) aim — the aim
/// the headline readiness reflects (S2/S4) — so the ladder + ready-date forecast
/// describe the SAME aim as the number. Each aim carries its own knobs now (S5a),
/// resolved via [ReadinessTarget.forAim] (aim slot → template fallback). Falls back
/// to [fallback] (the deck's coverage target) when no aim binds, so a single/no-aim
/// deck is byte-identical (invariant #8).
ReadinessTarget _bindingTarget(Deck goal, Readiness readiness,
    DeckTemplate template, ReadinessTarget fallback) {
  final id = readiness.bindingAimId;
  if (id != null) {
    for (final a in goal.aims) {
      if (a.id == id) return ReadinessTarget.forAim(a, template);
    }
  }
  return fallback;
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

/// The (deck + role) a forecast is computed against. A value-equal record so
/// [readinessForecastForProvider] memoises per deck+role — aims in the SAME deck
/// sharing a role (e.g. two "senior · faang · backend" loops) reuse one simulation,
/// while two DECKS at the same role keep SEPARATE forecasts (their card sets differ
/// — the per-deck scoping, #113).
typedef ForecastDims = ({
  String deckId,
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
    deckId: goal.id,
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
  final decksF = ref.watch(decksProvider.future);
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  final today = (await ref.watch(clockProvider.future)).today();
  // Scope to the [dims.deckId] deck (NOT necessarily the active one) so a non-active
  // lane's forecast/feasibility is computed over ITS OWN members (#113). Forecast
  // against that deck's OWN template (#30d multi-template).
  final goal = pickDeck(await decksF, dims.deckId);
  final registry = await registryF;
  final target = ReadinessTarget.of(
    level: dims.level,
    company: dims.company,
    track: dims.track,
    templateTarget: registry.byId(goal.templateId)?.target,
  );

  // The deck's concept cards — practice tracks feed readiness via transfer, not
  // recall coverage (matches the readiness provider; task #30d, G2).
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

/// Coverage pace toward the soonest interview date (an active interview round),
/// or null when nothing is scheduled. Projects from the recent
/// new-sections-per-day rate over a 14-day window.
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
