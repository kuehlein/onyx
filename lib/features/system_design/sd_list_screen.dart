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
import '../../shared/widgets/sheet_header.dart';

/// The System-design track entry: a single-problem "your next mock" launcher
/// (like the Algorithms session), not a browser. Spaced recurrence decides which
/// problem is next; the level + support are auto-derived (target + competence) and
/// shown only as a compact reference you can tweak from a tucked-away sheet. The
/// full library of problems lives in Browse.
class SdListScreen extends ConsumerStatefulWidget {
  const SdListScreen({super.key});

  @override
  ConsumerState<SdListScreen> createState() => _SdListScreenState();
}

class _SdListScreenState extends ConsumerState<SdListScreen> {
  SeniorityLevel? _levelOverride;
  SdSupportMode? _supportOverride;

  void _startMock(Card card, SeniorityLevel level) {
    final support = _supportOverride?.name ?? 'auto';
    context.push(
        '/system-design/mock/${card.id}?level=${level.name}&support=$support');
  }

  Future<void> _adjust(SeniorityLevel level, SdSupportMode autoSupport) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (_) => _AdjustSheet(
        level: level,
        supportOverride: _supportOverride,
        autoSupport: autoSupport,
        onLevel: (l) => setState(() => _levelOverride = l),
        onSupport: (s) => setState(() => _supportOverride = s),
      ),
    );
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
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  _NextMockCard(
                    card: suggested,
                    level: level,
                    support: support,
                    supportIsAuto: _supportOverride == null,
                    onAdjust: () => _adjust(level, autoSupport),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _startMock(suggested, level),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start the mock'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Problems surface on a spaced schedule — this is the one to '
                    'practise next. Looking for a specific problem?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/browse'),
                      child: const Text('Browse all problems'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The prominent "next mock" hero card: the problem, its due status, and a
/// compact, tappable line showing the (auto-derived) level + support.
class _NextMockCard extends ConsumerWidget {
  const _NextMockCard({
    required this.card,
    required this.level,
    required this.support,
    required this.supportIsAuto,
    required this.onAdjust,
  });

  final Card card;
  final SeniorityLevel level;
  final SdSupportMode support;
  final bool supportIsAuto;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final due = ref.watch(systemDesignDueProvider(card.id)).asData?.value;
    final now = ref.watch(clockProvider).asData?.value.now();
    final (status, color) = sdStatus(due, now);
    final supportLabel =
        support == SdSupportMode.coaching ? 'Coaching' : 'Realistic';

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
          const SizedBox(height: 16),
          // Compact, unobtrusive settings reference — tap to adjust.
          InkWell(
            onTap: onAdjust,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.tune,
                      size: 15, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${level.label} level · $supportLabel'
                      '${supportIsAuto ? ' (auto)' : ''}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Text('Adjust',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tucked-away "adjust this mock" sheet: level + support. Most users never
/// open this — the defaults are derived from the target and your competence.
class _AdjustSheet extends StatelessWidget {
  const _AdjustSheet({
    required this.level,
    required this.supportOverride,
    required this.autoSupport,
    required this.onLevel,
    required this.onSupport,
  });

  final SeniorityLevel level;
  final SdSupportMode? supportOverride;
  final SdSupportMode autoSupport;
  final ValueChanged<SeniorityLevel> onLevel;
  final ValueChanged<SdSupportMode?> onSupport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effective = supportOverride ?? autoSupport;
    return StatefulBuilder(
      builder: (context, setSheet) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHeader(
              icon: Icons.tune,
              title: 'Adjust this mock',
              subtitle: 'Defaults follow your target and your recent mocks.',
              divider: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Interview level',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  DropdownButton<SeniorityLevel>(
                    value: level,
                    isExpanded: true,
                    onChanged: (l) => l == null ? null : onLevel(l),
                    items: [
                      for (final l in SeniorityLevel.values)
                        DropdownMenuItem(value: l, child: Text(l.label)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Support',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'auto',
                          label: Text('Auto (${autoSupport.name})')),
                      const ButtonSegment(
                          value: 'coaching', label: Text('Coaching')),
                      const ButtonSegment(
                          value: 'realistic', label: Text('Realistic')),
                    ],
                    selected: {supportOverride?.name ?? 'auto'},
                    onSelectionChanged: (s) {
                      onSupport(switch (s.first) {
                        'coaching' => SdSupportMode.coaching,
                        'realistic' => SdSupportMode.realistic,
                        _ => null,
                      });
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    effective == SdSupportMode.coaching
                        ? 'Coaching: the interviewer steps in and helps if you '
                            'get stuck.'
                        : 'Realistic: hands-off, like the real thing. Ask '
                            'explicitly for a hint.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

/// Spaced-recurrence status label + colour for a problem.
(String, Color) sdStatus(DateTime? due, DateTime? now) {
  if (due == null) return ('New', statusInfo);
  if (now == null) return ('Scheduled', Colors.grey);
  if (!due.isAfter(now)) return ('Due', statusWarn);
  final diff = due.difference(now).inDays;
  if (diff == 0) return ('Due today', statusWarn);
  return ('Next in ${diff}d', Colors.grey);
}
