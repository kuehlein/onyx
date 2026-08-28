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
        loading: () => const Center(child: CircularProgressIndicator()),
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
