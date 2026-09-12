import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/story/story.dart';
import '../../core/story/story_repository.dart';
import 'vault.dart';

part 'story.g.dart';

/// The behavioral story-bank repository over the current vault source, or null
/// when no vault is configured.
@riverpod
StoryRepository? storyRepository(Ref ref) {
  final source = ref.watch(vaultSourceProvider);
  return source == null ? null : StoryRepository(source);
}

/// All behavioral stories in the vault (empty when no vault / none authored).
@riverpod
Future<List<Story>> stories(Ref ref) async {
  final repo = ref.watch(storyRepositoryProvider);
  if (repo == null) return const [];
  return repo.loadAll();
}
