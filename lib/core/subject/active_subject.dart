import 'software_interviews.dart';
import 'subject_config.dart';
import 'subject_registry.dart';

/// The process-wide active subject config that pure core math (readiness target,
/// ladder, projection) reads. Defaults to the built-in SWE reference; the vault
/// loader (task #30 Phase 5) will set it once at startup from the vault, falling
/// back to this default when no vault config is present. Treated as write-once
/// app configuration — the app/provider layer is the only writer.
///
/// This is the *primary* subject; multi-subject-aware code (per-card behavior)
/// reads [activeRegistry] instead (task #30d, M2).
SubjectConfig activeSubject = softwareInterviewsConfig;

/// The process-wide registry of all subjects live in the vault (task #30d).
/// Per-card behavior (flow, quizzability, practice-track) resolves against the
/// card's own subject via [registryFor]. Defaults to a one-entry registry around
/// [activeSubject]; the provider layer sets it once at startup. In a
/// single-subject vault it holds exactly the primary, so behavior is unchanged.
SubjectRegistry activeRegistry =
    SubjectRegistry.single(softwareInterviewsConfig);

/// The subject config for [subjectId] — the owning subject from [activeRegistry],
/// falling back to [activeSubject] when the id is empty/unknown (e.g. a card
/// constructed without a subject in tests).
SubjectConfig subjectFor(String subjectId) =>
    activeRegistry.byId(subjectId) ?? activeSubject;
