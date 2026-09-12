import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/story/story.dart';
import 'package:onyx/core/story/story_repository.dart';
import 'package:onyx/core/vault/vault_source.dart';

class _FakeSource implements VaultSource {
  _FakeSource(this.files);
  final Map<String, String> files;
  @override
  String get rootLabel => 'fake';
  @override
  Future<List<String>> listCardPaths() async => files.keys.toList()..sort();
  @override
  Future<String> readCard(String path) async => files[path]!;
  @override
  Future<String?> readMeta(String name) async => null;
  @override
  Future<void> writeMeta(String name, String content) async {}
  @override
  Future<void> writeFile(String path, String content) async =>
      files[path] = content;
}

void main() {
  group('Story parse', () {
    final s = Story.parse('''
---
title: The Kafka migration
competencies: [ownership, conflict]
level: staff
companies: [amazon]
created: 2026-09-12
---
# The Kafka migration

## Situation
Queue backlog was paging us nightly.

## Task
Own the migration to Kafka.

## Action
I drove the cutover across three teams.

## Result
Cut on-call pages by 80% and p99 by 200ms.

## Learning
I would have staged the cutover sooner.
''', id: 'kafka-migration')!;

    test('parses frontmatter + STAR sections', () {
      expect(s.title, 'The Kafka migration');
      expect(s.competencies, ['ownership', 'conflict']);
      expect(s.level, 'staff');
      expect(s.companies, ['amazon']);
      expect(s.situation, contains('paging us'));
      expect(s.action, contains('three teams'));
      expect(s.result, contains('80%'));
      expect(s.learning, contains('staged'));
      expect(s.created, DateTime(2026, 9, 12));
    });

    test('flags a quantified result and completeness', () {
      expect(s.hasQuantifiedResult, isTrue);
      expect(s.isComplete, isTrue);
    });

    test('round-trips through toMarkdown', () {
      final again = Story.parse(s.toMarkdown(), id: s.id)!;
      expect(again.title, s.title);
      expect(again.competencies, s.competencies);
      expect(again.level, s.level);
      expect(again.result, s.result);
      expect(again.learning, s.learning);
    });
  });

  test('incomplete story is flagged', () {
    final s = Story.parse('''
---
title: Half a story
competencies: [growth]
---
## Situation
Something happened.
''', id: 'half')!;
    expect(s.isComplete, isFalse);
    expect(s.hasQuantifiedResult, isFalse);
  });

  group('StoryRepository', () {
    test('loads only stories/ notes and can save', () async {
      final src = _FakeSource({
        'stories/a.md': '---\ntitle: A\ncompetencies: [ownership]\n---\n'
            '## Situation\ns\n## Action\na\n## Result\n5x\n',
        'flashcards/not-a-story.md': '---\ntype: flashcard\n---\n# Nope\n',
      });
      final repo = StoryRepository(src);
      final loaded = await repo.loadAll();
      expect(loaded.map((s) => s.id), ['a']); // flashcards/ ignored

      await repo.save(const Story(
        id: 'b',
        title: 'B',
        competencies: ['conflict'],
        situation: 's',
        action: 'a',
        result: 'r',
      ));
      expect(src.files.containsKey('stories/b.md'), isTrue);
      final reloaded = await repo.loadAll();
      expect(reloaded.map((s) => s.id), ['a', 'b']);
    });
  });

  test('storySlug makes a filesystem-safe id', () {
    expect(storySlug('The Kafka Migration!'), 'the-kafka-migration');
    expect(storySlug('***'), 'story');
  });
}
