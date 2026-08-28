import 'dart:io' show Platform;

// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/coach.dart';
import '../models/card.dart';
import '../providers/ai.dart';
import '../providers/coach.dart';
import '../study_grades.dart';
import 'card_markdown.dart';
import 'fading_scroll_edges.dart';

/// Open the coach as a modal bottom sheet for [card]. In a study session pass
/// the [section] under review, the current [revealed] state, and `grading:
/// true` (so it may offer an advisory grade). When browsing a card, pass
/// `section: null`, `revealed: true`, `grading: false`.
Future<void> showCoachSheet(
  BuildContext context, {
  required Card card,
  CardSection? section,
  required bool revealed,
  required bool grading,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // A slim custom handle (see CoachSheet) sits tight to the top instead of
    // the framework handle, which reserves ~36px and leaves the header floating.
    showDragHandle: false,
    // Set explicitly so the transcript's fade edges can blend into the same
    // colour (see FadingScrollEdges below).
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => CoachSheet(
      card: card,
      section: section,
      revealed: revealed,
      grading: grading,
    ),
  );
}

/// The app-bar entry point to the coach: an accent-coloured icon + label, used
/// on both the study and card-detail screens so it reads the same everywhere.
class CoachButton extends StatelessWidget {
  const CoachButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.psychology_outlined, size: 20),
        label: const Text('Coach'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// The coach conversation surface: a scrolling transcript over a text input.
/// Reused verbatim by the study screen and the card-detail screen.
class CoachSheet extends ConsumerStatefulWidget {
  const CoachSheet({
    super.key,
    required this.card,
    required this.section,
    required this.revealed,
    required this.grading,
  });

  final Card card;
  final CardSection? section;
  final bool revealed;
  final bool grading;

  @override
  ConsumerState<CoachSheet> createState() => _CoachSheetState();
}

class _CoachSheetState extends ConsumerState<CoachSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  ({String cardId, String? sectionSlug}) get _scope =>
      (cardId: widget.card.id, sectionSlug: widget.section?.slug);

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
        .read(coachProvider(_scope.cardId, _scope.sectionSlug).notifier)
        .send(
          text,
          card: widget.card,
          section: widget.section,
          revealed: widget.revealed,
          grading: widget.grading,
        );
    _scrollToEnd();
  }

  void _scrollToEnd() {
    // After the frame that adds the new message, pin to the bottom.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(coachProvider(_scope.cardId, _scope.sectionSlug));
    // Persisted history loads from the DB; until it's in, hold the input.
    final ready = async.hasValue;
    final state = async.asData?.value ?? const CoachState();
    final hasKey = ref.watch(claudeServiceProvider) != null;
    // Sit above the keyboard, and take most of the screen so the transcript
    // has room.
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            // Slim drag handle, tight to the top (replaces the framework one).
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _Header(
              subtitle: widget.section?.heading ?? widget.card.title,
              grading: widget.grading,
            ),
            const Divider(height: 1),
            if (!hasKey)
              const Expanded(child: _NoKeyPanel())
            else ...[
              Expanded(
                child: !ready
                    ? const Center(child: CircularProgressIndicator())
                    : FadingScrollEdges(
                        color: theme.colorScheme.surfaceContainerLow,
                        child: ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          children: [
                            // Keep the question in view while the learner talks.
                            _PromptContext(
                              card: widget.card,
                              section: widget.section,
                            ),
                            const SizedBox(height: 12),
                            if (state.isEmpty)
                              _EmptyHint(revealed: widget.revealed)
                            else
                              for (final m in state.messages)
                                _Bubble(
                                  message: m,
                                  showGrade: widget.grading,
                                ),
                          ],
                        ),
                      ),
              ),
              if (state.busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: _Thinking(),
                ),
              if (state.error != null)
                Container(
                  width: double.infinity,
                  color: theme.colorScheme.errorContainer,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    state.error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              _InputBar(
                controller: _input,
                busy: state.busy || !ready,
                grading: widget.grading,
                onSend: _send,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle, required this.grading});

  final String subtitle;
  final bool grading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        children: [
          Icon(Icons.psychology_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(grading ? 'Interviewer' : 'Coach',
                    style: theme.textTheme.titleMedium),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown before the first message; its wording adapts to whether
/// the answer is hidden (hint) or revealed (discuss).
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.revealed});

  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          revealed
              ? 'Ask anything about this card — for a clearer explanation, an '
                  'example, or a sanity check on what you recalled.'
              : "Stuck? Ask for a hint and I'll nudge you without giving it "
                  'away.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// A read-only "here's what you're being asked" card pinned at the top of the
/// transcript, so the prompt stays visible while the learner talks to the coach.
class _PromptContext extends StatelessWidget {
  const _PromptContext({required this.card, required this.section});

  final Card card;
  final CardSection? section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInterview = card.type == CardType.interviewQuestion;
    // Interview cards: the problem statement is the prompt; concept cards: the
    // section you're recalling.
    final problem =
        isInterview && card.overview.isNotEmpty ? card.overview : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROMPT',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary, letterSpacing: 0.6)),
          const SizedBox(height: 4),
          Text(card.title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (section != null) ...[
            const SizedBox(height: 2),
            Text(section!.heading,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
          if (problem != null) ...[
            const SizedBox(height: 8),
            CardMarkdown(problem, compact: true),
          ],
        ],
      ),
    );
  }
}

/// Shown in place of the transcript/input when no Anthropic key is set. The
/// coach button stays visible everywhere; this is where the missing key is
/// explained, with a shortcut to Settings.
class _NoKeyPanel extends StatelessWidget {
  const _NoKeyPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // On a Linux dev desktop there's no system keychain, so the env-var
    // fallback is the intended path — say so instead of sending them to a
    // Settings flow that can't persist a key there.
    final onLinuxDesktop = Platform.isLinux;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.vpn_key_outlined,
                size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'The coach needs an Anthropic API key',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              onLinuxDesktop
                  ? 'This Linux desktop has no system keychain, so launch the '
                      'app with ANTHROPIC_API_KEY set in the environment. (On '
                      'iOS the key lives in the Keychain and is added in '
                      'Settings.)'
                  : 'It talks to Claude directly with your own key — nothing '
                      'runs on a server. Add your key in Settings to start.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (!onLinuxDesktop) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open Settings'),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/settings');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.showGrade});

  final CoachMessage message;
  final bool showGrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == CoachRole.user;
    final grade = message.suggestedGrade;

    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      // Both sides render at the same 16px body size; the coach's is Markdown
      // (code, emphasis) via the card renderer in compact mode so it doesn't
      // carry the card's roomy top padding.
      child: isUser
          ? Text(message.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                height: 1.4,
                color: theme.colorScheme.onPrimaryContainer,
              ))
          : CardMarkdown(message.text, compact: true),
    );

    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.82,
                ),
                child: bubble,
              ),
              if (!isUser && showGrade && grade != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GradeSuggestion(grade: grade),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The coach's advisory grade, shown as a labelled chip. Purely informational —
/// the learner still taps their own grade in the action bar.
class _GradeSuggestion extends StatelessWidget {
  const _GradeSuggestion({required this.grade});

  final int grade;

  @override
  Widget build(BuildContext context) {
    final spec = studyGrades.firstWhere((g) => g.value == grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: spec.color.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Coach suggests: ${spec.label} — your call',
        style: TextStyle(color: spec.color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text('Thinking…',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.busy,
    required this.grading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final bool grading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Separate mic / field / send, vertically centred. Buttons are a fixed 44
    // so the filled circle actually fills them; the dense field lands close to
    // the same height, and centring keeps everything visually level. 8px gaps
    // plus the outer padding keep it off the edges.
    final buttonStyle = IconButton.styleFrom(
      fixedSize: const Size(40, 40),
      padding: EdgeInsets.zero,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Voice input is a fast-follow; the slot holds its place.
            IconButton.filledTonal(
              onPressed: null,
              icon: const Icon(Icons.mic_none),
              tooltip: 'Voice input — coming soon',
              style: buttonStyle,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: busy ? null : (_) => onSend(),
                decoration: InputDecoration(
                  hintText:
                      grading ? 'Answer the interviewer…' : 'Ask the coach…',
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
              style: buttonStyle,
            ),
          ],
        ),
      ),
    );
  }
}
