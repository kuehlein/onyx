import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/plan/practice_plan.dart';
import 'package:onyx/core/template/active_template.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/daily_plan.dart';
import 'package:onyx/shared/providers/practice_plan.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/vault.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// See database_test.dart — skip when host libsqlite3 is unavailable.
final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

/// Loads the real `korean-vault/` through the full provider graph and proves the
/// config vault-driven **conversation** mock flow (skill authored in the vault)
/// enters the daily plan as its own practice track — task #30 G2a, zero code
/// changes for the subject. The registry provider sets `activeTemplate` to Korean
/// as a side effect of indexing; tearDown restores the SWE default.
void main() {
  group('config vault mock flow → daily-plan track', () {
    tearDown(() => activeTemplate = softwareInterviewsTemplate);

    ProviderContainer container() => ProviderContainer(
          overrides: [
            vaultSourceProvider
                .overrideWithValue(DesktopVaultSource('korean-vault')),
            appDatabaseProvider.overrideWith((ref) {
              final db = AppDatabase.withExecutor(NativeDatabase.memory());
              ref.onDispose(db.close);
              return db;
            }),
          ],
        );

    test('emits a conversation track containing the order-water card',
        () async {
      final c = container();
      addTearDown(c.dispose);

      // Keep the availability subtree mounted (as a mounted UI would) so its async
      // deps aren't autodisposed mid-build when the registry-driven invalidations
      // (activeTemplate → Korean) settle across the queue providers.
      c.listen(practiceAvailabilityProvider, (_, __) {});

      final avail = await c.read(practiceAvailabilityProvider.future);

      // The four in-code SWE tracks plus one config vault mock flow.
      final byTrack = {for (final a in avail) a.track: a};
      expect(byTrack.keys, containsAll(<String>[kTrackReview, kTrackLearn]));

      final convo = byTrack['conversation'];
      expect(convo, isNotNull,
          reason: 'the vault conversation flow should yield a track');
      expect(convo!.label, 'Conversation');
      expect(convo.units.map((u) => u.id), contains('order-water'));

      // Whole-card unit (noSections mock flow), generic mock estimate.
      final unit = convo.units.firstWhere((u) => u.id == 'order-water');
      expect(unit.track, 'conversation');
      expect(unit.label, 'Order water at a café');
      expect(unit.estMinutes, kMockMinutes);
    });

    test('the conversation flow gates in the daily plan on its depends-on',
        () async {
      final c = container();
      addTearDown(c.dispose);
      c.listen(dailyPlanProvider, (_, __) {});

      final plan = await c.read(dailyPlanProvider.future);

      // Fresh state: the conversation's vocabulary prerequisites (its
      // `depends-on`) aren't comfortable, so the config practice flow is LOCKED
      // in the plan — parity with SWE system-design/algorithms. Proves the
      // general depends-on field now drives daily-plan gating, not just the
      // FlowRunner's screen-entry soft gate (task #30, G6).
      expect(plan.locked.map((t) => t.track), contains('conversation'));
      expect(plan.tracks.map((t) => t.track), isNot(contains('conversation')));
    });

    test('readiness computes config-only over the Korean deck domains',
        () async {
      final c = container();
      addTearDown(c.dispose);
      c.listen(readinessProvider, (_, __) {});

      final r = await c.read(readinessProvider.future);

      // Readiness resolves for the config subject over ITS domains (drawn from
      // the Korean cards' tags), and never assumes SWE domains — the readiness
      // math is fully config-driven (task #30, G6 acceptance).
      final domains = r.domains.map((d) => d.domain).toSet();
      expect(domains, isNotEmpty);
      expect(
          domains,
          everyElement(
              isIn(<String>{'hangul', 'vocabulary', 'grammar', 'culture'})));
      expect(domains, isNot(contains('ds-a')));
      expect(domains, isNot(contains('system-design')));
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
