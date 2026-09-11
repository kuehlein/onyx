// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/coach.dart' show CoachRole;
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
/// drives the session, a count-up stopwatch times the (spoken, STT) answer, and
/// on "End" an adversarial grader panel scores the transcript into readiness.
class SdMockScreen extends ConsumerWidget {
  const SdMockScreen({super.key, required this.problemId});

  final String problemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(vaultIndexProvider).asData?.value;
    final card = index?.cards
        .where((c) => c.id == problemId && c.type == CardType.systemDesign)
        .firstOrNull;
    if (card == null) {
      return const Scaffold(
        body: Center(child: Text('Problem not found.')),
      );
    }
    final target = ref.watch(readinessTargetControllerProvider).asData?.value;
    final level = target?.level ?? SeniorityLevel.senior;
    final company = target?.company ?? CompanyTier.faang;

    final state = ref.watch(sdMockSessionProvider(problemId));
    final session = ref.read(sdMockSessionProvider(problemId).notifier);
    final theme = Theme.of(context);
    final running = state.phase == SdMockPhase.running;

    return Scaffold(
      appBar: AppBar(
        title: Text(card.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (running && !state.busy)
            TextButton(
              onPressed: () => session.endAndGrade(
                  card: card, level: level, company: company),
              child: const Text('End'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.phase != SdMockPhase.intro)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SessionTimer(
                  mode: TimerMode.countUp,
                  idleLabel: 'Answer timer',
                ),
              ),
            ),
          if (state.grade != null) _GradeSummary(grade: state.grade!),
          Expanded(
            child: switch (state.phase) {
              SdMockPhase.intro => _Intro(
                  card: card,
                  level: level,
                  onStart: () =>
                      session.start(card: card, level: level, company: company),
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
                      card: card, level: level, company: company),
                  busy: state.busy,
                  error: state.error,
                  enabled: running,
                  hintText: running
                      ? 'Speak or type your answer…'
                      : 'Interview ended',
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

class _Intro extends StatelessWidget {
  const _Intro({
    required this.card,
    required this.level,
    required this.onStart,
    this.error,
  });

  final Card card;
  final SeniorityLevel level;
  final VoidCallback onStart;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.architecture_outlined,
                size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(card.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'A ~40-minute mock at the ${level.label} bar. You drive: clarify '
              'requirements, sketch the design, and justify your trade-offs. '
              'Answer out loud (speech-to-text) or type. Tap "End" for an honest '
              'debrief and a graded readiness signal.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
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

/// A compact banner of the reconciled grade: overall + per-dimension bars.
class _GradeSummary extends StatelessWidget {
  const _GradeSummary({required this.grade});

  final SdGrade grade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = grade.appliedScore >= 75
        ? statusGood
        : grade.appliedScore >= 50
            ? statusWarn
            : statusBad;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Mock graded', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text('${grade.appliedScore}/100',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Feeds your system-design readiness. See the debrief below.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (grade.rubric.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final key in systemDesignRubricDimensions)
              if (grade.rubric[key] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(rubricLabel(key),
                            style: theme.textTheme.bodySmall),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: grade.rubric[key]! / 5.0,
                          minHeight: 6,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${grade.rubric[key]}/5',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
