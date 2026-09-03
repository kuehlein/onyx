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
import '../../shared/providers/stats.dart';
import '../../shared/providers/settings.dart';
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
          ListTile(
            leading: Icon(Icons.settings_backup_restore,
                color: source == null
                    ? null
                    : Theme.of(context).colorScheme.error),
            title: const Text('Restore from vault'),
            subtitle: const Text(
                'Replace local progress with the vault snapshot — happens '
                'automatically on a fresh install'),
            enabled: source != null,
            onTap: source == null ? null : () => _restore(context, ref),
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
                  onTap: fromEnv ? null : () => _editApiKey(context, ref),
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
            ListTile(
              leading: Icon(Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('Reset local progress'),
              subtitle: const Text(
                  'Wipe this dev build\'s schedule, reviews, streak, coach '
                  'chats and mock attempts. Dev data is isolated — your real '
                  '(release) progress is separate and untouched.'),
              onTap: () => _resetProgress(context, ref),
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

  Future<void> _resetProgress(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset local progress?'),
        content: const Text(
          'Clears this development build\'s study data (schedule, review log, '
          'streak, coach chats). This only affects the isolated dev database '
          'and dev snapshot — real progress is untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

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
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(dailyNewRemainingProvider);
    ref.invalidate(srsStatesProvider);
    ref.invalidate(appliedTransferProvider);
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
    ref.invalidate(srsStatesProvider);
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(learnQueueProvider);
    ref.invalidate(dailyNewRemainingProvider);
    ref.invalidate(appliedTransferProvider);
    ref.invalidate(appliedSummaryProvider);
    ref.invalidate(readinessProvider);
    ref.invalidate(readinessLadderPositionProvider);
    ref.invalidate(readinessPaceProvider); // now fed by the seeded learn events
    ref.invalidate(studyStreakProvider);
    ref.invalidate(coachUpdateProvider);
    ref.invalidate(
        retentionByDomainProvider); // new review rows → refresh Insights
    await ref.read(backupProvider.notifier).flush();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Simulated $days day${days == 1 ? '' : 's'} '
            '($studiedNew new sections, +$mocks mocks) — now at day '
            '${startDay + days}. Check Home.'),
      ),
    );
  }

  Future<void> _editApiKey(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anthropic API key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'sk-ant-…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (key == null || key.isEmpty) return;
    try {
      await ref.read(apiKeyProvider.notifier).set(key);
      messenger.showSnackBar(const SnackBar(content: Text('API key saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save key: $e')));
    }
  }

  Future<void> _clearApiKey(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
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

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from vault?'),
        content: const Text(
          'This replaces your current progress with the snapshot saved in the '
          'vault. Any reviews recorded since that snapshot will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

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

/// A plain-language read on how heavy a given new-sections count is, so the
/// number isn't abstract.
String _loadLabel(int sections) {
  if (sections <= 10) return 'a light load';
  if (sections <= 25) return 'a moderate load';
  return 'a heavy load';
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
