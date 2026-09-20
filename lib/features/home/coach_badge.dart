import 'package:flutter/material.dart';
import '../../shared/design/onyx_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/coach/coach_update.dart';
import '../../core/plan/daily_plan.dart';
import '../../core/readiness/readiness.dart';
import '../../core/readiness/target.dart';
import '../../shared/coach_settings.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/coach_update.dart';
import '../../shared/providers/daily_plan.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/settings.dart';
import '../../shared/providers/srs.dart';
import '../../shared/widgets/sheet_header.dart';
import 'coach_chat_sheet.dart';
import 'load_checkin_sheet.dart';

/// The numbers that seed the "talk about it" chat.
typedef _ChatSeed = ({
  int overallPct,
  int coveragePct,
  String targetLabel,
  int? days,
});

/// The current per-track daily load, so the chat can reason about (and offer to
/// change) either flow.
typedef _Load = ({int newPerDay, int backlog, int algoMin, int algoMax});

const _green = StatusColor.good;
const _amber = StatusColor.warn;

/// The ambient coach update on Home: one prioritized, task-level line. Tap to
/// expand the "why now" and take the single suggested action. Renders nothing
/// while loading, on error, or when the coach has nothing worth saying.
class CoachBadge extends ConsumerWidget {
  const CoachBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(coachUpdateProvider).asData?.value;
    if (update == null) return const SizedBox.shrink();

    final seed = _chatSeed(
      ref.watch(readinessProvider).asData?.value,
      ref.watch(activeTargetProvider).asData?.value,
      ref.watch(clockProvider).asData?.value,
    );
    final load = (
      newPerDay: ref.watch(newCardLimitProvider).asData?.value ??
          NewCardLimit.defaultValue,
      backlog: ref.watch(reviewQueueProvider).asData?.value.queue.length ?? 0,
      algoMin: ref.watch(algoDailyMinProvider).asData?.value ??
          AlgoDailyMin.defaultValue,
      algoMax: ref.watch(algoDailyMaxProvider).asData?.value ??
          AlgoDailyMax.defaultValue,
    );
    // Today's assembled plan, so "talk about it" can reason about the actual
    // queue (what to keep, defer, sequence) — null until it's ready.
    final plan = ref.watch(dailyPlanProvider).asData?.value;
    final todayPlan = plan == null ? null : describeDailyPlan(plan);

    final theme = Theme.of(context);
    final color = _toneColor(update.tone, theme);
    return Material(
      color: color.withValues(alpha: Dim.fill),
      borderRadius: Dim.brCard,
      child: InkWell(
        borderRadius: Dim.brCard,
        onTap: () => update.kind == CoachInsightKind.loadCheckin
            ? showLoadCheckInSheet(context, ref)
            : _showDetail(context, ref, update, color, seed, load, todayPlan),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Dim.space4, vertical: Dim.space3),
          decoration: BoxDecoration(
            borderRadius: Dim.brCard,
            border: Border.all(color: color.withValues(alpha: Dim.emphasisLow)),
          ),
          child: Row(
            children: [
              Icon(_icon(update.kind), size: Dim.iconMd, color: color),
              const SizedBox(width: Dim.space3),
              Expanded(
                child: Text(
                  update.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: Dim.space2),
              Icon(Icons.expand_more,
                  size: Dim.iconMd, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  _ChatSeed _chatSeed(Readiness? r, ReadinessTarget? t, Clock? clock) {
    final total = r == null ? 0 : r.domains.fold(0, (a, d) => a + d.total);
    final studied = r == null ? 0 : r.domains.fold(0, (a, d) => a + d.studied);
    int? days;
    final date = t?.interviewDate;
    if (date != null && clock != null) {
      days = DateTime(date.year, date.month, date.day)
          .difference(clock.today())
          .inDays;
      if (days < 0) days = 0;
    }
    return (
      overallPct: r == null ? 0 : (r.overall * 100).round(),
      coveragePct: total == 0 ? 0 : (studied / total * 100).round(),
      targetLabel: t?.label ?? 'your goal',
      days: days,
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, CoachUpdate u,
      Color color, _ChatSeed seed, _Load load, String? todayPlan) {
    showOnyxSheet<void>(
      context,
      isScrollControlled: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeader(
                  icon: _icon(u.kind), iconColor: color, title: u.headline),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Dim.space5, 0, Dim.space5, Dim.space5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.why,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface, height: 1.4)),
                    const SizedBox(height: Dim.space5),
                    if (u.proposal != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _applyProposal(context, ref, u.proposal!);
                          },
                          icon: const Icon(Icons.check, size: Dim.iconMd),
                          label: Text(u.proposal!.applyLabel),
                        ),
                      )
                    else if (u.hasAction)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push(u.actionRoute!);
                          },
                          child: Text(u.actionLabel!),
                        ),
                      ),
                    const SizedBox(height: Dim.space2),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          showCoachChatSheet(
                            context,
                            update: u,
                            overallPct: seed.overallPct,
                            coveragePct: seed.coveragePct,
                            targetLabel: seed.targetLabel,
                            daysToInterview: seed.days,
                            newPerDay: load.newPerDay,
                            reviewBacklog: load.backlog,
                            algoMin: load.algoMin,
                            algoMax: load.algoMax,
                            todayPlan: todayPlan,
                          );
                        },
                        icon:
                            const Icon(Icons.forum_outlined, size: Dim.iconMd),
                        label: const Text('Talk about it'),
                      ),
                    ),
                    const SizedBox(height: Dim.space2),
                    // The deep dive lives here (progressive disclosure) rather than
                    // as its own Home button.
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/report');
                        },
                        icon: const Icon(Icons.auto_awesome_outlined,
                            size: Dim.iconMd),
                        label: const Text('Full readiness report'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Apply a proposed load change, then offer a one-tap Undo. Never silent —
  /// only reached from the sheet's explicit Apply button.
  Future<void> _applyProposal(
      BuildContext context, WidgetRef ref, CoachProposal p) async {
    final messenger = ScaffoldMessenger.of(context);
    final r = await applyCoachSetting(ref, p.setting, p.delta);
    messenger.showSnackBar(SnackBar(
      content:
          Text('${coachSettingLabel(p.setting)}: ${r.before} → ${r.after}'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => setCoachSetting(ref, p.setting, r.before),
      ),
    ));
  }

  Color _toneColor(CoachTone tone, ThemeData theme) => switch (tone) {
        CoachTone.caution => _amber,
        CoachTone.positive => _green,
        CoachTone.info => theme.colorScheme.primary,
      };

  IconData _icon(CoachInsightKind kind) => switch (kind) {
        CoachInsightKind.gettingStarted => Icons.rocket_launch_outlined,
        CoachInsightKind.overloaded => Icons.warning_amber_rounded,
        CoachInsightKind.behindPace => Icons.schedule,
        CoachInsightKind.behavioralPrep => Icons.record_voice_over_outlined,
        CoachInsightKind.building => Icons.menu_book_outlined,
        CoachInsightKind.algoDue => Icons.terminal_outlined,
        CoachInsightKind.explainDue => Icons.record_voice_over_outlined,
        CoachInsightKind.unproven => Icons.psychology_outlined,
        CoachInsightKind.loadCheckin => Icons.favorite_outline,
        CoachInsightKind.readyToPush => Icons.trending_up,
        CoachInsightKind.onTrack => Icons.check_circle_outline,
      };
}
