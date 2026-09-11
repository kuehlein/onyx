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

/// A live system-design mock interview for one problem: the interviewer persona
/// drives the session (level- and support-calibrated), a count-up stopwatch times
/// the spoken/STT answer, and on End an adversarial grader panel scores the
/// transcript into readiness. Afterward the candidate can keep chatting with a
/// tutor to learn.
class SdMockScreen extends ConsumerStatefulWidget {
  const SdMockScreen({super.key, required this.problemId});

  final String problemId;

  @override
  ConsumerState<SdMockScreen> createState() => _SdMockScreenState();
}

class _SdMockScreenState extends ConsumerState<SdMockScreen> {
  SeniorityLevel? _levelOverride;
  SdSupportMode? _supportOverride;

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
    final level = _levelOverride ?? target?.level ?? SeniorityLevel.senior;
    final company = target?.company ?? CompanyTier.faang;
    final autoSupport = ref.watch(sdAutoSupportModeProvider).asData?.value ??
        SdSupportMode.coaching;
    final support = _supportOverride ?? autoSupport;

    final state = ref.watch(sdMockSessionProvider(widget.problemId));
    final session = ref.read(sdMockSessionProvider(widget.problemId).notifier);
    final theme = Theme.of(context);
    final running = state.phase == SdMockPhase.running;
    final done = state.phase == SdMockPhase.done;

    return Scaffold(
      appBar: AppBar(
        title: Text(card.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (running && !state.busy)
            TextButton(
              onPressed: () => session.endAndGrade(
                  card: card, level: level, company: company, support: support),
              child: const Text('End'),
            ),
          if (done)
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (running || state.phase == SdMockPhase.grading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const SessionTimer(
                      mode: TimerMode.countUp, idleLabel: 'Answer timer'),
                  const Spacer(),
                  _ModeChip(support: support),
                ],
              ),
            ),
          if (state.grade != null) _GradeSummary(grade: state.grade!),
          Expanded(
            child: switch (state.phase) {
              SdMockPhase.intro => _Intro(
                  card: card,
                  level: level,
                  support: support,
                  supportIsAuto: _supportOverride == null,
                  autoSupport: autoSupport,
                  onLevel: (l) => setState(() => _levelOverride = l),
                  onSupport: (s) => setState(() => _supportOverride = s),
                  onStart: () => session.start(card: card),
                  error: state.error,
                ),
              _ => ChatView(
                  messages: [
                    for (final m in state.messages)
                      if (m.role != CoachRole.user || !_isKickoff(m.text))
                        ChatTurn(
                            isUser: m.role == CoachRole.user, text: m.text),
                  ],
                  onSend: (t) => session.send(t,
                      card: card,
                      level: level,
                      company: company,
                      support: support),
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
            },
          ),
        ],
      ),
    );
  }

  static bool _isKickoff(String t) => t.startsWith("I'm ready");
}

/// The intro: choose level + support, then start. Kept lightweight.
class _Intro extends StatelessWidget {
  const _Intro({
    required this.card,
    required this.level,
    required this.support,
    required this.supportIsAuto,
    required this.autoSupport,
    required this.onLevel,
    required this.onSupport,
    required this.onStart,
    this.error,
  });

  final Card card;
  final SeniorityLevel level;
  final SdSupportMode support;
  final bool supportIsAuto;
  final SdSupportMode autoSupport;
  final ValueChanged<SeniorityLevel> onLevel;
  final ValueChanged<SdSupportMode?> onSupport;
  final VoidCallback onStart;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.architecture_outlined,
                size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(card.title,
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'A ~40-minute mock. You drive: clarify requirements, sketch the '
              'design, and justify your trade-offs. Answer out loud '
              '(speech-to-text) or type. Tap "End" for an honest debrief and a '
              'graded readiness signal.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            // Level.
            _Labeled(
              label: 'Interview level',
              child: DropdownButton<SeniorityLevel>(
                value: level,
                isExpanded: true,
                onChanged: (l) => l == null ? null : onLevel(l),
                items: [
                  for (final l in SeniorityLevel.values)
                    DropdownMenuItem(value: l, child: Text(l.label)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Support mode.
            _Labeled(
              label: 'Support',
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'auto', label: Text('Auto (${autoSupport.name})')),
                  const ButtonSegment(
                      value: 'coaching', label: Text('Coaching')),
                  const ButtonSegment(
                      value: 'realistic', label: Text('Realistic')),
                ],
                selected: {
                  supportIsAuto ? 'auto' : support.name,
                },
                onSelectionChanged: (s) => onSupport(switch (s.first) {
                  'coaching' => SdSupportMode.coaching,
                  'realistic' => SdSupportMode.realistic,
                  _ => null,
                }),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              support == SdSupportMode.coaching
                  ? 'Coaching: the interviewer will step in and help if you get '
                      'stuck.'
                  : 'Realistic: hands-off, like the real thing. Ask explicitly if '
                      'you want a hint.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start the mock'),
            ),
          ],
        ),
      ),
    );
  }
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

/// A small chip showing the active support mode during the interview.
class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.support});
  final SdSupportMode support;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coaching = support == SdSupportMode.coaching;
    final color = coaching ? statusInfo : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
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
          Text(coaching ? 'Coaching' : 'Realistic',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
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
