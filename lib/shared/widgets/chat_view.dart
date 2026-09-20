import 'package:flutter/material.dart';

import '../design/onyx_design.dart';
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

  /// The color the transcript fades into at its edges; defaults to the scaffold
  /// background. Pass a surface color when the chat sits on a panel/sheet.
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
  void didUpdateWidget(ChatView old) {
    super.didUpdateWidget(old);
    // Scroll the newest content into view when a reply arrives (the list grew)
    // or when the "Thinking…" indicator appears — not just when the learner
    // sends. Replies here are short (2–4 sentences), so the bottom-align makes
    // the whole response visible.
    if (widget.messages.length != old.messages.length ||
        (widget.busy && !old.busy)) {
      _scrollToEnd();
    }
  }

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
            // A SingleChildScrollView (not a lazy ListView): these transcripts are
            // short but very heterogeneous — a tall report/markdown header above
            // small chat bubbles. A ListView estimates off-screen extent from the
            // children it has laid out, so scrolling past the big header makes it
            // revise maxScrollExtent, which visibly jumps/resizes the scrollbar.
            // Laying everything out gives an exact extent and smooth scrolling.
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                  Dim.space4, Dim.space3, Dim.space4, Dim.space2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
        ),
        if (widget.busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Dim.space2),
            child: _Thinking(),
          ),
        if (widget.error != null)
          Container(
            width: double.infinity,
            color: theme.colorScheme.errorContainer,
            padding: const EdgeInsets.symmetric(
                horizontal: Dim.space4, vertical: Dim.space3),
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
              margin: const EdgeInsets.only(bottom: Dim.space3),
              padding: const EdgeInsets.symmetric(
                  horizontal: Dim.space4, vertical: Dim.space3),
              decoration: BoxDecoration(
                color: turn.isUser
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: Dim.brCard,
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // Indeterminate AI work → a static status line, NOT a spinning ring
    // (design-system §2.6/§8 progressPolicy: no auto-playing/looping animation;
    // it would also ignore Reduce-Motion). `liveRegion` so a screen reader
    // announces it. The broader CircularProgressIndicator sweep is the
    // design-system pass; this fixes the shared composer (Stage-1 P1-4).
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.more_horiz, size: 16, color: muted),
          const SizedBox(width: Dim.space2),
          Text('Thinking…', style: TextStyle(color: muted)),
        ],
      ),
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
        padding: const EdgeInsets.fromLTRB(
            Dim.space3, Dim.space2, Dim.space3, Dim.space3),
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: Dim.space4, vertical: Dim.space3),
                  border: const OutlineInputBorder(
                    borderRadius: Dim.brSheet,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Dim.space2),
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
