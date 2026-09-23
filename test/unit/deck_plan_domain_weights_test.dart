import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/readiness/feasibility.dart';
import 'package:onyx/core/template/deck_template.dart';
import 'package:onyx/core/template/template_registry.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/template.dart';
import 'package:onyx/shared/providers/vault.dart';

/// S3b: the urgency-weighted domain emphasis the daily plan allocates on
/// (ADR-0007). The per-aim feasibility is injected, so this tests the combination
/// (normalized urgency-weighted average of each aim's own-track weight + boost),
/// not the forecast engine.
class _FixedDecks extends Decks {
  _FixedDecks(this._decks);
  final List<Deck> _decks;
  @override
  Future<List<Deck>> build() async => _decks;
}

class _FixedClock extends Clock {
  _FixedClock(this._fixed);
  final DateTime _fixed;
  @override
  DateTime now() => _fixed;
}

void main() {
  // A minimal template: no domain families → every domain weighs 1.0, so the only
  // differentiation is the aims' explicit boosts scaled by urgency.
  final registry = TemplateRegistry(entries: const [
    TemplateEntry(
      rootDir: '',
      config: DeckTemplate(
        id: 'swe',
        target: TargetSpec(
          levels: [
            LevelValue(id: 'l', label: 'L', tierCurve: [1.0])
          ],
          contexts: [
            ContextValue(id: 'c', label: 'C', stabilityTargetDays: 90)
          ],
          tracks: [TrackValue(id: 't', label: 'T')],
          families: [],
          fallbackLevelId: 'l',
          fallbackContextId: 'c',
          fallbackTrackId: 't',
        ),
      ),
    ),
  ], primaryId: 'swe');

  const index = IndexResult(
    cards: [
      Card(
        id: 'x',
        type: 'flashcard',
        title: 'X',
        overview: '',
        tags: ['sd'], // domain = first tag
        tiers: {},
        sections: [
          CardSection(heading: 'D', slug: 'd', content: 'x', quizzable: true)
        ],
        wikilinks: [],
        filePath: 'x.md',
      ),
      Card(
        id: 'y',
        type: 'flashcard',
        title: 'Y',
        overview: '',
        tags: ['ui'],
        tiers: {},
        sections: [
          CardSection(heading: 'D', slug: 'd', content: 'y', quizzable: true)
        ],
        wikilinks: [],
        filePath: 'y.md',
      ),
    ],
    idless: 0,
    malformed: 0,
    skipped: 0,
  );

  ProviderContainer container(
    List<({Aim aim, AimFeasibility feasibility})> feas,
  ) {
    final c = ProviderContainer(overrides: [
      templateRegistryProvider.overrideWith((ref) async => registry),
      vaultIndexProvider.overrideWith((ref) async => index),
      clockProvider
          .overrideWith((ref) async => _FixedClock(DateTime(2026, 1, 1))),
      decksProvider.overrideWith(() =>
          _FixedDecks(const [Deck(id: 'g', name: 'G', templateId: 'swe')])),
      deckAimFeasibilityProvider.overrideWith((ref, deckId) async => feas),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  final farDate = DateTime(2026, 7, 1); // >60d out → behind sits at its floor

  test('urgency tilts emphasis toward the behind aim\'s domain', () async {
    // Backend aim BEHIND (urgency 0.6) boosts sd; frontend aim ON TRACK (0.3)
    // boosts ui → sd should outweigh ui even though both boost by the same amount.
    final c = container([
      (
        aim: const Aim(id: 'a', domainWeights: {'sd': 1.0}),
        feasibility:
            AimFeasibility(status: FeasibilityStatus.behind, date: farDate)
      ),
      (
        aim: const Aim(id: 'b', domainWeights: {'ui': 1.0}),
        feasibility:
            AimFeasibility(status: FeasibilityStatus.onTrack, date: farDate)
      ),
    ]);
    final w = await c.read(deckPlanDomainWeightsProvider('g').future);
    expect(w['sd']!, greaterThan(w['ui']!));
    // shares: behind 0.6 / total 0.9 = 0.667, onTrack 0.333.
    expect(w['sd']!, closeTo(0.667 * 2 + 0.333 * 1, 0.01)); // 1.667
    expect(w['ui']!, closeTo(0.667 * 1 + 0.333 * 2, 0.01)); // 1.333
  });

  test('single aim → its own weights (byte-identical: urgency share is 1)',
      () async {
    final c = container([
      (
        aim: const Aim(id: 'a', domainWeights: {'sd': 1.0}),
        feasibility:
            AimFeasibility(status: FeasibilityStatus.behind, date: farDate)
      ),
    ]);
    final w = await c.read(deckPlanDomainWeightsProvider('g').future);
    // Matches the pre-S3 weightForDomain (base 1.0 + boost) exactly.
    expect(w['sd'], 2.0);
    expect(w['ui'], 1.0);
  });

  test('no active aim → the deck base target weights (byte-identical)',
      () async {
    final c = container(const []);
    final w = await c.read(deckPlanDomainWeightsProvider('g').future);
    expect(w['sd'], 1.0);
    expect(w['ui'], 1.0);
  });
}
