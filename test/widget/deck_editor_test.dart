import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/template/template_registry.dart';
import 'package:onyx/features/home/deck_editor_sheet.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/template.dart';

class _CapturingGoals extends Decks {
  Deck? upserted;
  @override
  Future<List<Deck>> build() async => const [];
  @override
  Future<void> upsert(Deck goal) async => upserted = goal;
}

void main() {
  testWidgets('creating a goal from the editor upserts it', (tester) async {
    final cap = _CapturingGoals();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decksProvider.overrideWith(() => cap),
          templateRegistryProvider.overrideWith((ref) async =>
              TemplateRegistry.single(softwareInterviewsTemplate)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDeckEditor(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Create is disabled until the goal has a name.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).first, 'Korean');
    await tester.pump();

    // Scope to a tag lens.
    await tester.tap(find.text('Tag'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'korean');
    await tester.pump();

    await tester.tap(find.text('Create goal'));
    await tester.pumpAndSettle();

    expect(cap.upserted, isNotNull);
    expect(cap.upserted!.name, 'Korean');
    expect(cap.upserted!.id, 'korean');
    expect(cap.upserted!.membership, isA<TagMembership>());
  });
}
