import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/readiness/feasibility.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/features/home/aims_screen.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/template.dart';
import 'package:onyx/shared/providers/vault.dart';

/// A fake decks notifier holding one default deck whose [aims] are under test.
/// The Aims screen reads the active deck's aims + the (overridden) readiness /
/// feasibility providers, so no DB / vault is touched.
class _FakeDecks extends Decks {
  _FakeDecks(this._aims);
  final List<Aim> _aims;
  @override
  Future<List<Deck>> build() async => [
        Deck(
          id: defaultDeckId,
          name: 'default',
          templateId: 'software-interviews',
          aims: _aims,
        ),
      ];
}

/// A canned readiness band (55–65%, overall 60%) so the headline is deterministic
/// without computing readiness from cards.
const _readiness = Readiness(
  domains: [
    DomainReadiness(
      domain: 'system-design',
      coverage: 0.6,
      strength: 0.6,
      score: 0.6,
      low: 0.55,
      high: 0.65,
      studied: 10,
      total: 20,
    ),
  ],
  overall: 0.6,
  low: 0.55,
  high: 0.65,
);

Aim _aim(String id, String company,
        {DateTime? date, InterviewStatus? status}) =>
    Aim(
      id: id,
      companyName: company,
      status: status ?? InterviewStatus.active,
      rounds: date == null
          ? const []
          : [InterviewRound(id: '$id-r1', number: 1, date: date)],
    );

Widget _app({
  required List<Aim> aims,
  List<({Aim aim, AimFeasibility feasibility})> feas = const [],
  Readiness readiness = _readiness,
}) =>
    ProviderScope(
      overrides: [
        decksProvider.overrideWith(() => _FakeDecks(aims)),
        clockProvider.overrideWith((ref) async => Clock.real),
        // A null source resolves the built-in SWE template (no DB / vault).
        vaultSourceProvider.overrideWithValue(null),
        readinessProvider.overrideWith((ref) async => readiness),
        aimFeasibilityProvider.overrideWith((ref) async => feas),
        // The aim editor (opened on a row tap) reads the forecast + template;
        // stub the forecast and pin the template to SWE for stable axis titles.
        readinessForecastForProvider.overrideWith((ref, dims) async => null),
        activeDeckTemplateProvider
            .overrideWith((ref) async => softwareInterviewsTemplate),
      ],
      child: MaterialApp(theme: OnyxTheme.dark(), home: const AimsScreen()),
    );

void main() {
  testWidgets(
      'active aims render soonest-first with an honest band + feasibility pills',
      (tester) async {
    final google = _aim('g', 'Google', date: DateTime(2099, 1, 1));
    final amazon = _aim('a', 'Amazon', date: DateTime(2099, 2, 1));
    await tester.pumpWidget(_app(
      // Amazon first in the list, but Google's date is sooner → sorts above.
      aims: [amazon, google],
      feas: [
        (
          aim: amazon,
          feasibility: AimFeasibility(
              status: FeasibilityStatus.behind,
              date: DateTime(2099, 2, 1),
              readyBy: DateTime(2099, 3, 1)),
        ),
        (
          aim: google,
          feasibility: AimFeasibility(
              status: FeasibilityStatus.onTrack,
              date: DateTime(2099, 1, 1),
              readyBy: DateTime(2098, 12, 1)),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    // Honest weakest-link band + a "weakest of N" caption, never a bare number.
    expect(find.text('55–65% ready'), findsOneWidget);
    expect(find.text('Weakest of 2 active aims'), findsOneWidget);

    // Both aims + their calm feasibility pills.
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Amazon'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('Behind'), findsOneWidget);

    // Soonest-dated aim sorts above the later one.
    expect(tester.getTopLeft(find.text('Google')).dy,
        lessThan(tester.getTopLeft(find.text('Amazon')).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a scheduled interview opens the interview overview',
      (tester) async {
    // A company-named aim is interview-shaped → the sheet (where you log the
    // outcome / reschedule), NOT the knob editor (ADR-0009 amendment / #111).
    final google = _aim('g', 'Google', date: DateTime(2099, 1, 1));
    await tester.pumpWidget(_app(
      aims: [google],
      feas: [
        (
          aim: google,
          feasibility: const AimFeasibility(status: FeasibilityStatus.onTrack)
        ),
      ],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();

    // The interview sheet — its study/pause toggle shows; no editor pickers.
    expect(find.text('Prioritize my study for this'), findsOneWidget);
    expect(find.text('Level'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a bare target aim opens the knob editor',
      (tester) async {
    // No company + no interview loop → a target to tune → the knob editor.
    const target = Aim(id: 't');
    await tester.pumpWidget(_app(
      aims: [target],
      feas: [
        (
          aim: target,
          feasibility: const AimFeasibility(status: FeasibilityStatus.openEnded)
        ),
      ],
    ));
    await tester.pumpAndSettle();
    // A company-less aim's row reads as the assessment noun ("Interview" for SWE).
    await tester.tap(find.text('Interview'));
    await tester.pumpAndSettle();

    // The aim editor sheet is open — its Save button + axis pickers are shown.
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Level'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("the interview sheet's Edit aim opens the knob editor",
      (tester) async {
    // Open interview → overflow → Edit aim → the editor (one sheet at a time; the
    // sheet resolves to a signal and the row opens the editor, never stacked).
    final google = _aim('g', 'Google', date: DateTime(2099, 1, 1));
    await tester.pumpWidget(_app(
      aims: [google],
      feas: [
        (
          aim: google,
          feasibility: const AimFeasibility(status: FeasibilityStatus.onTrack)
        ),
      ],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit aim (difficulty · date)'));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Level'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an occurred interview offers a coach debrief (#90)',
      (tester) async {
    // A past-dated round → "occurred" → the inline "Debrief with coach" entry
    // point (unreachable before #90).
    final google = _aim('g', 'Google', date: DateTime(2020, 1, 1));
    await tester.pumpWidget(_app(
      aims: [google],
      feas: [
        (
          aim: google,
          feasibility: const AimFeasibility(status: FeasibilityStatus.openEnded)
        ),
      ],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();

    expect(find.text('Debrief with coach'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an ended interview offers Debrief in the overflow (#90)',
      (tester) async {
    await tester.pumpWidget(_app(
      aims: [_aim('g', 'Google', status: InterviewStatus.rejected)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past (1)')); // expand the Past section
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google')); // ended → interview sheet
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz)); // header overflow
    await tester.pumpAndSettle();

    expect(find.text('Debrief'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an open-ended aim reads as coverage, never a ready-by',
      (tester) async {
    final meta = _aim('m', 'Meta'); // no rounds → open-ended
    await tester.pumpWidget(_app(
      aims: [meta],
      feas: [
        (
          aim: meta,
          feasibility: const AimFeasibility(status: FeasibilityStatus.openEnded)
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Meta'), findsOneWidget);
    expect(find.text('Open-ended'), findsOneWidget);
    expect(find.text('Open-ended · steady pace'), findsOneWidget);
    // Open-ended aims are judged by coverage, so no projected ready-by.
    expect(find.textContaining('ready ~'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a deck with no aims shows the building-coverage state',
      (tester) async {
    await tester.pumpWidget(_app(aims: const []));
    await tester.pumpAndSettle();

    expect(find.text('Building coverage'), findsOneWidget);
    // Coverage = sections studied / total (10/20), not the readiness score.
    expect(find.textContaining('50% of the deck seen'), findsOneWidget);
    // No phantom empty interview list.
    expect(find.text('Weakest of'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ended aims live in a collapsible Past section with their outcome',
      (tester) async {
    await tester.pumpWidget(_app(
      aims: [_aim('g', 'Google', status: InterviewStatus.rejected)],
    ));
    await tester.pumpAndSettle();

    // Collapsed by default: a "Past (1)" toggle, no row yet.
    expect(find.text('Past (1)'), findsOneWidget);
    expect(find.text('Google'), findsNothing);

    // Expand → the aim row appears with its outcome (not a feasibility pill).
    await tester.tap(find.text('Past (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Google'), findsOneWidget);
    expect(find.text("Didn't pass"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
