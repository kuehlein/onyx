import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/claude_service.dart';
import '../../core/ai/readiness_report.dart';
import '../../core/readiness/readiness.dart';
import '../../core/readiness/target.dart';
import 'ai.dart';
import 'clock.dart';
import 'readiness.dart';
import 'vault.dart';

part 'readiness_report.g.dart';

/// The state of the AI readiness report: the rendered Markdown (or null before
/// the first run), whether a request is in flight, the last error, and when it
/// was generated + the overall % it was based on (for the footer).
class ReadinessReportState {
  const ReadinessReportState({
    this.text,
    this.busy = false,
    this.error,
    this.generatedAt,
    this.basedOnOverall,
  });

  final String? text;
  final bool busy;
  final String? error;
  final DateTime? generatedAt;
  final double? basedOnOverall;

  bool get hasReport => text != null && text!.isNotEmpty;

  ReadinessReportState copyWith({
    String? text,
    bool? busy,
    String? error,
    bool clearError = false,
    DateTime? generatedAt,
    double? basedOnOverall,
  }) =>
      ReadinessReportState(
        text: text ?? this.text,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
        generatedAt: generatedAt ?? this.generatedAt,
        basedOnOverall: basedOnOverall ?? this.basedOnOverall,
      );
}

/// The AI interview-readiness report (task #24). Kept alive so a generated
/// report survives navigating away and back within a session (it is not
/// persisted — regenerating is cheap and keeps it fresh against new progress).
@Riverpod(keepAlive: true)
class ReadinessReport extends _$ReadinessReport {
  // A capable model: this is an infrequent, reasoning-heavy call, unlike the
  // high-frequency coach (which uses the cheap default).
  static const _model = 'claude-sonnet-4-6';

  @override
  ReadinessReportState build() => const ReadinessReportState();

  /// Gather the same data the dashboard shows, build the prompt, and ask Claude
  /// for the assessment. No-op while already busy.
  Future<void> generate() async {
    if (state.busy) return;
    final claude = ref.read(claudeServiceProvider);
    if (claude == null) {
      state = state.copyWith(
          error:
              'Add your Anthropic API key in Settings to generate a report.');
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final data = await _gather();
      final reply = await claude.complete(
        system: buildReadinessReportSystem(),
        prompt: buildReadinessReportUser(data),
        model: _model,
        maxTokens: 1600,
      );
      state = ReadinessReportState(
        text: reply,
        busy: false,
        generatedAt: (await ref.read(clockProvider.future)).now(),
        basedOnOverall: data.overall,
      );
    } on ClaudeException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Could not generate: $e');
    }
  }

  /// Assemble [ReadinessReportData] from readiness, the target, applied-evidence
  /// counts, and the deck's per-domain topic list.
  Future<ReadinessReportData> _gather() async {
    final readiness = await ref.read(readinessProvider.future);
    final target = await ref.read(readinessTargetControllerProvider.future);
    final summary = await ref.read(appliedSummaryProvider.future);
    final index = await ref.read(vaultIndexProvider.future);

    // Per-domain deck topics (card titles), so the model can reason about scope.
    final topicsByDomain = <String, List<String>>{};
    for (final c in index.cards) {
      final d = c.domain;
      if (d == null) continue;
      topicsByDomain.putIfAbsent(d, () => []).add(c.title);
    }

    int? daysToInterview;
    final date = target.interviewDate;
    if (date != null) {
      final today = (await ref.read(clockProvider.future)).today();
      daysToInterview =
          DateTime(date.year, date.month, date.day).difference(today).inDays;
      if (daysToInterview < 0) daysToInterview = 0;
    }

    final domains = [
      for (final dr in readiness.domains)
        DomainReportRow(
          name: prettyDomain(dr.domain),
          coverage: dr.coverage,
          strength: dr.strength,
          score: dr.score,
          transfer: dr.transfer,
          studied: dr.studied,
          total: dr.total,
          mocks: summary[dr.domain]?.attempts ?? 0,
          contested: summary[dr.domain]?.contested ?? 0,
          topics: topicsByDomain[dr.domain] ?? const [],
        ),
    ];

    return ReadinessReportData(
      targetLabel: target.label,
      level: target.level.label,
      company: target.company.label,
      track: target.track.label,
      overall: readiness.overall,
      low: readiness.low,
      high: readiness.high,
      interviewTested: readiness.interview,
      daysToInterview: daysToInterview,
      domains: domains,
    );
  }
}
