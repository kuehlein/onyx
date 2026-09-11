// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/coach.dart' show CoachRole;
import '../../core/ai/system_design_interviewer.dart' show SdSupportMode;
import '../../core/interview/assessment.dart';
import '../../core/interview/system_design_grader.dart';
import '../../core/readiness/target.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/system_design.dart';
import '../../shared/providers/vault.dart';
import '../../shared/status_colors.dart';
import '../../shared/widgets/chat_view.dart';
import '../../shared/widgets/session_timer.dart';
import '../../shared/widgets/sheet_header.dart';

/// A live system-design mock interview for one problem. Like the Algorithms
/// session, you land straight in it — it auto-starts (level and support are
/// auto-derived from your target and recent mocks; tweak them from the tune
/// action). A count-up stopwatch times the spoken/STT answer; on End an
/// adversarial grader panel scores the transcript into readiness; afterward you
/// can keep chatting with a tutor to learn.
class SdMockScreen extends ConsumerStatefulWidget {
  const SdMockScreen({
    super.key,
    required this.problemId,
    this.levelName,
    this.supportName,
  });

  final String problemId;
  final String? levelName;
  final String? supportName;

  @override
  ConsumerState<SdMockScreen> createState() => _SdMockScreenState();
}

class _SdMockScreenState extends ConsumerState<SdMockScreen> {
  // In-session overrides from the tune action (null = use the auto-derived value).
  SeniorityLevel? _levelOverride;
  SdSupportMode? _supportOverride;

  SeniorityLevel _level(SeniorityLevel? target) {
    if (_levelOverride != null) return _levelOverride!;
    for (final l in SeniorityLevel.values) {
      if (l.name == widget.levelName) return l;
    }
    return target ?? SeniorityLevel.senior;
  }

  SdSupportMode _support(SdSupportMode auto) {
    if (_supportOverride != null) return _supportOverride!;
    for (final s in SdSupportMode.values) {
      if (s.name == widget.supportName) return s;
    }
    return auto; // 'auto' or absent
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
    final index = ref.watch(vaultIndexProvider).asData?.value;
    final card = index?.cards
        .where(
            (c) => c.id == widget.problemId && c.type == CardType.systemDesign)
        .firstOrNull;
    if (card == null) {
      return const Scaffold(body: Center(child: Text('Problem not found.')));
    }
    final target = ref.watch(readinessTargetControllerProvider).asData?.value;
    final autoSupport = ref.watch(sdAutoSupportModeProvider).asData?.value ??
        SdSupportMode.coaching;
    final level = _level(target?.level);
    final company = target?.company ?? CompanyTier.faang;
    final support = _support(autoSupport);

    final state = ref.watch(sdMockSessionProvider(widget.problemId));
    final session = ref.read(sdMockSessionProvider(widget.problemId).notifier);
    final theme = Theme.of(context);
    final running = state.phase == SdMockPhase.running;
    final done = state.phase == SdMockPhase.done;

    // Land straight in the interview (like the Algorithms session).
    if (state.phase == SdMockPhase.intro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) session.start(card: card);
      });
    }

    // Whether the candidate has actually answered (beyond the hard-coded opener).
    // If not, "End" is really a cancel: pop without grading or spending tokens,
    // and without touching FSRS/stats.
    final answered = state.messages
        .any((m) => m.role == CoachRole.user && !_isKickoff(m.text));

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
                        card: card,
                        level: level,
                        company: company,
                        support: support)
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
          if (running || state.phase == SdMockPhase.grading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  _SettingsPill(
                    level: level,
                    support: support,
                    onTap: () => _adjust(level, autoSupport),
                  ),
                  const Spacer(),
                  const SessionTimer(
                      mode: TimerMode.countUp, idleLabel: 'Answer timer'),
                ],
              ),
            ),
          if (state.grade != null) _GradeSummary(grade: state.grade!),
          Expanded(
            child: ChatView(
              messages: [
                for (final m in state.messages)
                  if (m.role != CoachRole.user || !_isKickoff(m.text))
                    ChatTurn(isUser: m.role == CoachRole.user, text: m.text),
              ],
              onSend: (t) => session.send(t,
                  card: card, level: level, company: company, support: support),
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

  static bool _isKickoff(String t) => t.startsWith("I'm ready");
}

/// The tucked-away "adjust this mock" sheet: level + support. Most users never
/// open it — the defaults follow the target and recent-mock competence.
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
                    onChanged: (l) {
                      if (l != null) {
                        onLevel(l);
                        setSheet(() {});
                      }
                    },
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
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'auto', label: Text('Auto')),
                        ButtonSegment(
                            value: 'coaching', label: Text('Coaching')),
                        ButtonSegment(
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
                  ),
                  const SizedBox(height: 12),
                  // What the choices mean — most users leave this on Auto.
                  _Explain(
                    'Auto',
                    'picks Coaching while you\'re new to these mocks, then '
                        'switches to Realistic as your scores improve. Right now: '
                        '${autoSupport.name}.',
                    theme,
                  ),
                  const SizedBox(height: 6),
                  _Explain(
                    'Coaching',
                    'the interviewer notices when you\'re stuck and steps in with '
                        'a hint — good while you\'re learning.',
                    theme,
                  ),
                  const SizedBox(height: 6),
                  _Explain(
                    'Realistic',
                    'hands-off, like the real thing; ask explicitly if you want a '
                        'hint.',
                    theme,
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

/// A "**Term** — explanation" line for the adjust sheet.
class _Explain extends StatelessWidget {
  const _Explain(this.term, this.desc, this.theme);
  final String term;
  final String desc;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final base = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return RichText(
      text: TextSpan(
        style: base,
        children: [
          TextSpan(
              text: '$term — ',
              style: base?.copyWith(fontWeight: FontWeight.w700)),
          TextSpan(text: desc),
        ],
      ),
    );
  }
}

/// The active level + support, as a tappable pill (opens the adjust sheet) with
/// a tooltip explaining what the mode means and that it's editable.
class _SettingsPill extends StatelessWidget {
  const _SettingsPill({
    required this.level,
    required this.support,
    required this.onTap,
  });

  final SeniorityLevel level;
  final SdSupportMode support;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coaching = support == SdSupportMode.coaching;
    final color = coaching ? statusInfo : theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: coaching
          ? 'Coaching — the interviewer steps in and helps if you get stuck.\n'
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

/// A clean banner of the reconciled grade: a prominent score, a calibrated label,
/// and per-dimension rubric bars.
class _GradeSummary extends StatelessWidget {
  const _GradeSummary({required this.grade});

  final SdGrade grade;

  ({String label, Color color}) get _verdict {
    final s = grade.appliedScore;
    if (s >= 80) return (label: 'Strong', color: statusGood);
    if (s >= 65) return (label: 'Solid', color: statusGood);
    if (s >= 50) return (label: 'Developing', color: statusWarn);
    return (label: 'Needs work', color: statusBad);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = _verdict;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: v.color.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ScoreDisc(score: grade.appliedScore, color: v.color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.label,
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: v.color, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Feeds your system-design readiness',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          if (grade.rubric.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final key in systemDesignRubricDimensions)
              if (grade.rubric[key] != null)
                _RubricRow(label: rubricLabel(key), value: grade.rubric[key]!),
          ],
          if ((grade.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(grade.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 4),
          Text('Read the debrief below, or ask the coach how to improve.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ScoreDisc extends StatelessWidget {
  const _ScoreDisc({required this.score, required this.color});
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 5,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text('$score',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RubricRow extends StatelessWidget {
  const _RubricRow({required this.label, required this.value});
  final String label;
  final int value; // 1..5

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 1; i <= 5; i++) ...[
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= value
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  if (i < 5) const SizedBox(width: 3),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('$value/5', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
