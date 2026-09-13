import 'software_interviews.dart';
import 'subject_config.dart';

/// The process-wide active subject config that pure core math (readiness target,
/// ladder, projection) reads. Defaults to the built-in SWE reference; the vault
/// loader (task #30 Phase 5) will set it once at startup from the vault, falling
/// back to this default when no vault config is present. Treated as write-once
/// app configuration — the app/provider layer is the only writer.
SubjectConfig activeSubject = softwareInterviewsConfig;
