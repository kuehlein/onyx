import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/ai.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/readiness_report.dart';
import '../../shared/widgets/card_markdown.dart';

/// The AI interview-readiness report (task #24): an honest narrative assessment
/// for the chosen target — strengths, gaps (including scope gaps the readiness
/// number can't see), and prioritised next steps.
///
/// The report is persisted and reused until the data changes: opening this screen
/// reuses the cached report for free if nothing has moved, and auto-regenerates
/// only after new study/reviews/mocks or an interview change (see [ReadinessReport]).
class ReadinessReportScreen extends ConsumerStatefulWidget {
  const ReadinessReportScreen({super.key});

  @override
  ConsumerState<ReadinessReportScreen> createState() =>
      _ReadinessReportScreenState();
}

class _ReadinessReportScreenState extends ConsumerState<ReadinessReportScreen> {
  @override
  void initState() {
    super.initState();
    // Reuse-or-regenerate on open: free if the data is unchanged, a fresh call
    // only when it has moved.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(readinessReportProvider.notifier).ensureFresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKey = ref.watch(claudeServiceProvider) != null;
    final report = ref.watch(readinessReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Readiness report')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: !hasKey
              ? _NeedsKey(theme)
              : report.busy
                  ? const _Busy()
                  : report.hasReport
                      ? _Report(report)
                      : _Intro(error: report.error),
        ),
      ),
    );
  }
}

class _NeedsKey extends StatelessWidget {
  const _NeedsKey(this.theme);
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('Add your Anthropic API key to generate a report.',
              textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'The report is written on-device with your own key — no Onyx server '
            'sees your data.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: () => context.go('/settings'),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3)),
        SizedBox(height: 16),
        Text('Analysing your progress and deck…'),
      ],
    );
  }
}

class _Intro extends ConsumerWidget {
  const _Intro({this.error});
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_outlined,
              size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('AI readiness report',
              style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Reads your progress and the topics in your deck, then assesses how '
            'ready you are for your target — including likely scope gaps the '
            'readiness score alone can’t see (it only knows your cards).',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            _ErrorNote(error!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => ref
                .read(readinessReportProvider.notifier)
                .generate(force: true),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Generate report'),
          ),
        ],
      ),
    );
  }
}

class _Report extends ConsumerWidget {
  const _Report(this.report);
  final ReadinessReportState report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: CardMarkdown(report.text!),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _footer(ref, report),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              if (report.error != null) ...[
                const SizedBox(width: 8),
                Flexible(child: _ErrorNote(report.error!, compact: true)),
              ],
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => ref
                    .read(readinessReportProvider.notifier)
                    .generate(force: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Regenerate'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _footer(WidgetRef ref, ReadinessReportState r) {
    final parts = <String>[];
    if (r.basedOnOverall != null) {
      parts.add('based on ${(r.basedOnOverall! * 100).round()}% readiness');
    }
    if (r.generatedAt != null) {
      final now = ref.read(clockProvider).asData?.value.now();
      parts.add('generated ${_ago(r.generatedAt!, now)}');
    }
    return parts.join(' · ');
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message, {this.compact = false});
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      maxLines: compact ? 2 : null,
      overflow: compact ? TextOverflow.ellipsis : null,
      textAlign: compact ? TextAlign.start : TextAlign.center,
      style: (compact ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
          ?.copyWith(color: theme.colorScheme.error),
    );
  }
}

/// A coarse "how long ago" label. [now] may be null (falls back to no relative).
String _ago(DateTime then, DateTime? now) {
  if (now == null) return 'just now';
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
