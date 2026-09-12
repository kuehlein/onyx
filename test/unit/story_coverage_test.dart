import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/story/coverage.dart';
import 'package:onyx/core/story/story.dart';

Story _s(String id, List<String> comps, {bool complete = true}) => Story(
      id: id,
      title: id,
      competencies: comps,
      situation: 's',
      action: complete ? 'a' : '',
      result: complete ? 'r' : '',
    );

void main() {
  test('coveredCompetencies counts only complete stories', () {
    final stories = [
      _s('a', ['ownership', 'conflict']),
      _s('b', ['ambiguity'], complete: false), // incomplete → not covered
      _s('c', ['conflict']),
    ];
    expect(coveredCompetencies(stories), {'ownership', 'conflict'});
  });

  test('storyCountByCompetency counts all tagging stories', () {
    final stories = [
      _s('a', ['conflict']),
      _s('b', ['conflict'], complete: false),
    ];
    final counts = storyCountByCompetency(stories);
    expect(counts['conflict'], 2);
    expect(counts['ownership'], 0);
  });
}
