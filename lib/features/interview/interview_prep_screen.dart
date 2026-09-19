import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/story/competency.dart';
import '../../core/story/coverage.dart';
import '../../shared/providers/behavioral_readiness.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/story.dart';
import '../../shared/design/onyx_design.dart';
import '../home/target_sheet.dart';

/// The "Interview prep" hub — everything about a *specific* interview you're
/// targeting, gathered in one place: your target, the interviews you've scheduled,
/// and behavioral practice (mock + the story bank). This is last-mile, interview-
/// specific work, deliberately kept OUT of the daily Today queue (which is the
/// months-out fundamentals). Reached by tapping the Home target card.
class InterviewPrepScreen extends ConsumerWidget {
  const InterviewPrepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final target = ref.watch(activeTargetProvider).asData?.value;
    final clock = ref.watch(clockProvider).asData?.value;
    final unset = target == null ||
        ref.watch(activeTargetIsSetProvider).asData?.value != true;

    String? countdown;
    final d = target?.interviewDate;
    if (d != null && clock != null) {
      final days =
          DateTime(d.year, d.month, d.day).difference(clock.today()).inDays;
      countdown = days <= 0 ? 'interview is today' : '$days days to go';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Interview prep')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, Dim.space3, 20, 28),
            children: [
              const _SectionHeader('Your target'),
              Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.surfaceContainerHigh,
                child: ListTile(
                  leading: Icon(Icons.flag_outlined,
                      color: theme.colorScheme.primary),
                  title:
                      Text(unset ? 'Set your interview target' : target.label),
                  subtitle: Text(countdown ?? 'level · company · track · date'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => showTargetSheet(context),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionHeader('Scheduled interviews'),
              Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.surfaceContainerHigh,
                child: ListTile(
                  leading: Icon(Icons.event_note_outlined,
                      color: theme.colorScheme.primary),
                  title: const Text('Manage interviews'),
                  subtitle: const Text(
                      'Add or edit the interviews you\'re prepping for.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/interviews'),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionHeader('Behavioral practice'),
              Text(
                'Best in the last stretch before you interview — build your '
                'stories, then rehearse them under pressure.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Dim.space3),
              const _BehavioralReadinessBanner(),
              const SizedBox(height: Dim.space3),
              Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.surfaceContainerHigh,
                child: Column(
                  children: [
                    _StoryCoverageTile(
                        onTap: () => context.push('/behavioral/story-bank')),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.auto_stories_outlined,
                          color: theme.colorScheme.primary),
                      title: const Text('Build your stories'),
                      subtitle: const Text(
                          'Coach-guided STAR story bank from your career.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/behavioral/stories'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.record_voice_over_outlined,
                          color: theme.colorScheme.primary),
                      title: const Text('Do a mock interview'),
                      subtitle: const Text(
                          'A graded, adversarial behavioral mock on a competency.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/behavioral'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact banner of behavioral readiness stage + its next-step hint.
class _BehavioralReadinessBanner extends ConsumerWidget {
  const _BehavioralReadinessBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = ref.watch(behavioralReadinessProvider).asData?.value;
    if (r == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Dim.space3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: Dim.brCard,
      ),
      child: Row(
        children: [
          Icon(Icons.insights_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: Dim.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.stage.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(r.stage.hint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tile summarizing story coverage (N/8 competencies), tapping to the bank.
class _StoryCoverageTile extends ConsumerWidget {
  const _StoryCoverageTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stories = ref.watch(storiesProvider).asData?.value ?? const [];
    final covered = coveredCompetencies(stories).length;
    final total = kBehavioralCompetencies.length;
    return ListTile(
      leading:
          Icon(Icons.checklist_rtl_outlined, color: theme.colorScheme.primary),
      title: const Text('Your stories'),
      subtitle: Text(stories.isEmpty
          ? 'No stories yet — build some to cover the 8 competencies.'
          : '$covered of $total competencies covered · ${stories.length} '
              'stor${stories.length == 1 ? 'y' : 'ies'}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
      padding: const EdgeInsets.only(bottom: Dim.space2, left: 2),
      child: Text(title,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}
