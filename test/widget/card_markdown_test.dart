import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/widgets/callout.dart';
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

  testWidgets('highlights aliased languages like ```js (not plain text)',
      (tester) async {
    const markdown = '''
```js
const answer = 42;
```
''';
    await tester.pumpWidget(host(markdown));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Highlighted code is a RichText of spans, so the raw line is NOT present as
    // a plain Text widget. If `js` fell back to plain, this would be findsOne.
    expect(find.text('const answer = 42;'), findsNothing);
  });

  testWidgets('renders an Obsidian callout with title and body',
      (tester) async {
    const markdown = '''
Intro paragraph.

> [!important] Watch out
> Use a heap when the set **changes**.

Trailing paragraph.
''';
    await tester.pumpWidget(host(markdown));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Callout), findsOneWidget);
    expect(find.text('Watch out'), findsOneWidget); // custom title
    // Surrounding prose still renders as normal markdown.
    expect(find.textContaining('Intro paragraph'), findsOneWidget);
  });

  testWidgets('callout without a title falls back to the type label',
      (tester) async {
    const markdown = '''
> [!tip]
> A helpful hint.
''';
    await tester.pumpWidget(host(markdown));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Callout), findsOneWidget);
    expect(find.text('Tip'), findsOneWidget); // default label for [!tip]
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
