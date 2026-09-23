import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/readiness/feasibility.dart';
import 'package:onyx/core/readiness/projection.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/template/deck_template.dart';
import 'package:onyx/core/template/template_registry.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/template.dart';

/// S4b: the per-aim feasibility PROVIDER + the forecast repoint. The heavy FSRS
/// simulation ([readinessForecastFor]) is overridden with controlled forecasts
/// keyed by role, so these test the wiring — role resolution, per-aim date, and
/// "the forecast follows the binding aim" — not the engine (see projection tests).
class _FixedDecks extends Decks {
  _FixedDecks(this._decks);
  final List<Deck> _decks;
  @override
  Future<List<Deck>> build() async => _decks;
}

void main() {
  final today = DateTime(2026, 1, 1);
  final date20 = today.add(const Duration(days: 20));

  final registry = TemplateRegistry(entries: const [
    TemplateEntry(
      rootDir: '',
      config: DeckTemplate(
        id: 'swe',
        target: TargetSpec(
          levels: [
            LevelValue(id: 'senior', label: 'Senior', tierCurve: [1.0])
          ],
          contexts: [
            ContextValue(id: 'faang', label: 'FAANG', stabilityTargetDays: 120)
          ],
          tracks: [
            TrackValue(id: 'backend', label: 'Backend'),
            TrackValue(id: 'frontend', label: 'Frontend'),
          ],
          families: [],
          fallbackLevelId: 'senior',
          fallbackContextId: 'faang',
          fallbackTrackId: 'backend',
        ),
      ),
    ),
  ], primaryId: 'swe');

  ReadinessForecast fc({
    required double start,
    required int perDay,
    required List<PacePoint> curve,
  }) =>
      ReadinessForecast(
        curve: curve,
        currentPerDay: perDay,
        today: today,
        startReadiness: start,
        threshold: 0.75,
      );

  // backend role → makes the date; frontend role → only at a faster pace.
  final onTrack = fc(start: 0.3, perDay: 8, curve: const [PacePoint(8, 10)]);
  final behind = fc(
      start: 0.3,
      perDay: 8,
      curve: const [PacePoint(8, 30), PacePoint(16, 15)]);

  final forecastByTrack =
      readinessForecastForProvider.overrideWith((ref, dims) async {
    switch (dims.track) {
      case Track.backend:
        return onTrack;
      case Track.frontend:
        return behind;
      default:
        return null;
    }
  });

  InterviewRound round(String id, DateTime? d) =>
      InterviewRound(id: id, number: 1, date: d);

  test('per-aim feasibility: each dated aim classified by its own role',
      () async {
    final c = ProviderContainer(overrides: [
      templateRegistryProvider.overrideWith((ref) async => registry),
      forecastByTrack,
      decksProvider.overrideWith(() => _FixedDecks([
            Deck(id: 'g', name: 'G', templateId: 'swe', aims: [
              Aim(id: 'a', trackId: 'backend', rounds: [round('a1', date20)]),
              Aim(id: 'b', trackId: 'frontend', rounds: [round('b1', date20)]),
            ]),
          ])),
    ]);
    addTearDown(c.dispose);
    final list = await c.read(deckAimFeasibilityProvider('g').future);

    expect(list.length, 2);
    expect(list[0].aim.id, 'a');
    expect(list[0].feasibility.status, FeasibilityStatus.onTrack);
    expect(list[1].aim.id, 'b');
    expect(list[1].feasibility.status, FeasibilityStatus.behind);
    expect(list[1].feasibility.requiredPerDay, 16);
  });

  test('an aim with no scheduled round → open-ended (coverage)', () async {
    final c = ProviderContainer(overrides: [
      templateRegistryProvider.overrideWith((ref) async => registry),
      forecastByTrack,
      decksProvider.overrideWith(() => _FixedDecks([
            const Deck(id: 'g', name: 'G', templateId: 'swe', aims: [
              Aim(id: 'o', trackId: 'backend'), // no rounds, no deadline
            ]),
          ])),
    ]);
    addTearDown(c.dispose);
    final list = await c.read(deckAimFeasibilityProvider('g').future);
    expect(list.single.feasibility.status, FeasibilityStatus.openEnded);
  });

  test('muted aims are excluded', () async {
    final c = ProviderContainer(overrides: [
      templateRegistryProvider.overrideWith((ref) async => registry),
      forecastByTrack,
      decksProvider.overrideWith(() => _FixedDecks([
            Deck(id: 'g', name: 'G', templateId: 'swe', aims: [
              Aim(id: 'a', trackId: 'backend', rounds: [round('a1', date20)]),
              Aim(
                  id: 'b',
                  active: false,
                  trackId: 'frontend',
                  rounds: [round('b1', date20)]),
            ]),
          ])),
    ]);
    addTearDown(c.dispose);
    final list = await c.read(deckAimFeasibilityProvider('g').future);
    expect(list.length, 1);
    expect(list.single.aim.id, 'a');
  });

  test('readinessForecast follows the binding aim, not the first aim',
      () async {
    // Marker forecasts: currentPerDay encodes which role was resolved.
    final c = ProviderContainer(overrides: [
      templateRegistryProvider.overrideWith((ref) async => registry),
      activeDeckProvider.overrideWith((ref) async => const Deck(
            id: 'g',
            name: 'G',
            templateId: 'swe',
            aims: [
              Aim(id: 'a', trackId: 'backend'),
              Aim(id: 'b', trackId: 'frontend'),
            ],
          )),
      // The headline binds to the harder (frontend) aim 'b'.
      readinessProvider.overrideWith((ref) async => const Readiness(
            domains: [],
            overall: 0.5,
            low: 0.4,
            high: 0.6,
            bindingAimId: 'b',
          )),
      // Fallback target (backend, marker 111) — must NOT be used when an aim binds.
      activeTargetProvider.overrideWith((ref) async => const ReadinessTarget(
            levelId: 'senior',
            contextId: 'faang',
            trackId: 'backend',
          )),
      readinessForecastForProvider.overrideWith((ref, dims) async => fc(
            start: 0,
            perDay: dims.track == Track.frontend ? 222 : 111,
            curve: const [],
          )),
    ]);
    addTearDown(c.dispose);
    final f = await c.read(readinessForecastProvider.future);
    expect(f?.currentPerDay, 222); // followed aim 'b' (frontend), not 'a'
  });

  test('readinessForecast falls back to the target when no aim binds',
      () async {
    final c = ProviderContainer(overrides: [
      templateRegistryProvider.overrideWith((ref) async => registry),
      activeDeckProvider.overrideWith(
          (ref) async => const Deck(id: 'g', name: 'G', templateId: 'swe')),
      readinessProvider.overrideWith((ref) async => const Readiness(
            domains: [],
            overall: 0.5,
            low: 0.4,
            high: 0.6,
          )), // no bindingAimId
      activeTargetProvider.overrideWith((ref) async => const ReadinessTarget(
            levelId: 'senior',
            contextId: 'faang',
            trackId: 'backend',
          )),
      readinessForecastForProvider.overrideWith((ref, dims) async => fc(
            start: 0,
            perDay: dims.track == Track.backend ? 111 : 999,
            curve: const [],
          )),
    ]);
    addTearDown(c.dispose);
    final f = await c.read(readinessForecastProvider.future);
    expect(f?.currentPerDay, 111); // used the deck's own target role
  });
}
