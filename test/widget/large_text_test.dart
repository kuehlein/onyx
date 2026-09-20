import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/widgets/confidence_badge.dart';
import 'package:onyx/shared/widgets/destructive_row.dart';
import 'package:onyx/shared/widgets/empty_state.dart';
import 'package:onyx/shared/widgets/grade_buttons.dart';
import 'package:onyx/shared/widgets/status_pill.dart';

/// Guards WCAG 1.4.4 (resize text up to 200% without loss of content) for the
/// shared, app-wide widgets. Each is rendered at TextScaler 2.0 on a small phone
/// width; a RenderFlex overflow (or any layout throw) surfaces via
/// [WidgetTester.takeException]. Feature screens with heavy provider deps are
/// covered by their own tests — this pins the reusable primitives so a future
/// edit can't silently reintroduce a clip.
void main() {
  // 400dp ≈ a typical phone content width (real devices are ≥360dp); a
  // narrower surface would flag chip labels wider than a sub-device width,
  // which is a chip-contract issue, not a real large-text clip.
  Future<void> pumpAt2x(WidgetTester tester, Widget child,
      {double width = 400}) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: OnyxTheme.dark(),
        home: Builder(
          builder: (context) => MediaQuery(
            // copyWith so the surface size + other metrics survive; only the
            // text scale is forced to the 200% accessibility bar.
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'layout overflowed at 200% text scale');
  }

  testWidgets('StatusPill / ConfidenceBadge wrap without overflow',
      (tester) async {
    // Wider surface here: the test font's square glyphs over-measure the verbose
    // "High confidence" label's *width* (real proportional font is ~half). This
    // still guards structure/height + that pills wrap rather than clip.
    await pumpAt2x(
      tester,
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusPill(
            tone: StatusTone.good,
            label: 'High',
            value: '0.82',
            icon: Icons.verified_outlined,
          ),
          StatusPill(tone: StatusTone.warn, label: 'Shaky'),
          StatusPill(tone: StatusTone.bad, label: 'Weak', dense: true),
          ConfidenceBadge(Confidence.high),
        ],
      ),
      width: 480,
    );
  });

  testWidgets('EmptyState scales without overflow', (tester) async {
    await pumpAt2x(
      tester,
      EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No cards indexed',
        message:
            'Point Onyx at a vault in Settings and your cards show up here.',
        action:
            FilledButton(onPressed: () {}, child: const Text('Open Settings')),
      ),
    );
  });

  testWidgets('DestructiveRow scales without overflow', (tester) async {
    await pumpAt2x(
      tester,
      DestructiveRow(
        icon: Icons.delete_forever_outlined,
        title: 'Reset local progress',
        subtitle: 'Replace local progress with the snapshot',
        actionLabel: 'Reset',
        confirmTitle: 'Reset?',
        confirmMessage: '…',
        onConfirmed: () async {},
      ),
    );
  });

  testWidgets('GradeButtons row scales without overflow', (tester) async {
    await pumpAt2x(
      tester,
      GradeButtons(
        buttons: [
          GradeButton(label: 'Again', color: Colors.red, onTap: () {}),
          GradeButton(label: 'Hard', color: Colors.orange, onTap: () {}),
          GradeButton(label: 'Good', color: Colors.green, onTap: () {}),
          GradeButton(label: 'Easy', color: Colors.blue, onTap: () {}),
        ],
      ),
    );
  });
}
