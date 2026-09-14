import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/dependency_gating.dart';
import 'package:onyx/core/subject/flow_access.dart';

GateStatus _gate(bool unlocked) => GateStatus(
    unlocked: unlocked,
    metFraction: unlocked ? 1 : 0,
    satisfied: const [],
    weak: const []);

void main() {
  group('flowAccess', () {
    test('gate met → unlocked (override irrelevant)', () {
      expect(flowAccess(gate: _gate(true), overridden: false),
          FlowAccess.unlocked);
      // self-heals: a past override doesn't keep it provisional once earned.
      expect(
          flowAccess(gate: _gate(true), overridden: true), FlowAccess.unlocked);
    });

    test('gate unmet + overridden → provisional (started early)', () {
      expect(flowAccess(gate: _gate(false), overridden: true),
          FlowAccess.provisional);
    });

    test('gate unmet + not overridden → locked', () {
      expect(
          flowAccess(gate: _gate(false), overridden: false), FlowAccess.locked);
    });
  });

  group('satisfiesDownstream (taint containment)', () {
    test('only a legitimately unlocked flow satisfies downstream prereqs', () {
      expect(satisfiesDownstream(FlowAccess.unlocked), isTrue);
      expect(satisfiesDownstream(FlowAccess.provisional), isFalse);
      expect(satisfiesDownstream(FlowAccess.locked), isFalse);
    });
  });
}
