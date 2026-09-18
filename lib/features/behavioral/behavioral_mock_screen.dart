// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/coach.dart' show CoachRole;
import '../../core/interview/assessment.dart';
import '../../core/practice/mock_session.dart';
import '../../core/readiness/target.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/behavioral.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/vault.dart';
import '../../shared/design/status_color.dart';
import '../../shared/widgets/chat_view.dart';
import '../../shared/widgets/mock_grade_summary.dart';
import '../../shared/widgets/session_timer.dart';
import '../../shared/widgets/sheet_header.dart';

/// A live behavioral mock interview for one competency. You land straight in it —
/// it auto-starts (level from your target; support auto-derived from recent mocks,
/// adjustable from the tune action). A count-up stopwatch times the spoken/STT
/// answer; on End an adversarial grader panel scores the STAR+L transcript into
/// readiness; afterward you can keep chatting with a coach to improve the story.
class BehavioralMockScreen extends ConsumerStatefulWidget {
  const BehavioralMockScreen({
    super.key,
    required this.competencyId,
    this.levelName,
    this.supportName,
  });

  final String competencyId;
  final String? levelName;
  final String? supportName;

  @override
  ConsumerState<BehavioralMockScreen> createState() =>
      _BehavioralMockScreenState();
}

class _BehavioralMockScreenState extends ConsumerState<BehavioralMockScreen> {
  SeniorityLevel? _levelOverride;
  SupportMode? _supportOverride;

  SeniorityLevel _level(SeniorityLevel? target) {
    if (_levelOverride != null) return _levelOverride!;
    for (final l in SeniorityLevel.values) {
      if (l.name == widget.levelName) return l;
    }
    return target ?? SeniorityLevel.senior;
  }

  SupportMode _support(SupportMode auto) {
    if (_supportOverride != null) return _supportOverride!;
    for (final s in SupportMode.values) {
      if (s.name == widget.supportName) return s;
    }
    return auto;
  }

  Future<void> _adjust(SeniorityLevel level, SupportMode autoSupport) async {
    await showOnyxSheet<void>(
      context,
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
    final index = ref.watch(vaultIndexProvider).asData?.value;
    final card = index?.cards
        .where((c) => c.id == widget.competencyId && c.type == kTypeBehavioral)
        .firstOrNull;
    if (card == null) {
      return const Scaffold(body: Center(child: Text('Competency not found.')));
    }
    final target = ref.watch(activeTargetProvider).asData?.value;
    final autoSupport =
        ref.watch(behavioralAutoSupportModeProvider).asData?.value ??
            SupportMode.coaching;
    final level = _level(target?.level);
    final support = _support(autoSupport);

    final state = ref.watch(behavioralMockSessionProvider(widget.competencyId));
    final session =
        ref.read(behavioralMockSessionProvider(widget.competencyId).notifier);
    final theme = Theme.of(context);
    final running = state.phase == MockPhase.running;
    final done = state.phase == MockPhase.done;

    // Land straight in the interview.
    if (state.phase == MockPhase.intro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) session.start(card: card);
      });
    }

    // "End" is a real cancel until the candidate has actually answered.
    final answered = state.messages.any((m) => m.role == CoachRole.user);

    return Scaffold(
      appBar: AppBar(
        title: Text(card.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (!done)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Adjust level & support',
              onPressed: () => _adjust(level, autoSupport),
            ),
          if (running && !state.busy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                onPressed: answered
                    ? () => session.endAndGrade(
                        card: card, level: level, support: support)
                    : () => Navigator.of(context).maybePop(),
                icon: Icon(answered ? Icons.flag_outlined : Icons.close,
                    size: 18),
                label: Text(answered ? 'End & grade' : 'Cancel'),
              ),
            ),
          if (done)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Done'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (running || state.phase == MockPhase.grading)
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                    child: Row(
                      children: [
                        const SessionTimer(
                            mode: TimerMode.countUp, idleLabel: 'Answer timer'),
                        const Spacer(),
                        _SettingsPill(
                          level: level,
                          support: support,
                          onTap: () => _adjust(level, autoSupport),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
          if (state.grade != null)
            MockGradeSummary(
              grade: state.grade!,
              dimensions: behavioralRubricDimensions,
              feedsLabel: 'Feeds your behavioral readiness',
            ),
          Expanded(
            child: ChatView(
              messages: [
                for (final m in state.messages)
                  ChatTurn(isUser: m.role == CoachRole.user, text: m.text),
              ],
              onSend: (t) =>
                  session.send(t, card: card, level: level, support: support),
              busy: state.busy,
              error: state.error,
              enabled: running || done,
              hintText: running
                  ? 'Speak or type your answer…'
                  : done
                      ? 'Ask the coach how to improve…'
                      : 'Grading…',
              fadeColor: theme.colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}

/// The tucked-away "adjust this mock" sheet: level + support. Defaults follow the
/// target and recent-mock competence. Holds its own state so the form reflects a
/// change immediately.
class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet({
    required this.level,
    required this.supportOverride,
    required this.autoSupport,
    required this.onLevel,
    required this.onSupport,
  });

  final SeniorityLevel level;
  final SupportMode? supportOverride;
  final SupportMode autoSupport;
  final ValueChanged<SeniorityLevel> onLevel;
  final ValueChanged<SupportMode?> onSupport;

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  late SeniorityLevel _level = widget.level;
  late SupportMode? _supportOverride = widget.supportOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effective = _supportOverride ?? widget.autoSupport;
    return Padding(
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
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                DropdownButton<SeniorityLevel>(
                  value: _level,
                  isExpanded: true,
                  onChanged: (l) {
                    if (l != null) {
                      setState(() => _level = l);
                      widget.onLevel(l);
                    }
                  },
                  items: [
                    for (final l in SeniorityLevel.values)
                      DropdownMenuItem(value: l, child: Text(l.label)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Support',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'auto', label: Text('Auto')),
                      ButtonSegment(value: 'coaching', label: Text('Coaching')),
                      ButtonSegment(
                          value: 'realistic', label: Text('Realistic')),
                    ],
                    selected: {_supportOverride?.name ?? 'auto'},
                    onSelectionChanged: (s) {
                      final next = switch (s.first) {
                        'coaching' => SupportMode.coaching,
                        'realistic' => SupportMode.realistic,
                        _ => null,
                      };
                      setState(() => _supportOverride = next);
                      widget.onSupport(next);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 15, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Now: ${_level.label} · '
                        '${effective == SupportMode.coaching ? 'Coaching' : 'Realistic'}. '
                        'Applies from your next message.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The active level + support, as a tappable pill (opens the adjust sheet).
class _SettingsPill extends StatelessWidget {
  const _SettingsPill({
    required this.level,
    required this.support,
    required this.onTap,
  });

  final SeniorityLevel level;
  final SupportMode support;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coaching = support == SupportMode.coaching;
    final color =
        coaching ? StatusColor.info : theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: coaching
          ? 'Coaching — the interviewer helps if you get stuck.\n'
              'Tap to change interview level or support.'
          : 'Realistic — hands-off, like a real interview.\n'
              'Tap to change interview level or support.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  coaching
                      ? Icons.volunteer_activism_outlined
                      : Icons.gavel_outlined,
                  size: 14,
                  color: color),
              const SizedBox(width: 6),
              Text('${level.label} · ${coaching ? 'Coaching' : 'Realistic'}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.tune,
                  size: 12, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
