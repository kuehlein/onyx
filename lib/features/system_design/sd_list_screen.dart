// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/system_design_interviewer.dart' show SdSupportMode;
import '../../core/readiness/target.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/system_design.dart';
import '../../shared/status_colors.dart';

/// The System-design track entry: a single-problem "your next mock" launcher
/// (like the Algorithms session), not a browser. It leads with the problem that's
/// due next by spaced recurrence, lets you pick level + support, and starts the
/// mock. Other due problems are a quiet secondary list; the full library lives in
/// Browse.
class SdListScreen extends ConsumerStatefulWidget {
  const SdListScreen({super.key});

  @override
  ConsumerState<SdListScreen> createState() => _SdListScreenState();
}

class _SdListScreenState extends ConsumerState<SdListScreen> {
  SeniorityLevel? _levelOverride;
  SdSupportMode? _supportOverride;

  void _startMock(Card card, SeniorityLevel level, SdSupportMode? support) {
    final q = {
      'level': level.name,
      'support': support?.name ?? 'auto',
    };
    final query = q.entries.map((e) => '${e.key}=${e.value}').join('&');
    context.push('/system-design/mock/${card.id}?$query');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problems = ref.watch(systemDesignProblemsProvider);
    final target = ref.watch(readinessTargetControllerProvider).asData?.value;
    final level = _levelOverride ?? target?.level ?? SeniorityLevel.senior;
    final autoSupport = ref.watch(sdAutoSupportModeProvider).asData?.value ??
        SdSupportMode.coaching;
    final support = _supportOverride ?? autoSupport;

    return Scaffold(
      appBar: AppBar(title: const Text('System design')),
      body: problems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load problems: $e')),
        data: (cards) {
          if (cards.isEmpty) return const _Empty();
          final suggested = cards.first;
          final rest = cards.skip(1).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _NextMockCard(card: suggested),
              const SizedBox(height: 20),
              _Labeled(
                label: 'Interview level',
                child: DropdownButton<SeniorityLevel>(
                  value: level,
                  isExpanded: true,
                  onChanged: (l) =>
                      l == null ? null : setState(() => _levelOverride = l),
                  items: [
                    for (final l in SeniorityLevel.values)
                      DropdownMenuItem(value: l, child: Text(l.label)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Labeled(
                label: 'Support',
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'auto',
                        label: Text('Auto (${autoSupport.name})')),
                    const ButtonSegment(
                        value: 'coaching', label: Text('Coaching')),
                    const ButtonSegment(
                        value: 'realistic', label: Text('Realistic')),
                  ],
                  selected: {_supportOverride?.name ?? 'auto'},
                  onSelectionChanged: (s) => setState(() {
                    _supportOverride = switch (s.first) {
                      'coaching' => SdSupportMode.coaching,
                      'realistic' => SdSupportMode.realistic,
                      _ => null,
                    };
                  }),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                support == SdSupportMode.coaching
                    ? 'Coaching: the interviewer steps in and helps if you get '
                        'stuck.'
                    : 'Realistic: hands-off, like the real thing. Ask explicitly '
                        'for a hint.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _startMock(suggested, level, _supportOverride),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start the mock'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('Or practise another', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final c in rest)
                  _ProblemTile(
                    card: c,
                    onTap: () => _startMock(c, level, _supportOverride),
                  ),
              ],
              const SizedBox(height: 16),
              Text(
                'Ordered by when each is due to re-practise. Browse the full '
                'library of problems in Browse.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The prominent "next mock" hero card for the suggested problem.
class _NextMockCard extends ConsumerWidget {
  const _NextMockCard({required this.card});
  final Card card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final due = ref.watch(systemDesignDueProvider(card.id)).asData?.value;
    final now = ref.watch(clockProvider).asData?.value.now();
    final (status, color) = sdStatus(due, now);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.architecture_outlined,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Your next mock',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary)),
              const Spacer(),
              _StatusChip(status: status, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(card.title, style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}

/// A quiet row for an alternative problem.
class _ProblemTile extends ConsumerWidget {
  const _ProblemTile({required this.card, required this.onTap});
  final Card card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final due = ref.watch(systemDesignDueProvider(card.id)).asData?.value;
    final now = ref.watch(clockProvider).asData?.value.now();
    final (status, color) = sdStatus(due, now);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.architecture_outlined),
      title: Text(card.title),
      subtitle: Text(status,
          style: theme.textTheme.bodySmall?.copyWith(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(status,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No system-design problems in the vault yet.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Spaced-recurrence status label + colour for a problem, shared across tiles.
(String, Color) sdStatus(DateTime? due, DateTime? now) {
  if (due == null) return ('New', statusInfo);
  if (now == null) return ('Scheduled', Colors.grey);
  if (!due.isAfter(now)) return ('Due', statusWarn);
  final diff = due.difference(now).inDays;
  if (diff == 0) return ('Due today', statusWarn);
  return ('Next in ${diff}d', Colors.grey);
}
