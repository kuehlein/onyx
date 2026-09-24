import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/features/settings/study_load_help.dart';

/// Guards ADR-0010/0011: the study-load help reflects the budget model (you set
/// time + share; the engine derives the mix) and stays subject-neutral — no
/// SWE-specific flow names, no removed per-flow dials, no imported fitness jargon.
Widget _app() => MaterialApp(
      theme: OnyxTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showStudyLoadHelp(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('study-load help reflects the budget model, no SWE/flow leak',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The new model: you set time + share; the app derives the mix + a ceiling.
    expect(find.textContaining('Daily study time'), findsWidgets);
    expect(find.textContaining('automatic ceiling'), findsOneWidget);

    // No SWE-specific flow leak, no removed per-flow dials, no fitness jargon.
    for (final leak in const [
      'Algorithms',
      'algorithm',
      'Mock interviews',
      'LeetCode',
      'New/day',
      'Mocks/wk',
      'deload',
      'taper',
      'strain',
    ]) {
      expect(find.textContaining(leak), findsNothing, reason: 'leaked "$leak"');
    }
  });
}
