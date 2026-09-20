import 'package:flutter/material.dart';
import '../../shared/widgets/loading_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/story/competency.dart';
import '../../core/story/coverage.dart';
import '../../core/story/story.dart';
import '../../shared/providers/story.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/widgets/sheet_header.dart';

/// The story bank: a competency-coverage matrix (do you have a strong story for
/// each of the 8 competencies?) over the list of your saved stories. Coverage is
/// the durable half of behavioral readiness; this is the prep dashboard. Stories
/// are edited in Obsidian (they're vault notes) — this view is read + navigate.
class StoryBankScreen extends ConsumerWidget {
  const StoryBankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your stories')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Could not load stories: $e')),
        data: (stories) => _Body(stories: stories),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.stories});
  final List<Story> stories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final covered = coveredCompetencies(stories);
    final counts = storyCountByCompetency(stories);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Dim.space5, Dim.space3, Dim.space5, Dim.space6),
          children: [
            Text('Coverage', style: theme.textTheme.titleSmall),
            const SizedBox(height: Dim.space1),
            Text(
                '${covered.length} of ${kBehavioralCompetencies.length} '
                'competencies have a story.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: Dim.space3),
            Card(
              margin: EdgeInsets.zero,
              color: theme.colorScheme.surfaceContainerHigh,
              child: Column(
                children: [
                  for (final c in kBehavioralCompetencies)
                    _CoverageRow(
                      label: c.label,
                      covered: covered.contains(c.key),
                      count: counts[c.key] ?? 0,
                    ),
                ],
              ),
            ),
            const SizedBox(height: Dim.space5),
            Text('Your stories (${stories.length})',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: Dim.space2),
            if (stories.isEmpty)
              Text(
                'No stories yet — use "Build your stories" to draft some with the '
                'coach.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final s in stories) _StoryTile(story: s),
          ],
        ),
      ),
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow(
      {required this.label, required this.covered, required this.count});
  final String label;
  final bool covered;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Dim.space4, vertical: Dim.space3),
      child: Row(
        children: [
          Icon(covered ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: covered
                  ? StatusColor.good
                  : theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: Dim.space3),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            covered
                ? (count > 1 ? '$count stories' : 'covered')
                : (count > 0 ? '$count · needs detail' : 'needed'),
            style: theme.textTheme.labelSmall?.copyWith(
                color: covered
                    ? StatusColor.good
                    : theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = story.competencies.map(competencyLabel).join(' · ');
    final flags = <String>[
      if (!story.isComplete) 'incomplete',
      if (story.isComplete && !story.hasQuantifiedResult) 'no metric',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: Dim.space2),
      color: theme.colorScheme.surfaceContainerHigh,
      child: ListTile(
        title: Text(story.title),
        subtitle: Text([
          if (tags.isNotEmpty) tags,
          if (flags.isNotEmpty) '⚠ ${flags.join(', ')}',
        ].join('  ·  ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _show(context, story),
      ),
    );
  }

  void _show(BuildContext context, Story s) {
    showOnyxSheet<void>(
      context,
      builder: (_) => _StorySheet(story: s),
    );
  }
}

class _StorySheet extends StatelessWidget {
  const _StorySheet({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section(String heading, String body) {
      if (body.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: Dim.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: Dim.space1),
            Text(body.trim(), style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          SheetHeader(
              icon: Icons.auto_stories_outlined,
              title: story.title,
              divider: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Dim.space5, Dim.space2, Dim.space5, Dim.space5),
              children: [
                if (story.competencies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Dim.space4),
                    child: Wrap(
                      spacing: Dim.space2,
                      runSpacing: Dim.space2,
                      children: [
                        for (final c in story.competencies)
                          Chip(
                            label: Text(competencyLabel(c)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ),
                section('Situation', story.situation),
                section('Task', story.task),
                section('Action', story.action),
                section('Result', story.result),
                section('Learning', story.learning),
                Text('Edit this story in your vault (Obsidian).',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
