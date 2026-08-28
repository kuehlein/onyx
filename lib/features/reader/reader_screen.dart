import 'dart:async';

// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/reader/reader.dart';
import '../../shared/models/card.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/reader.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/coach_sheet.dart';
import '../../shared/widgets/fading_scroll_edges.dart';

/// In-app "reader mode" for a recommended-reading link: fetch the page, reduce
/// it to clean text, and offer to discuss it with the tutor. An "Open in
/// browser" escape is always available (for pages that don't reduce well).
class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(articleProvider(url));
    final host = Uri.tryParse(url)?.host ?? url;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          async.asData?.value.title ?? 'Reading…',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Discuss the page with the tutor (once it's loaded and a key exists).
          if (async.hasValue && ref.watch(claudeServiceProvider) != null)
            CoachButton(
              onPressed: () => showCoachSheet(
                context,
                card: _pageCard(async.asData!.value),
                section: null,
                revealed: true,
                grading: false,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in browser',
            onPressed: () => _openExternally(url),
          ),
        ],
      ),
      body: async.when(
        loading: () => _ReaderLoading(url: url),
        error: (e, _) => _ReaderError(
          url: url,
          message:
              e is ReaderException ? e.message : 'Could not load this page.',
        ),
        data: (article) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: FadingScrollEdges(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  Text(host,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(article.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  CardMarkdown(article.markdown),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a fetched page as a throwaway [Card] so the coach can discuss it with
/// the tutor persona, reusing the whole coach sheet. The text is capped so a
/// long article doesn't balloon every request.
Card _pageCard(Article a) {
  const cap = 12000;
  final body = a.markdown.length > cap
      ? '${a.markdown.substring(0, cap)}\n\n…(truncated)'
      : a.markdown;
  return Card(
    id: a.url,
    type: CardType.flashcard,
    title: a.title,
    overview: body,
    tags: const [],
    tiers: const {},
    sections: const [],
    wikilinks: const [],
    filePath: a.url,
  );
}

Future<void> _openExternally(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// The loading state. Keeps spinning, but after a few seconds it surfaces an
/// "open in browser instead" escape — so a slow page doesn't strand you until
/// the full timeout.
class _ReaderLoading extends StatefulWidget {
  const _ReaderLoading({required this.url});

  final String url;

  @override
  State<_ReaderLoading> createState() => _ReaderLoadingState();
}

class _ReaderLoadingState extends State<_ReaderLoading> {
  bool _slow = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3),
        () => mounted ? setState(() => _slow = true) : null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            // Still attempting; this just offers a shortcut once it drags.
            if (_slow) ...[
              const SizedBox(height: 20),
              Text('Still loading — this one is taking a while.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in browser instead'),
                onPressed: () => _openExternally(widget.url),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.url, required this.message});

  final String url;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined,
                size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in browser'),
              onPressed: () => _openExternally(url),
            ),
          ],
        ),
      ),
    );
  }
}
