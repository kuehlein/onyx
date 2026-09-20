import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/plan/practice_plan.dart';
import 'package:onyx/core/subject/active_subject.dart';
import 'package:onyx/core/subject/software_interviews.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/practice_plan.dart';
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
/// changes for the subject. The registry provider sets `activeSubject` to Korean
/// as a side effect of indexing; tearDown restores the SWE default.
void main() {
  group('config vault mock flow → daily-plan track', () {
    tearDown(() => activeSubject = softwareInterviewsConfig);

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
      // (activeSubject → Korean) settle across the queue providers.
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
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
