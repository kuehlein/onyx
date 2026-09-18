import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';

/// Golden-test harness for the design system (design-system §7 Step 6).
///
/// Pumps [child] inside the real [OnyxTheme.dark] on the app surface color at a
/// fixed [size], and returns a [Finder] for a tight [RepaintBoundary] to capture:
///
/// ```dart
/// final target = await pumpGolden(tester, const MyWidget());
/// await expectLater(target, matchesGoldenFile('goldens/my_widget.png'));
/// ```
///
/// Regenerate baselines with:  `flutter test --update-goldens test/golden/`
///
/// **What goldens are here for:** a LAYOUT / COLOR / SHAPE / ELEVATION regression
/// net for a token-driven restyle — edit a token, and the golden diff shows
/// exactly what moved. They render with the test font (text → blocks), so they
/// are *not* an aesthetic preview — review the look in the running app. (A bundled
/// real font, or the `alchemist` package, would make them human-readable; deferred
/// until online / a CI matrix exists. Goldens are generated on Linux here, so a
/// future macOS/CI run should regenerate or adopt platform-tagged goldens.)
Future<Finder> pumpGolden(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(480, 360),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final theme = OnyxTheme.dark();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: const Key('golden'),
            child: Container(
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return find.byKey(const Key('golden'));
}
