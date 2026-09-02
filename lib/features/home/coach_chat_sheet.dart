import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/coach_update_chat.dart';
import '../../core/coach/coach_update.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/coach_chat.dart';
import '../../shared/widgets/card_markdown.dart';

/// Opens the "talk about it" strategist chat for a coach [update], seeded with
/// the learner's current numbers so it can advise without a round-trip.
Future<void> showCoachChatSheet(
  BuildContext context, {
  required CoachUpdate update,
  required int overallPct,
  required int coveragePct,
  required String targetLabel,
  int? daysToInterview,
}) {
  final system = buildCoachChatSystem(
    update: update,
    overallPct: overallPct,
    coveragePct: coveragePct,
    targetLabel: targetLabel,
    daysToInterview: daysToInterview,
  );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => _CoachChatSheet(system: system, seed: update.headline),
  );
}

class _CoachChatSheet extends ConsumerStatefulWidget {
  const _CoachChatSheet({required this.system, required this.seed});

  final String system;
  final String seed;

  @override
  ConsumerState<_CoachChatSheet> createState() => _CoachChatSheetState();
}

class _CoachChatSheetState extends ConsumerState<_CoachChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await ref
        .read(coachChatProvider.notifier)
        .send(text, system: widget.system);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(coachChatProvider);
    final hasKey = ref.watch(claudeServiceProvider) != null;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.psychology_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('Coach', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: !hasKey
                  ? const _NoKey()
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      children: [
                        if (state.isEmpty) _Opener(seed: widget.seed),
                        for (final m in state.messages) _Bubble(m),
                        if (state.busy)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text('Thinking…'),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            if (state.error != null)
              Container(
                width: double.infinity,
                color: theme.colorScheme.errorContainer,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(state.error!,
                    style:
                        TextStyle(color: theme.colorScheme.onErrorContainer)),
              ),
            if (hasKey)
              _InputBar(controller: _input, busy: state.busy, onSend: _send),
          ],
        ),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('"$seed"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),
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

class _Bubble extends StatelessWidget {
  const _Bubble(this.message);
  final CoachMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == CoachRole.user;
    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: isUser
                  ? Text(message.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          height: 1.4,
                          color: theme.colorScheme.onPrimaryContainer))
                  : CardMarkdown(message.text, compact: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar(
      {required this.controller, required this.busy, required this.onSend});

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: busy ? null : (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask the coach…',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: busy ? null : onSend,
              icon: const Icon(Icons.arrow_upward),
              style: IconButton.styleFrom(
                  fixedSize: const Size(40, 40), padding: EdgeInsets.zero),
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(32),
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
