import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/coach_update_chat.dart'
    show CoachRole, buildCoachChatSystem;
import '../../core/coach/coach_update.dart';
import '../../shared/coach_settings.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/coach_chat.dart';
import '../../shared/widgets/chat_view.dart';
import '../../shared/widgets/sheet_header.dart';

/// Opens the "talk about it" strategist chat for a coach [update], seeded with
/// the learner's current numbers (readiness + the daily budget + backlog) so it
/// can advise — and offer a one-tap budget change (its one load lever) — without
/// a round-trip.
Future<void> showCoachChatSheet(
  BuildContext context, {
  required CoachUpdate update,
  required int overallPct,
  required int coveragePct,
  required String targetLabel,
  int? daysToInterview,
  required int budgetMinutes,
  int? retentionPct,
  required int reviewBacklog,
  String? todayPlan,
}) {
  final system = buildCoachChatSystem(
    update: update,
    overallPct: overallPct,
    coveragePct: coveragePct,
    targetLabel: targetLabel,
    daysToInterview: daysToInterview,
    budgetMinutes: budgetMinutes,
    retentionPct: retentionPct,
    reviewBacklog: reviewBacklog,
    todayPlan: todayPlan,
  );
  return showOnyxSheet<void>(
    context,
    builder: (_) => _CoachChatSheet(system: system, seed: update.headline),
  );
}

class _CoachChatSheet extends ConsumerWidget {
  const _CoachChatSheet({required this.system, required this.seed});

  final String system;
  final String seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(coachChatProvider);
    final hasKey = ref.watch(claudeServiceProvider) != null;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const SheetHeader(
                icon: Icons.psychology_outlined, title: 'Coach', divider: true),
            Expanded(
              child: !hasKey
                  ? const _NoKey()
                  : ChatView(
                      messages: [
                        for (final m in state.messages)
                          ChatTurn(
                              isUser: m.role == CoachRole.user, text: m.text),
                      ],
                      busy: state.busy,
                      error: state.error,
                      hintText: 'Ask the coach…',
                      fadeColor: sheetSurface(context),
                      opener: _Opener(seed: seed),
                      trailing: state.proposal == null
                          ? null
                          : _ProposalCard(
                              proposal: state.proposal!,
                              onApply: () => _apply(context, ref),
                              onDismiss: () => ref
                                  .read(coachChatProvider.notifier)
                                  .dismissProposal(),
                            ),
                      onSend: (t) => ref
                          .read(coachChatProvider.notifier)
                          .send(t, system: system),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _apply(BuildContext context, WidgetRef ref) async {
  final proposal = ref.read(coachChatProvider).proposal;
  if (proposal == null) return;
  final messenger = ScaffoldMessenger.of(context);
  ref.read(coachChatProvider.notifier).dismissProposal();
  final r = await applyBudgetDelta(ref, proposal.deltaMinutes);
  messenger.showSnackBar(SnackBar(
    content: Text('Daily study time: ${r.before} → ${r.after} min'),
    action: SnackBarAction(
      label: 'Undo',
      onPressed: () => setBudgetMinutes(ref, r.before),
    ),
  ));
}

/// The strategist's proposed load change, shown at the foot of the transcript
/// with Apply / Not now. Applying is the only thing that changes a setting.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.onApply,
    required this.onDismiss,
  });

  final CoachProposal proposal;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sign = proposal.deltaMinutes > 0 ? '+' : '';
    return Container(
      margin: const EdgeInsets.fromLTRB(
          Dim.space3, Dim.space1, Dim.space3, Dim.space3),
      padding: const EdgeInsets.fromLTRB(
          Dim.space4, Dim.space3, Dim.space4, Dim.space3),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.primaryContainer.withValues(alpha: Dim.hairline),
        borderRadius: Dim.brCard,
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: Dim.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily study time  $sign${proposal.deltaMinutes} min/day',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dim.space2),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.check, size: Dim.iconMd),
                label: const Text('Apply'),
              ),
              const SizedBox(width: Dim.space2),
              TextButton(onPressed: onDismiss, child: const Text('Not now')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Opener extends StatelessWidget {
  const _Opener({required this.seed});
  final String seed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Dim.space5),
      child: Column(
        children: [
          Text('"$seed"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: Dim.space3),
          Text(
            'Ask how to act on this — cutting your load, catching up, a plan for '
            'today, whatever’s on your mind.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NoKey extends StatelessWidget {
  const _NoKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dim.space6),
        child: Text(
          'The coach needs an Anthropic API key — add one in Settings to chat.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
