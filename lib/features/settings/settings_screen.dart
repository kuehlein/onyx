import 'dart:io' show Platform;

// Material's `Card` widget collides with our domain `Card` model (used by the
// dev interview-seeding action); we don't render a Material Card here.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/claude_service.dart';
import '../../core/clock.dart';
import '../../core/dev.dart';
import '../../core/interview/assessment.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/analytics.dart';
import '../../shared/providers/backup.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/database.dart';
import '../../shared/providers/interview.dart';
import '../../shared/providers/learn.dart';
import '../../shared/providers/coach_update.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/settings.dart';
import '../../shared/status_colors.dart';
import '../../shared/widgets/destructive_row.dart';
import '../home/goal_editor_sheet.dart';
import 'api_key_sheet.dart';
import 'study_load_help.dart';
import '../../shared/providers/srs.dart';
import '../../shared/providers/vault.dart';

/// App settings. Vault selection, the Claude API key (iOS Keychain via
/// flutter_secure_storage), and theme land here. For now it reports the
/// resolved vault so the dev ONYX_VAULT_PATH wiring is visible.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(vaultSourceProvider);
    final index = ref.watch(vaultIndexProvider);
    final apiKey = ref.watch(apiKeyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Vault'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Source'),
            subtitle: Text(source?.rootLabel ?? 'Not configured'),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Indexed cards'),
            subtitle: Text(index.when(
              loading: () => 'Indexing…',
              error: (e, _) => 'Error: $e',
              data: (r) => '${r.cardCount} cards'
                  '${r.idless > 0 ? ' · ${r.idless} missing id' : ''}'
                  '${r.malformed > 0 ? ' · ${r.malformed} malformed' : ''}',
            )),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(vaultIndexProvider),
            ),
          ),
          const _SectionHeader('Learning'),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Study goals'),
            subtitle: const Text(
                'Define subjects/focuses to study concurrently — they share '
                'your daily time.'),
            onTap: () => showGoalsManager(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('How much should I study?'),
            subtitle: const Text(
                'What the daily levers mean + a start-slow ramp plan.'),
            onTap: () => showStudyLoadHelp(context),
          ),
          ref.watch(dailyTargetMinutesProvider).when(
                loading: () => const ListTile(
                  leading: Icon(Icons.schedule_outlined),
                  title: Text('Daily study time'),
                  subtitle: Text('Loading…'),
                ),
                error: (e, _) => ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Daily study time'),
                  subtitle: Text('Error: $e'),
                ),
                data: (target) => ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Daily study time'),
                  subtitle: Text(
                      '${_prettyMinutes(target)} target — the day\'s plan across '
                      'all tracks. It eases in from shorter sessions and ramps to '
                      'this as the habit sticks; new learning tapers near an '
                      'interview.'),
                  trailing: _Stepper(
                    value: target,
                    min: DailyTargetMinutes.min,
                    max: DailyTargetMinutes.max,
                    step: DailyTargetMinutes.step,
                    onChanged: (v) =>
                        ref.read(dailyTargetMinutesProvider.notifier).set(v),
                  ),
                ),
              ),
          ref.watch(loadCheckInProvider).when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (checkIn) => SwitchListTile(
                  secondary: const Icon(Icons.favorite_outline),
                  title: const Text('Weekly load check-in'),
                  subtitle: const Text(
                      'Once a week the coach asks how the load feels and uses '
                      'your answer to tune what it suggests.'),
                  value: checkIn.enabled,
                  onChanged: (v) =>
                      ref.read(loadCheckInProvider.notifier).setEnabled(v),
                ),
              ),
          ref.watch(newCardLimitProvider).when(
                loading: () => const ListTile(
                  leading: Icon(Icons.auto_stories_outlined),
                  title: Text('New sections per day'),
                  subtitle: Text('Loading…'),
                ),
                error: (e, _) => ListTile(
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: const Text('New sections per day'),
                  subtitle: Text('Error: $e'),
                ),
                data: (limit) => ListTile(
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: const Text('New sections per day'),
                  subtitle: Text(
                      '$limit new per day — ${_loadLabel(limit)}. Once you\'ve '
                      'learned this many, new material waits until tomorrow. '
                      'Fewer means stronger retention; more covers ground faster '
                      'but raises cognitive load.'),
                  trailing: _Stepper(
                    value: limit,
                    onChanged: (v) =>
                        ref.read(newCardLimitProvider.notifier).set(v),
                  ),
                ),
              ),
          const _SectionHeader('Pace planner'),
          const _PacePlanner(),
          const _SectionHeader('Algorithms'),
          const _AlgoDailySetting(),
          const _SectionHeader('Gym mode'),
          ...ref.watch(gymModeProvider).when(
                loading: () => const [
                  ListTile(
                      leading: Icon(Icons.fitness_center_outlined),
                      title: Text('Gym mode'),
                      subtitle: Text('Loading…')),
                ],
                error: (e, _) => [
                  ListTile(
                      leading: const Icon(Icons.fitness_center_outlined),
                      title: const Text('Gym mode'),
                      subtitle: Text('Error: $e')),
                ],
                data: (gym) => [
                  SwitchListTile(
                    secondary: const Icon(Icons.fitness_center_outlined),
                    title: const Text('Gym mode'),
                    subtitle: const Text(
                        'A between-sets rest timer on the review screen, coach '
                        'hidden — quick recall reviews while you train. Mock '
                        'interviews stay a separate, always-available activity.'),
                    value: gym.enabled,
                    onChanged: (v) =>
                        ref.read(gymModeProvider.notifier).setEnabled(v),
                  ),
                  if (gym.enabled)
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Rest between sets'),
                      subtitle: Text('${gym.restSeconds}s'),
                      trailing: _Stepper(
                        value: gym.restSeconds,
                        min: GymMode.minRest,
                        max: GymMode.maxRest,
                        step: GymMode.step,
                        onChanged: (v) =>
                            ref.read(gymModeProvider.notifier).setRest(v),
                      ),
                    ),
                ],
              ),
          const _SectionHeader('Progress'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Back up now'),
            subtitle: const Text('Write your progress to the vault snapshot'),
            enabled: source != null,
            onTap: source == null ? null : () => _backupNow(context, ref),
          ),
          DestructiveRow(
            icon: Icons.settings_backup_restore,
            title: 'Restore from vault',
            subtitle:
                'Replace local progress with the vault snapshot — happens '
                'automatically on a fresh install',
            actionLabel: 'Restore',
            confirmTitle: 'Restore from vault?',
            confirmMessage:
                'This replaces your current progress with the snapshot saved in '
                'the vault. Any reviews recorded since that snapshot will be '
                'lost.',
            enabled: source != null,
            onConfirmed: () => _restore(context, ref),
          ),
          const _SectionHeader('Claude'),
          ...apiKey.when(
            loading: () => const [
              ListTile(
                leading: Icon(Icons.key_outlined),
                title: Text('Anthropic API key'),
                subtitle: Text('Checking…'),
              ),
            ],
            error: (e, _) => [
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Anthropic API key'),
                subtitle: Text('Storage error: $e'),
              ),
            ],
            data: (key) {
              final isSet = key != null && key.isNotEmpty;
              // Where did the resolved key come from? The env var wins in
              // `apiKeyProvider.build`, so if it's present the app is using it —
              // this line is the definitive readout when debugging the env
              // fallback on desktop.
              final fromEnv =
                  (Platform.environment['ANTHROPIC_API_KEY'] ?? '').isNotEmpty;
              final String subtitle;
              if (isSet) {
                subtitle = fromEnv
                    ? 'Key detected · from ANTHROPIC_API_KEY (environment)'
                    : 'Key saved · stored in the Keychain';
              } else if (Platform.isLinux) {
                subtitle = 'Not set — launch with ANTHROPIC_API_KEY set '
                    '(no keychain on Linux)';
              } else {
                subtitle = 'Not set — tap to add';
              }
              return [
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Anthropic API key'),
                  subtitle: Text(subtitle),
                  trailing: isSet && !fromEnv
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove key',
                          onPressed: () => _clearApiKey(context, ref),
                        )
                      : null,
                  onTap: fromEnv ? null : () => showApiKeySheet(context),
                ),
                ListTile(
                  leading: const Icon(Icons.wifi_tethering),
                  title: const Text('Test connection'),
                  subtitle: const Text('Send a tiny request to verify the key'),
                  enabled: isSet,
                  onTap: isSet ? () => _testConnection(context, ref) : null,
                ),
              ];
            },
          ),
          if (isDevDataMode) ...[
            const _SectionHeader('Developer'),
            DestructiveRow(
              icon: Icons.delete_forever_outlined,
              title: 'Reset local progress',
              subtitle:
                  'Wipe this dev build\'s schedule, reviews, streak, coach '
                  'chats and mock attempts. Dev data is isolated — your real '
                  '(release) progress is separate and untouched.',
              actionLabel: 'Reset',
              confirmTitle: 'Reset local progress?',
              confirmMessage:
                  'Clears this development build\'s study data (schedule, review '
                  'log, streak, coach chats). This only affects the isolated dev '
                  'database and dev snapshot — real progress is untouched.',
              onConfirmed: () => _resetProgress(context, ref),
            ),
            ref.watch(devSimDayProvider).when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (day) => ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: const Text('Simulate study progress'),
                    subtitle: Text(day == 0
                        ? 'Build a realistic history: each step = one day at '
                            'your "New sections per day" pace (learns that many '
                            'new sections + a mock, clock advances a day). Tap '
                            'to watch the dashboard evolve at true speed.'
                        : 'Day $day simulated — cumulative recall + mock '
                            'evidence at your real daily pace. Keep tapping to '
                            'advance; "Reset local progress" clears it.'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        ActionChip(
                          label: const Text('+1 day'),
                          onPressed: () => _simulate(context, ref, 1),
                        ),
                        ActionChip(
                          label: const Text('+1 week'),
                          onPressed: () => _simulate(context, ref, 7),
                        ),
                      ],
                    ),
                  ),
                ),
            ref.watch(devClockOffsetProvider).when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (days) => ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Time travel'),
                    subtitle: Text(days == 0
                        ? 'Clock at real time. Advance to let the FSRS schedule '
                            'come due naturally.'
                        : 'Clock advanced ${days > 0 ? '+' : ''}$days '
                            'day${days.abs() == 1 ? '' : 's'} from real time.'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        for (final d in const [1, 7])
                          ActionChip(
                            label: Text('+$d'),
                            onPressed: () => _advanceClock(ref, d),
                          ),
                        if (days != 0)
                          ActionChip(
                            label: const Text('Reset'),
                            onPressed: () => _advanceClock(ref, null),
                          ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  // The confirm step lives in [DestructiveRow]; this runs only after the user
  // has confirmed.
  Future<void> _resetProgress(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(appDatabaseProvider).wipeStudyData();
    // Reset the dev clock too — a fresh testing baseline means back to real time,
    // otherwise a left-over fast-forward silently skews the next run's schedule.
    await ref.read(devClockOffsetProvider.notifier).reset();
    // And the simulated-day counter, so "Simulate study progress" starts over.
    await ref.read(devSimDayProvider.notifier).reset();
    ref.invalidate(srsStatesProvider);
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(learnQueueProvider);
    ref.invalidate(dailyNewRemainingProvider);
    // Applied attempts were wiped too — refresh so readiness de-graduates.
    ref.invalidate(appliedTransferProvider);
    // Overwrite the (dev) snapshot so a restart doesn't restore the old data.
    await ref.read(backupProvider.notifier).flush();
    messenger.showSnackBar(
      const SnackBar(content: Text('Local progress reset — clock back to now')),
    );
  }

  /// Advance the dev clock by [days] (or reset when null), then refresh the
  /// time-gated providers so due dates, the daily new allowance, streak and
  /// readiness reflect the new "now".
  Future<void> _advanceClock(WidgetRef ref, int? days) async {
    final notifier = ref.read(devClockOffsetProvider.notifier);
    if (days == null) {
      await notifier.reset();
    } else {
      await notifier.advance(days);
    }
    // Force the CLOCK itself to recompute with the new offset first — its watch
    // of devClockOffset doesn't reliably re-fire, so without this the consumers
    // below rebuild but read a stale clock (the "clock moves, app doesn't" bug).
    ref.invalidate(clockProvider);
    // Then refresh everything clock-derived — a partial list left readiness/
    // pace/streak/insights stale (they can't be trusted to recompute off the
    // watch chain alone when kept alive by Home).
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(learnQueueProvider);
    ref.invalidate(dailyNewRemainingProvider);
    ref.invalidate(srsStatesProvider);
    ref.invalidate(appliedTransferProvider);
    ref.invalidate(appliedSummaryProvider);
    ref.invalidate(readinessProvider);
    ref.invalidate(readinessPaceProvider);
    ref.invalidate(readinessLadderPositionProvider);
    ref.invalidate(coachUpdateProvider);
    ref.invalidate(dueForecastProvider);
    ref.invalidate(retentionByDomainProvider);
    ref.invalidate(studyConsistencyProvider);
  }

  /// Dev/E2E: simulate [days] more days of study — **cumulative**, so repeated
  /// taps build a believable history and the dashboard visibly evolves. A
  /// simulated day mirrors a *real* day at the configured pace: it learns
  /// exactly `New sections per day` new sections (globally, round-robin across
  /// domains — not a fraction of the corpus), adds a mock per already-started
  /// domain with a gradually climbing score, and advances the dev clock a day
  /// so recency behaves and earlier low-stability material eventually falls due.
  /// Interview readiness *gates* recall by proven transfer, so planting recall
  /// first (it's logically prior) is what lets the graduated dashboard populate.
  Future<void> _simulate(BuildContext context, WidgetRef ref, int days) async {
    final messenger = ScaffoldMessenger.of(context);
    final index = await ref.read(vaultIndexProvider.future);
    final clock0 = ref.read(clockProvider).asData?.value ?? Clock.real;
    final perDay = await ref.read(newCardLimitProvider.future); // real cadence
    final repo = ref.read(appliedRepositoryProvider);
    final srsRepo = ref.read(srsRepositoryProvider);
    final startDay = ref.read(devSimDayProvider).asData?.value ?? 0;

    // Every quizzable section by domain + one representative card per domain.
    final domains = <String>[];
    final byDomain = <String, Card>{};
    final sectionsByDomain = <String, List<({String cardId, String slug})>>{};
    for (final c in index.cards) {
      final d = c.domain;
      if (d == null) continue;
      if (!byDomain.containsKey(d)) domains.add(d);
      byDomain.putIfAbsent(d, () => c);
      for (final s in c.quizzableSections) {
        sectionsByDomain
            .putIfAbsent(d, () => [])
            .add((cardId: c.id, slug: s.slug));
      }
    }
    if (byDomain.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No domains found — configure a vault first')));
      return;
    }

    // One global learn order, round-robin across domains so both progress
    // together (a fair proxy for the tier-interleaved real learn queue). New
    // sections come online at `perDay`/day against THIS list, so a simulated
    // day covers the same slice a real day would — not 1/7 of the whole corpus.
    final order = <({String domain, String cardId, String slug})>[];
    for (var i = 0; true; i++) {
      var added = false;
      for (final d in domains) {
        final list = sectionsByDomain[d]!;
        if (i < list.length) {
          order.add((domain: d, cardId: list[i].cardId, slug: list[i].slug));
          added = true;
        }
      }
      if (!added) break;
    }
    final total = order.length;

    var mocks = 0, studiedNew = 0;
    for (var k = 1; k <= days; k++) {
      final day = startDay + k;
      final simNow = clock0.now().add(Duration(days: k));

      // Sections come online at `perDay`/day against the global order. A section
      // at index i was first studied on day (i ~/ perDay) + 1.
      final from = ((day - 1) * perDay).clamp(0, total);
      final to = (day * perDay).clamp(0, total);

      // Re-seed EVERY studied-so-far section with an age-grown stability —
      // modeling review-driven consolidation. FSRS stability ≈ your current
      // review interval, so it climbs ~1 day per real day of successful spaced
      // review: `stability ≈ 3 + age`. Reaching the ~90-day stability that reads
      // as fully durable therefore takes ~3 months, not 2 weeks. (Without any
      // growth, strength froze and readiness plateaued ~55%; with growth that's
      // too fast, "ready" arrived unrealistically early.) Newest cards stay
      // weak, so the p20 floor still bites until the deck matures.
      final startedDomains = <String>{};
      final studied =
          <({String cardId, String sectionSlug, double stability})>[];
      for (var i = 0; i < to; i++) {
        final firstDay = (i ~/ perDay) + 1;
        final age = day - firstDay; // >= 0
        studied.add((
          cardId: order[i].cardId,
          sectionSlug: order[i].slug,
          stability: (3.0 + age).clamp(3.0, 200.0),
        ));
        startedDomains.add(order[i].domain);
      }
      if (studied.isNotEmpty) {
        await srsRepo.seedStudied(studied, at: simNow);
        studiedNew += (to - from);
      }
      // Log a 'learn' event for THIS day's newly-covered slice only (once per
      // section), so the coverage-pace signal reflects the simulated study rate.
      if (to > from) {
        await srsRepo.seedLearnEvents(
          [
            for (var i = from; i < to; i++)
              (cardId: order[i].cardId, sectionSlug: order[i].slug)
          ],
          at: simNow,
        );
        // Also append graded review rows for the day's slice, so retention
        // analytics have data (seedStudied only writes FSRS state). A ~87% recall
        // pattern (every 8th "Again", then every 3rd "Hard") reads realistically
        // against the ~90% target rather than a suspicious 100%.
        await srsRepo.seedReviews(
          [
            for (var i = from; i < to; i++)
              (
                cardId: order[i].cardId,
                sectionSlug: order[i].slug,
                grade: i % 8 == 0 ? 1 : (i % 3 == 0 ? 2 : 3),
                stability: 3.0,
              )
          ],
          at: simNow,
        );
      }

      // One mock per already-started domain this day; score climbs with time and
      // varies by domain so the per-domain bars diverge.
      for (var di = 0; di < domains.length; di++) {
        final d = domains[di];
        if (!startedDomains.contains(d)) continue;
        final card = byDomain[d]!;
        await repo.record(
          cardId: card.id,
          sectionSlug: card.quizzableSections.isEmpty
              ? null
              : card.quizzableSections.first.slug,
          domain: d,
          source: 'dev-seed',
          occurredAt: simNow,
          assessment: AppliedAssessment(
            // Mock performance climbs slowly — reaching ~90% only around the
            // two-month mark, not in the first fortnight.
            appliedScore: (42 + 1.2 * day + di * 4).round().clamp(35, 92),
            rubric: const {'correctness': 3, 'communication': 4},
            novel: day.isOdd,
          ),
        );
        mocks++;
      }
    }

    // Move the app clock to the last simulated day and persist the counter.
    await ref.read(devClockOffsetProvider.notifier).advance(days);
    await ref.read(devSimDayProvider.notifier).set(startDay + days);

    // Refresh everything time/evidence-derived so Home reflects the new history.
    ref.invalidate(
        clockProvider); // recompute the clock with the new offset first
    ref.invalidate(srsStatesProvider);
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(learnQueueProvider);
    ref.invalidate(dailyNewRemainingProvider);
    ref.invalidate(appliedTransferProvider);
    ref.invalidate(appliedSummaryProvider);
    ref.invalidate(readinessProvider);
    ref.invalidate(readinessLadderPositionProvider);
    ref.invalidate(readinessPaceProvider); // now fed by the seeded learn events
    ref.invalidate(coachUpdateProvider);
    // Refresh the Insights sections (new review rows, states, and mocks).
    ref.invalidate(retentionByDomainProvider);
    ref.invalidate(mockSkillsProvider);
    ref.invalidate(dueForecastProvider);
    ref.invalidate(strugglingCardsProvider);
    ref.invalidate(studyConsistencyProvider);
    await ref.read(backupProvider.notifier).flush();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Simulated $days day${days == 1 ? '' : 's'} '
            '($studiedNew new sections, +$mocks mocks) — now at day '
            '${startDay + days}. Check Home.'),
      ),
    );
  }

  Future<void> _clearApiKey(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove API key?'),
        content: const Text(
            'Coach and mock features stop until you add a key again. Your '
            'study progress is unaffected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiKeyProvider.notifier).clear();
      messenger.showSnackBar(const SnackBar(content: Text('API key removed')));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Could not remove key: $e')));
    }
  }

  Future<void> _testConnection(BuildContext context, WidgetRef ref) async {
    final service = ref.read(claudeServiceProvider);
    if (service == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Testing…')));
    try {
      final reply = await service.complete(
          prompt: 'Reply with exactly: pong', maxTokens: 16);
      messenger.showSnackBar(
          SnackBar(content: Text('Connected — Claude replied "$reply"')));
    } on ClaudeException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: ${e.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _backupNow(BuildContext context, WidgetRef ref) async {
    await ref.read(backupProvider.notifier).flush();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress backed up to the vault')),
      );
    }
  }

  // The confirm step lives in [DestructiveRow]; this runs only after the user
  // has confirmed.
  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final restored = await ref.read(backupProvider.notifier).restore();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(restored == 0
              ? 'No snapshot found in the vault'
              : 'Restored $restored sections from the vault'),
        ),
      );
    }
  }
}

/// A "what-if" pace planner: drag the new-sections/day and see when relevance-
/// weighted recall readiness would cross your target, reusing the same forecast
/// curve as Home's calendar (#49). Lets you apply the pace in one tap, so
/// planning and the actual setting stay in sync.
class _PacePlanner extends ConsumerStatefulWidget {
  const _PacePlanner();

  @override
  ConsumerState<_PacePlanner> createState() => _PacePlannerState();
}

class _PacePlannerState extends ConsumerState<_PacePlanner> {
  int? _perDay; // null → track the saved new-cards/day

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final async = ref.watch(readinessForecastProvider);
    final r = ref.watch(readinessProvider).asData?.value;
    final limit = ref.watch(newCardLimitProvider).asData?.value ??
        NewCardLimit.defaultValue;

    if (async.isLoading) {
      return const ListTile(
        leading: Icon(Icons.timeline_outlined),
        title: Text('Pace planner'),
        subtitle: Text('Estimating your timeline…'),
      );
    }
    final f = async.asData?.value;
    if (f == null) {
      return ListTile(
        leading: const Icon(Icons.timeline_outlined),
        title: const Text('Pace planner'),
        subtitle: Text(
            'Set a target on Home and study a little to plan a pace.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      );
    }
    if (f.alreadyReady) {
      return ListTile(
        leading: const Icon(Icons.timeline_outlined),
        title: const Text('Pace planner'),
        subtitle: Text('You’re already at your target for this aim.',
            style: theme.textTheme.bodySmall?.copyWith(color: statusGood)),
      );
    }

    final perDay = _perDay ?? f.currentPerDay;
    // Slider spans a light floor up to the fastest pace we simulated. Cap the
    // lower clamp bound at NewCardLimit.max: dragging to the far end makes perDay
    // reach the max, and clamp(perDay + 1, max) would throw (lower > upper).
    final headroom =
        (perDay + 1) > NewCardLimit.max ? NewCardLimit.max : perDay + 1;
    final maxPace = f.maxSampledPerDay.clamp(headroom, NewCardLimit.max);
    const minPace = NewCardLimit.min;
    final value = perDay.clamp(minPace, maxPace);

    // Two DISTINCT, non-competing dates (see the coverage-vs-readiness split):
    //   1. Coverage: when you'll have SEEN every section at this pace (cheap,
    //      linear — remaining / pace). This is "time to get through the deck".
    //   2. Readiness: when recall MATURES past the target (the FSRS forecast).
    // Readiness is always on/after coverage — covering is the prerequisite.
    final total = r == null ? 0 : r.domains.fold(0, (a, d) => a + d.total);
    final studied = r == null ? 0 : r.domains.fold(0, (a, d) => a + d.studied);
    final remaining = (total - studied).clamp(0, total);
    final coveragePct = total == 0 ? 0 : (studied / total * 100).round();
    final coverDate = remaining == 0
        ? null
        : f.today.add(Duration(days: (remaining / value).ceil()));
    final coverText =
        remaining == 0 ? 'done — all cards seen' : _fmtDate(coverDate!);
    final readyDate = f.readyDateFor(value);
    final readyText = readyDate == null
        ? 'over a year out at this pace'
        : _fmtDate(readyDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.timeline_outlined, color: muted),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('At ~$value new/day:',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    _PaceLine(
                        label: 'Get through all cards',
                        value: coverText,
                        color: theme.colorScheme.primary),
                    _PaceLine(
                        label: 'Interview-ready',
                        value: readyText,
                        color: statusGood),
                    const SizedBox(height: 4),
                    Text(
                      total == 0
                          ? 'A what-if forecast for your saved target.'
                          : 'Covered ~$coveragePct% so far. Seeing the material '
                              'comes first; reviews then deepen it into readiness '
                              '(recall only — mocks are a separate axis).',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Slider(
            value: value.toDouble(),
            min: minPace.toDouble(),
            max: maxPace.toDouble(),
            divisions: (maxPace - minPace).clamp(1, 100),
            label: '$value/day',
            onChanged: (v) => setState(() => _perDay = v.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
          child: Row(
            children: [
              Text('Your pace: $limit/day',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              const Spacer(),
              if (value != limit)
                TextButton(
                  onPressed: () {
                    ref.read(newCardLimitProvider.notifier).set(value);
                    setState(() => _perDay = null); // follow the saved value
                  },
                  child: Text('Set to $value/day'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

/// One labeled milestone line in the pace planner (a color dot + "label:
/// value"), used to show the coverage and readiness dates distinctly.
class _PaceLine extends StatelessWidget {
  const _PaceLine(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(text: '$label: '),
                TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

/// A plain-language read on how heavy a given new-sections count is, so the
/// number isn't abstract.
String _loadLabel(int sections) {
  if (sections <= 10) return 'a light load';
  if (sections <= 25) return 'a moderate load';
  return 'a heavy load';
}

/// Minutes as a friendly "90 min (~1.5 h)" label for the daily-time setting.
String _prettyMinutes(int minutes) {
  final hours = minutes / 60;
  final h = hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);
  return '$minutes min (~$h h)';
}

/// A plain-language load rating for a daily problems-per-day target, grounded in
/// interview-prep guidance: ~1–2/day is sustainable, 3–4 is intense, 5+ risks
/// burnout and shallow retention (mitigated here by spaced re-solving).
String _algoLoadLabel(int perDay) {
  if (perDay <= 2) return 'light';
  if (perDay <= 4) return 'moderate';
  if (perDay <= 6) return 'heavy';
  return 'very heavy';
}

/// The Algorithms daily range (min floor / max ceiling), each a compact stepper
/// with a plain-language load read on the ceiling.
class _AlgoDailySetting extends ConsumerWidget {
  const _AlgoDailySetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final min = ref.watch(algoDailyMinProvider).asData?.value;
    final max = ref.watch(algoDailyMaxProvider).asData?.value;
    if (min == null || max == null) {
      return const ListTile(
        leading: Icon(Icons.terminal_outlined),
        title: Text('Problems per day'),
        subtitle: Text('Loading…'),
      );
    }
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.terminal_outlined),
          title: const Text('Problems per day'),
          subtitle: Text(
              '$min–$max per day — up to $max is a ${_algoLoadLabel(max)} load. '
              'A quiet day still gets at least $min (topped up with new '
              'problems); a busy day is capped at $max so due re-solves can’t '
              'pile up.'),
        ),
        ListTile(
          title: const Text('Fewest per day'),
          trailing: _Stepper(
            value: min,
            min: AlgoDailyMin.min,
            max: AlgoDailyMin.max,
            step: AlgoDailyMin.step,
            onChanged: (v) => ref.read(algoDailyMinProvider.notifier).set(v),
          ),
        ),
        ListTile(
          title: const Text('Most per day'),
          trailing: _Stepper(
            value: max,
            min: AlgoDailyMax.min,
            max: AlgoDailyMax.max,
            step: AlgoDailyMax.step,
            onChanged: (v) => ref.read(algoDailyMaxProvider.notifier).set(v),
          ),
        ),
      ],
    );
  }
}

/// A compact −/value/+ stepper for an integer setting, clamped to the
/// NewCardLimit range and moving in its step.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onChanged,
    this.min = NewCardLimit.min,
    this.max = NewCardLimit.max,
    this.step = NewCardLimit.step,
  });

  final int value;
  final void Function(int) onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          visualDensity: VisualDensity.compact,
          onPressed: value > min ? () => onChanged(value - step) : null,
        ),
        SizedBox(
          width: 34,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          visualDensity: VisualDensity.compact,
          onPressed: value < max ? () => onChanged(value + step) : null,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
