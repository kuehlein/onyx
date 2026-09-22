import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/aim.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/template/software_interviews.dart';

/// S1: aims own the 4 readiness knobs (level/context/track slot ids + date).
/// The deck is a pure lens; `ReadinessTarget.forAim` resolves an aim's knobs,
/// falling back to the template for any it leaves unset. (S2 consumes this in the
/// weakest-link rollup across aims.)
void main() {
  group('Aim knob fields', () {
    test('JSON round-trips the level/context/track slot ids', () {
      const aim = Aim(
          id: 'a', levelId: 'senior', contextId: 'faang', trackId: 'frontend');
      final back = Aim.fromJson(aim.toJson());
      expect(back.levelId, 'senior');
      expect(back.contextId, 'faang');
      expect(back.trackId, 'frontend');
    });

    test('unset knobs are omitted from JSON + stay null', () {
      const aim = Aim(id: 'a');
      expect(aim.toJson().containsKey('levelId'), isFalse);
      final back = Aim.fromJson(aim.toJson());
      expect(back.levelId, isNull);
      expect(back.contextId, isNull);
      expect(back.trackId, isNull);
    });

    test('copyWith sets a knob and can clear it back to null', () {
      const aim = Aim(id: 'a', levelId: 'staff');
      expect(aim.copyWith(levelId: 'mid').levelId, 'mid');
      expect(aim.copyWith(levelId: null).levelId, isNull); // _unset sentinel
      expect(aim.copyWith(companyName: 'x').levelId, 'staff'); // untouched
    });
  });

  group('ReadinessTarget.forAim', () {
    test('uses the aim\'s own knobs when set', () {
      const aim =
          Aim(levelId: 'senior', contextId: 'faang', trackId: 'backend');
      final t = ReadinessTarget.forAim(aim, softwareInterviewsTemplate);
      expect(t.levelId, 'senior');
      expect(t.contextId, 'faang');
      expect(t.trackId, 'backend');
      // Scores against the aim's own template.
      expect(t.templateTarget, same(softwareInterviewsTemplate.target));
    });

    test('falls back to the template slots for unset knobs', () {
      final t = ReadinessTarget.forAim(const Aim(), softwareInterviewsTemplate);
      expect(t.levelId, softwareInterviewsTemplate.target.fallbackLevelId);
      expect(t.contextId, softwareInterviewsTemplate.target.fallbackContextId);
      expect(t.trackId, softwareInterviewsTemplate.target.fallbackTrackId);
    });

    test('carries the passed governing date', () {
      final d = DateTime(2026, 11, 3);
      final t = ReadinessTarget.forAim(const Aim(), softwareInterviewsTemplate,
          date: d);
      expect(t.interviewDate, d);
    });
  });
}
