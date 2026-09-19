import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/design/dim.dart';
import 'package:onyx/shared/design/onyx_tokens.dart';

/// The const [Dim] surface and the runtime [OnyxTokens] (`context.tokens`) are
/// both single-sourced from the primitive palette, so they MUST resolve to the
/// same values. This guard fails if one drifts from the other — the whole point
/// of tokenizing is that there is one grid, expressed two ways.
void main() {
  const t = OnyxTokens.standard;

  test('Dim spacing mirrors OnyxTokens.standard', () {
    expect(Dim.space1, t.space1);
    expect(Dim.space2, t.space2);
    expect(Dim.space3, t.space3);
    expect(Dim.space4, t.space4);
    expect(Dim.space5, t.space5);
    expect(Dim.space6, t.space6);
    expect(Dim.space7, t.space7);
  });

  test('Dim radii mirror OnyxTokens.standard (scalars + BorderRadius forms)',
      () {
    expect(Dim.radiusChip, t.radiusChip);
    expect(Dim.radiusCard, t.radiusCard);
    expect(Dim.radiusSheet, t.radiusSheet);
    expect(Dim.radiusFull, t.radiusFull);
    expect(Dim.brChip, BorderRadius.circular(t.radiusChip));
    expect(Dim.brCard, BorderRadius.circular(t.radiusCard));
    expect(Dim.brSheet, BorderRadius.circular(t.radiusSheet));
    expect(Dim.brFull, BorderRadius.circular(t.radiusFull));
  });

  test('Dim opacities mirror OnyxTokens.standard', () {
    expect(Dim.fill, t.fill);
    expect(Dim.hairline, t.hairline);
    expect(Dim.emphasisHigh, t.emphasisHigh);
    expect(Dim.emphasisMed, t.emphasisMed);
    expect(Dim.emphasisLow, t.emphasisLow);
  });
}
