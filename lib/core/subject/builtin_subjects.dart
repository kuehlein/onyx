import 'neutral_subject.dart';
import 'software_interviews.dart';
import 'subject_config.dart';
import 'subject_config_yaml.dart';

/// App-owned **built-in** subject templates, resolvable by id so a vault opts into
/// one with a one-line `id:` config instead of re-specifying every field (task #88
/// / G7f). Reserved ids — a vault wanting a custom subject uses its own id and a
/// full config. Lets the SWE reference stay app-owned (single source of truth) even
/// once a config-less folder defaults to [neutralSubjectConfig].
const builtInSubjects = <String, SubjectConfig>{
  'software-interviews': softwareInterviewsConfig,
  'general': neutralSubjectConfig,
};

/// Resolves a discovered config's YAML to a [SubjectConfig]: the built-in template
/// when the `id:` names one (opt-in-by-id), else a full parse of the YAML. Returns
/// null when the YAML is malformed, so discovery skips it (as before).
SubjectConfig? resolveSubjectConfig(String yaml) {
  final builtIn = builtInSubjects[subjectIdFromYaml(yaml)];
  if (builtIn != null) return builtIn;
  try {
    return subjectConfigFromYaml(yaml);
  } catch (_) {
    return null;
  }
}
