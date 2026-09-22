import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/template/active_template.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/flow_runner.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/vault.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// Resolves [flowRunnerContext] over the real `korean-vault/` through the full
/// provider graph (mirrors korean_vault_test's loader + config_flow_availability's
/// container). Proves the config `conversation` flow's screen context: the vault
/// skill loads, and the `depends-on` competence gate + covered frontier track the
/// same per-concept comfort the daily plan uses. Gate on the host libsqlite3 like
/// the other DB-backed provider tests.
final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

void main() {
  group('flowRunnerContext over the real korean-vault', () {
    final source = DesktopVaultSource('korean-vault');
    late List<Card> cards;

    setUp(() async {
      cards = [
        for (final path in await source.listCardPaths())
          if (const CardParser()
                  .parse(await source.readCard(path), filePath: path)
              case final c?)
            c,
      ];
    });
    tearDown(() => activeTemplate = softwareInterviewsTemplate);

    // Seed comfort for a whole concept card: SRS state on every quizzable
    // section → comfort 1.0 (> the 0.7 flow bar). Keyed `<id>::<slug>` exactly
    // as flowRunnerContext computes it.
    Map<String, SrsState> studiedFully(Iterable<String> conceptIds) {
      final byId = {for (final c in cards) c.id: c};
      final out = <String, SrsState>{};
      for (final id in conceptIds) {
        for (final s in byId[id]!.quizzableSections) {
          out['$id::${s.slug}'] = SrsState(
            cardId: id,
            sectionSlug: s.slug,
            stability: 100,
            difficulty: 5,
            state: 2,
            dueAt: DateTime(2026),
            reviewCount: 1,
          );
        }
      }
      return out;
    }

    ProviderContainer container(Map<String, SrsState> states) =>
        ProviderContainer(overrides: [
          vaultSourceProvider.overrideWithValue(source),
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase.withExecutor(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          srsStatesProvider.overrideWith((ref) async => SectionStates(states)),
        ]);

    test('loads the vault skill and locks the gate with nothing studied',
        () async {
      final c = container(const {});
      addTearDown(c.dispose);
      // Keep the graph mounted while the registry-driven invalidations settle.
      c.listen(flowRunnerContextProvider('order-water'), (_, __) {});

      final ctx = await c.read(flowRunnerContextProvider('order-water').future);

      // The card + flow resolved, and the vault-authored server persona loaded.
      expect(ctx.card, isNotNull);
      expect(ctx.card!.id, 'order-water');
      expect(ctx.flow?.cardType, 'conversation');
      expect(ctx.skill, isNotNull);
      expect(ctx.skill, contains('café')); // the vault persona

      // Nothing studied → gate locked, ALL four word prereqs still weak, and the
      // covered frontier is empty (the AI may draw on nothing).
      expect(ctx.gate.unlocked, isFalse);
      expect(
          ctx.gate.weak,
          containsAll(<String>[
            'word-hello',
            'word-water',
            'word-please-give',
            'word-thankyou',
          ]));
      expect(ctx.frontier, isEmpty);
      // Friendly labels resolve to the card titles (romanized headings).
      expect(ctx.weakLabels['word-water'], contains('mul'));
    }, skip: _sqliteAvailable ? false : 'libsqlite3 unavailable');

    test('seeding comfort on the prerequisites unlocks it', () async {
      // Three of the four words fully studied → 3/4 = 0.75 ≥ 0.6 → unlocked.
      final c = container(
          studiedFully(const ['word-hello', 'word-water', 'word-please-give']));
      addTearDown(c.dispose);
      c.listen(flowRunnerContextProvider('order-water'), (_, __) {});

      final ctx = await c.read(flowRunnerContextProvider('order-water').future);

      expect(ctx.gate.unlocked, isTrue);
      // The frontier is exactly the covered words the AI may use.
      expect(ctx.frontier, {'word-hello', 'word-water', 'word-please-give'});
      // The one un-studied word is neither satisfied nor in the frontier.
      expect(ctx.gate.weak, ['word-thankyou']);
    }, skip: _sqliteAvailable ? false : 'libsqlite3 unavailable');

    test('a missing card id yields a null-card context', () async {
      final c = container(const {});
      addTearDown(c.dispose);
      c.listen(flowRunnerContextProvider('does-not-exist'), (_, __) {});

      final ctx =
          await c.read(flowRunnerContextProvider('does-not-exist').future);
      expect(ctx.card, isNull);
      expect(ctx.skill, isNull);
      expect(ctx.gate.unlocked, isTrue); // no deps → not gated
    }, skip: _sqliteAvailable ? false : 'libsqlite3 unavailable');
  });
}
