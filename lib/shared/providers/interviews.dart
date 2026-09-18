import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/goal/interview_aim.dart';
import 'study_goals.dart';
part 'interviews.g.dart';

/// The active study goal's interviews (Phase B) — the interview cluster reads
/// these; writes go through [StudyGoals.upsertInterview] etc. with the active id.
@riverpod
Future<List<InterviewAim>> activeInterviews(Ref ref) async =>
    (await ref.watch(activeStudyGoalProvider.future)).interviews;
