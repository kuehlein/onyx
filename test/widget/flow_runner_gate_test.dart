// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/dependency_gating.dart';
import 'package:onyx/core/subject/flow_spec.dart';
import 'package:onyx/features/practice/flow_runner_screen.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/flow_runner.dart';

/// A focused smoke test of the FlowRunner's GATE branch only: with a locked
/// context, the soft-gate panel renders its "Start anyway" affordance. The live
/// AI chat path is intentionally NOT widget-tested (it needs a fake ClaudeService
/// and hangs on chat animations) — that logic is covered by flow_runner_test.dart.
void main() {
  const flow = FlowSpec(
    cardType: 'conversation',
    scheduling: SchedulingModel.mock,
    quizzability: QuizzabilityPolicy.noSections,
    label: 'Conversation',
    iconKey: 'interview',
    skill: 'skills/order-water.md',
  );

  const locked = FlowRunnerContext(
    card: Card(
      id: 'order-water',
      type: 'conversation',
      title: 'Order water at a café',
      overview: 'Greet the server, ask for water, and thank them.',
      tags: ['dining'],
      tiers: {'dining': 1},
      sections: [],
      wikilinks: [],
      filePath: 'order-water.md',
      dependsOn: ['word-hello', 'word-water'],
    ),
    flow: flow,
    skill: 'You are a warm Korean café server.',
    frontier: {},
    gate: GateStatus(
      unlocked: false,
      metFraction: 0,
      satisfied: [],
      weak: ['word-hello', 'word-water'],
    ),
    weakLabels: {
      'word-hello': '안녕하세요 (annyeonghaseyo)',
      'word-water': '물 (mul)',
    },
  );

  testWidgets('renders the soft-gate panel with a Start anyway affordance',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        flowRunnerContextProvider('order-water')
            .overrideWith((ref) async => locked),
      ],
      child: const MaterialApp(
        home: FlowRunnerScreen(flowType: 'conversation', cardId: 'order-water'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining("builds on things you haven't studied"),
        findsOneWidget);
    // The missing prerequisites are surfaced by their friendly labels.
    expect(find.textContaining('mul'), findsOneWidget);
    // Both affordances render: the soft-gate override and a way back.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Start anyway'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });
}
