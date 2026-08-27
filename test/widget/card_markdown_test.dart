import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/widgets/card_markdown.dart';

void main() {
  Widget host(String markdown) => MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Scaffold(
          body: SingleChildScrollView(child: CardMarkdown(markdown)),
        ),
      );

  testWidgets('renders bare, unknown, and known code fences without error',
      (tester) async {
    // A bare fence (no language) previously crashed: highlight.parse throws on a
    // null/unknown language. It must render as plain code instead.
    const markdown = '''
Some prose.

```
bare fence code
```

```wutlang
unknown language code
```

```dart
void main() {}
```
''';
    await tester.pumpWidget(host(markdown));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('bare fence code'), findsOneWidget);
    expect(find.text('unknown language code'), findsOneWidget);
  });

  testWidgets('renders a GFM table without error', (tester) async {
    const markdown = '''
| Operation | Time |
|-----------|------|
| lookup    | O(1) |
| insert    | O(1) |
''';
    await tester.pumpWidget(host(markdown));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Operation'), findsOneWidget);
  });
}
