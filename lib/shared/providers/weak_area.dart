import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/readiness_report.dart';
import '../../core/ai/weak_area.dart';
import 'ai.dart';
import 'readiness_report.dart';

part 'weak_area.g.dart';

/// A failure producing the weak-area drill-down — a user-presentable message.
/// [needsKey] is set when AI is off, so the UI can offer to add a key.
class WeakAreaException implements Exception {
  WeakAreaException(this.message, {this.needsKey = false});
  final String message;
  final bool needsKey;
  @override
  String toString() => 'WeakAreaException: $message';
}

/// The AI weak-area drill-down (task #23): a focused explanation of why one
/// [domain] (its raw key) is where it is, plus a couple of targeted next steps.
///
/// A cheap, focused Q&A-style call on the DEFAULT (Haiku) model — unlike the
/// heavy Sonnet holistic report. Reuses [readinessReportData] (the same gathered
/// per-domain evidence the report uses) and matches the tapped domain by its raw
/// key. `autoDispose` family: caches per-domain for the session and re-runs if
/// the readiness data changes; deliberately NOT disk-cached (cheap + wants
/// freshness).
@riverpod
Future<String> weakAreaAnalysis(Ref ref, String domain) async {
  // Register the dependency reads before the first await so disposal/rebuild
  // tracking is correct.
  final claude = ref.watch(claudeServiceProvider);
  final dataFuture = ref.watch(readinessReportDataProvider.future);

  if (claude == null) {
    throw WeakAreaException(
      'Add your Anthropic API key in Settings to explain this domain.',
      needsKey: true,
    );
  }

  final data = await dataFuture;
  // Match on the raw domain key (the dashboard bars carry it); fall back to the
  // pretty name in case a caller passed that.
  DomainReportRow? row;
  for (final r in data.domains) {
    if (r.domain == domain) {
      row = r;
      break;
    }
  }
  row ??= () {
    for (final r in data.domains) {
      if (r.name == domain) return r;
    }
    return null;
  }();
  if (row == null) {
    throw WeakAreaException('No readiness data for this domain yet.');
  }

  return claude.chat(
    system: buildWeakAreaSystem(),
    messages: [
      (
        role: 'user',
        content: buildWeakAreaUser(
          row,
          targetLabel: data.targetLabel,
          daysToInterview: data.daysToInterview,
          interviewTested: data.interviewTested,
        ),
      ),
    ],
    maxTokens: 700,
  );
}
