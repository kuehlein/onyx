import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/reader/reader.dart';

part 'reader.g.dart';

/// Shared reader (one HTTP client for the process).
@Riverpod(keepAlive: true)
ReaderService readerService(Ref ref) {
  final service = ReaderService();
  ref.onDispose(service.dispose);
  return service;
}

/// Fetches + extracts the article at [url]. Autodisposes when the reader screen
/// leaves, so it re-fetches fresh next time.
@riverpod
Future<Article> article(Ref ref, String url) =>
    ref.watch(readerServiceProvider).fetch(url);
