import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/subject_config.dart';
import 'package:onyx/core/subject/subject_config_yaml.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/core/vault/starter_deck.dart';

/// The create-a-folder scaffolder (task #30, G5b): a fresh folder must become a
/// complete, self-documenting, LOADABLE vault — orientation + a neutral subject
/// config + real starter cards — never a SWE sample (content-creation.md §2.3).
void main() {
  test('scaffoldStudyFolder writes a complete, loadable neutral vault',
      () async {
    final dir = await Directory.systemTemp.createTemp('onyx_scaffold_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final source = DesktopVaultSource(dir.path);

    await scaffoldStudyFolder(source);

    // Orientation for an AI opening the folder (Claude Code auto-loads root
    // CLAUDE.md).
    expect(File('${dir.path}/CLAUDE.md').existsSync(), isTrue);

    // The folder is a defined, NEUTRAL subject — not the SWE fallback.
    final yaml = await source.readMeta('onyx-subject.yaml');
    expect(yaml, isNotNull);
    final cfg = subjectConfigFromYaml(yaml!);
    expect(cfg.id, 'my-studies');
    expect(cfg.flowForType('flashcard')?.scheduling, SchedulingModel.recall);
    expect(cfg.target.tracks.map((t) => t.id), ['everything']); // no SWE tracks
    expect(
        cfg.vocabulary, same(Vocabulary.neutral)); // no interview terminology

    // The starter deck parses (CLAUDE.md is a root .md but not a card).
    final cards = [
      for (final path in await source.listCardPaths())
        if (const CardParser()
                .parse(await source.readCard(path), filePath: path)
            case final c?)
          c,
    ];
    expect(
      cards.map((c) => c.id),
      containsAll(<String>[
        'how-reviewing-works',
        'what-makes-a-good-flashcard',
        'spaced-repetition',
      ]),
    );
    for (final c in cards) {
      expect(c.sections.any((s) => s.quizzable), isTrue,
          reason: '${c.id} should have a quizzable section');
    }
  });

  test('scaffoldVault writes an arbitrary template verbatim, nested paths too',
      () async {
    final dir = await Directory.systemTemp.createTemp('onyx_scaffold2_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final source = DesktopVaultSource(dir.path);

    await scaffoldVault(
      source,
      const VaultTemplate(id: 't', label: 'T', files: {
        'notes/deep/a.md': 'hello',
        'root.txt': 'world',
      }),
    );

    expect(File('${dir.path}/notes/deep/a.md').readAsStringSync(), 'hello');
    expect(File('${dir.path}/root.txt').readAsStringSync(), 'world');
  });
}
