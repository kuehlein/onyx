import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/active_subject.dart';
import 'package:onyx/core/subject/software_interviews.dart';
import 'package:onyx/core/subject/subject_config.dart';
import 'package:onyx/core/subject/subject_config_yaml.dart';
import 'package:onyx/core/subject/subject_registry.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';

/// The shipped example vault (`examples/vault/`) is the reference authoring kit +
/// the scaffold/distribution payload (task #30, G5). Its config must stay a valid,
/// loadable subject that exercises every seam, and its exemplar card must parse
/// under that config — this guards the annotated reference against drift.
void main() {
  final source = DesktopVaultSource('examples/vault');
  late SubjectConfig cfg;

  setUp(() async {
    cfg = subjectConfigFromYaml((await source.readMeta('onyx-subject.yaml'))!);
    activeRegistry = SubjectRegistry.single(cfg);
    activeSubject = cfg;
  });
  tearDown(() {
    activeRegistry = SubjectRegistry.single(softwareInterviewsConfig);
    activeSubject = softwareInterviewsConfig;
  });

  test('loads as a subject exercising target/flows/vocab/parse', () {
    expect(cfg.id, 'software-interviews-example');
    expect(cfg.target.levels.map((l) => l.id), ['mid', 'senior']);
    expect(cfg.target.stabilityTargetDays('faang'), 120);
    expect(cfg.target.domainWeight('backend', 'system-design'), 1.15);

    expect(cfg.flowForType('flashcard')?.scheduling, SchedulingModel.recall);
    expect(cfg.flowForType('algorithm')?.scheduling, SchedulingModel.twoClock);
    expect(cfg.flowForType('system-design')?.scheduling, SchedulingModel.mock);

    expect(cfg.vocabulary.examinerNoun, 'interviewer'); // G3 seam
    expect(cfg.parseProfile.sectionHeadingLevel, 2); // G4 seam
    expect(cfg.parseProfile.fileExtensions, {'md'});
    expect(cfg.parseProfile.wikilinks, isTrue);
  });

  test('the exemplar card parses cleanly under the example config', () async {
    final cards = [
      for (final path in await source.listCardPaths())
        if (const CardParser()
                .parse(await source.readCard(path), filePath: path)
            case final c?)
          c,
    ];
    final bin = cards.firstWhere((c) => c.id == 'binary-search');
    expect(bin.title, 'Binary Search');
    expect(bin.type, 'flashcard');

    final quiz = {for (final s in bin.sections) s.heading: s.quizzable};
    expect(quiz['When to Use'], isTrue); // a load-bearing recall section
    expect(quiz['Resources'], isFalse); // reference-only (blocklist)
    expect(quiz['Related'], isFalse);
    expect(bin.wikilinks, containsAll(['sorting', 'two-pointers']));
  });
}
