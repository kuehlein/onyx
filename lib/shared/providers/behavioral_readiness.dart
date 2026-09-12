import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/story/behavioral_readiness.dart';
import '../../core/story/competency.dart';
import '../../core/story/coverage.dart';
import 'behavioral.dart';
import 'clock.dart';
import 'interview.dart';
import 'story.dart';

export '../../core/story/behavioral_readiness.dart';

part 'behavioral_readiness.g.dart';

/// Behavioral readiness from the story bank (coverage) + recent behavioral mocks
/// (freshness). A last-mile metric surfaced in the Interview-prep hub.
@riverpod
Future<BehavioralReadiness> behavioralReadiness(Ref ref) async {
  final stories = await ref.watch(storiesProvider.future);
  final now = (await ref.watch(clockProvider.future)).now();
  final attempts = await ref
      .watch(appliedRepositoryProvider)
      .attempts(domain: behavioralSource);
  final mocks = [
    for (final a in attempts)
      if (a.source == behavioralSource)
        (score: a.appliedScore, at: a.occurredAt),
  ];
  return computeBehavioralReadiness(
    coveredCompetencies: coveredCompetencies(stories).length,
    totalCompetencies: kBehavioralCompetencies.length,
    storyCount: stories.length,
    mocks: mocks,
    now: now,
  );
}
