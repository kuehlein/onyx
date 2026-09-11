import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/widgets/grade_buttons.dart';

void main() {
  testWidgets('renders one button per option in a single row and fires taps',
      (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GradeButtons(
          buttons: [
            GradeButton(
                label: 'Clean',
                color: Colors.green,
                onTap: () => tapped.add('Clean')),
            GradeButton(
                label: 'Failed',
                color: Colors.red,
                onTap: () => tapped.add('Failed'),
                highlighted: true),
          ],
        ),
      ),
    ));

    expect(find.byType(Row), findsOneWidget);
    expect(find.text('Clean'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);

    await tester.tap(find.text('Failed'));
    expect(tapped, ['Failed']);
  });
}
