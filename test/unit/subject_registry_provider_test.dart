import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/active_subject.dart';
import 'package:onyx/core/subject/neutral_subject.dart';
import 'package:onyx/core/subject/software_interviews.dart';
import 'package:onyx/core/subject/subject_config.dart';
import 'package:onyx/core/subject/subject_registry.dart';
import 'package:onyx/core/vault/vault_source.dart';
import 'package:onyx/shared/providers/subject.dart';
import 'package:onyx/shared/providers/vault.dart';

/// G7f golden: the default subject flipped from the SWE reference to the neutral
/// built-in for a config-less vault, and a vault opts back into SWE with a
/// one-line `id: software-interviews` config (resolved to the built-in verbatim).
class _FakeSource implements VaultSource {
  _FakeSource(this._configs);

  /// path → YAML content for each discovered config.
  final Map<String, String> _configs;

  @override
  String get rootLabel => 'fake';
  @override
  Future<List<String>> listCardPaths() async => const [];
  @override
  Future<List<String>> listAllPaths() async => const [];
  @override
  Future<List<String>> listConfigPaths() async => _configs.keys.toList();
  @override
  Future<String> readCard(String relativePath) async =>
      _configs[relativePath] ?? '';
  @override
  Future<String?> readMeta(String name) async => null;
  @override
  Future<void> writeMeta(String name, String content) async {}
  @override
  Future<void> writeFile(String relativePath, String content) async {}
  @override
  Future<void> deleteFile(String relativePath) async {}
}

void main() {
  // subjectRegistryProvider sets the process-wide activeSubject/activeRegistry as
  // a side effect — reset around each case so this test neither pollutes nor is
  // polluted by others (the pure-core placeholder is the SWE reference).
  void reset() {
    activeSubject = softwareInterviewsConfig;
    activeRegistry = SubjectRegistry.single(softwareInterviewsConfig);
  }

  setUp(reset);
  tearDown(reset);

  Future<SubjectConfig> primaryFor(Map<String, String> configs) async {
    final c = ProviderContainer(overrides: [
      vaultSourceProvider.overrideWithValue(_FakeSource(configs)),
    ]);
    addTearDown(c.dispose);
    return (await c.read(subjectRegistryProvider.future)).primary;
  }

  test('a config-less vault resolves to the neutral subject (flip)', () async {
    expect(await primaryFor(const {}), same(neutralSubjectConfig));
  });

  test('a one-line `id: software-interviews` opts back into the SWE reference',
      () async {
    final primary = await primaryFor(
        const {'_meta/onyx-subject.yaml': 'id: software-interviews'});
    expect(primary, same(softwareInterviewsConfig));
  });
}
