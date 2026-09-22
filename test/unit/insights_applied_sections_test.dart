import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/features/insights/insights_screen.dart';

/// G7d: the Insights "Applied performance" group renders a SWE applied section
/// only when the active subject declares its matching flow. SWE (all flows) is
/// unchanged; a neutral subject gets none (so the group is hidden).
void main() {
  test('SWE declares all five applied sections (byte-identical order)', () {
    final types = {
      for (final f in softwareInterviewsTemplate.flows) f.cardType
    };
    expect(appliedSectionKeys(types),
        ['mock', 'systemDesign', 'behavioral', 'algo', 'patterns']);
  });

  test('a flashcard-only / neutral subject shows no applied sections', () {
    expect(appliedSectionKeys({'flashcard'}), isEmpty);
    expect(appliedSectionKeys({'flashcard', 'conversation'}), isEmpty);
  });

  test('a subject with only the algorithm flow gets algo + patterns', () {
    expect(appliedSectionKeys({'algorithm'}), ['algo', 'patterns']);
  });

  test('sections track exactly the declared flows', () {
    expect(appliedSectionKeys({'system-design'}), ['systemDesign']);
    expect(appliedSectionKeys({'behavioral', 'flashcard'}), ['behavioral']);
  });
}
