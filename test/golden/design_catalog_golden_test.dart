import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/design/onyx_design.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/widgets/confidence_badge.dart';
import 'package:onyx/shared/widgets/status_pill.dart';

import 'golden_harness.dart';

/// The design-system catalog golden — the pinned baseline + regression net for
/// the tokens (color / shape / spacing / elevation). When a token changes, this
/// golden's diff shows what moved. Regenerate: `flutter test --update-goldens`.
void main() {
  testWidgets('design catalog — StatusPill + ConfidenceBadge', (tester) async {
    final target = await pumpGolden(tester, const _Catalog());
    await expectLater(
      target,
      matchesGoldenFile('goldens/design_catalog.png'),
    );
  });
}

class _Catalog extends StatelessWidget {
  const _Catalog();

  @override
  Widget build(BuildContext context) {
    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.labelSmall),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: children),
            ],
          ),
        );

    return SizedBox(
      width: 448,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('StatusPill · tones (filled)', const [
            StatusPill(tone: StatusTone.good, label: 'High', value: '0.82'),
            StatusPill(tone: StatusTone.warn, label: 'Shaky'),
            StatusPill(tone: StatusTone.bad, label: 'Weak'),
            StatusPill(tone: StatusTone.info, label: 'Easy'),
            StatusPill(tone: StatusTone.muted, label: 'No data'),
          ]),
          section('StatusPill · variants', const [
            StatusPill(tone: StatusTone.good, label: 'Filled'),
            StatusPill(
                tone: StatusTone.good,
                label: 'Outline',
                variant: StatusPillVariant.outline),
            StatusPill(
                tone: StatusTone.muted,
                label: 'paused',
                variant: StatusPillVariant.text),
          ]),
          section('ConfidenceBadge', const [
            ConfidenceBadge(Confidence.high),
            ConfidenceBadge(Confidence.medium),
            ConfidenceBadge(Confidence.low),
          ]),
        ],
      ),
    );
  }
}
