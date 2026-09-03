import 'package:flutter/material.dart';

import 'card_markdown.dart';
import 'fading_scroll_edges.dart';

/// One turn in a simple text chat.
class ChatTurn {
  const ChatTurn({required this.isUser, required this.text});
  final bool isUser;
  final String text;
}

/// A reusable chat surface: a fading, auto-scrolling transcript over a text
/// composer that keeps focus after each send (so you can fire off several
/// messages without re-tapping the field). Used by the interview planner, the
/// debrief, and the readiness-report Q&A.
///
/// The richer study-coach sheet ([CoachSheet]) keeps its own variant — it adds
/// voice input, a pinned prompt, and grade chips — but shares the same
/// [FadingScrollEdges] treatment.
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.messages,
    required this.onSend,
    this.busy = false,
    this.error,
    this.hintText = 'Message…',
    this.header,
    this.opener,
    this.trailing,
    this.fadeColor,
    this.enabled = true,
  });

  final List<ChatTurn> messages;
  final void Function(String text) onSend;
  final bool busy;
  final String? error;
  final String hintText;

  /// Always shown at the very top of the transcript (e.g. the report being
  /// discussed, kept in view while you ask about it).
  final Widget? header;

  /// Shown when there are no messages yet (e.g. an intro / how-to line).
  final Widget? opener;

  /// Always shown after the messages (e.g. a proposed-plan result card).
  final Widget? trailing;

  /// The colour the transcript fades into at its edges; defaults to the scaffold
  /// background. Pass a surface colour when the chat sits on a panel/sheet.
  final Color? fadeColor;

  /// When false, the composer is disabled (e.g. no API key configured).
  final bool enabled;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty || widget.busy) return;
    _input.clear();
    widget.onSend(text);
    // Keep the keyboard + caret so the next message can be typed straight away.
    _focus.requestFocus();
    _scrollToEnd();
  }

  void _scrollToEnd() {
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
    return Column(
      children: [
        Expanded(
          child: FadingScrollEdges(
            color: widget.fadeColor,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: [
                if (widget.header != null) widget.header!,
                if (widget.messages.isEmpty && widget.opener != null)
                  widget.opener!,
                for (final m in widget.messages) _Bubble(turn: m),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
        if (widget.busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: _Thinking(),
          ),
        if (widget.error != null)
          Container(
            width: double.infinity,
            color: theme.colorScheme.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              widget.error!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        _Composer(
          controller: _input,
          focusNode: _focus,
          hintText: widget.hintText,
          busy: widget.busy || !widget.enabled,
          onSend: _send,
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});

  final ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment:
          turn.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: turn.isUser
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: turn.isUser
                  ? Text(
                      turn.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        height: 1.4,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  : CardMarkdown(turn.text, compact: true),
            ),
          ),
        ),
      ],
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
        Text(
          'Thinking…',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: busy ? null : (_) => onSend(),
                decoration: InputDecoration(
                  hintText: hintText,
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
                fixedSize: const Size(40, 40),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
