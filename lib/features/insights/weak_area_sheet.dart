import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/readiness_report.dart';
import '../../core/util.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/ai.dart';
import '../../shared/providers/readiness_report.dart';
import '../../shared/providers/weak_area.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/sheet_header.dart';
import '../settings/api_key_sheet.dart';

/// Opens the weak-area drill-down (task #23) for one [domain] (its raw key,
/// e.g. `system-design`), titled with its [prettyName]. Tapped from a domain bar
/// on the readiness dashboard (Home + Insights). Shows the domain's stat chips
/// from the readiness data, then a focused AI explanation of *why* it's weak +
/// targeted next steps. Gated on an AI key being present.
Future<void> showWeakAreaSheet(
  BuildContext context,
  WidgetRef ref, {
  required String domain,
  required String prettyName,
}) {
  return showOnyxSheet<void>(
    context,
    builder: (_) => _WeakAreaSheet(domain: domain, prettyName: prettyName),
  );
}

class _WeakAreaSheet extends ConsumerWidget {
  const _WeakAreaSheet({required this.domain, required this.prettyName});

  final String domain;
  final String prettyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasKey = ref.watch(claudeServiceProvider) != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          title: prettyName,
          icon: Icons.insights_outlined,
        ),
        SheetScrollBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatChips(domain: domain),
              const SizedBox(height: Dim.space4),
              if (!hasKey) const _NoKey() else _Analysis(domain: domain),
            ],
          ),
        ),
      ],
    );
  }
}

/// A compact row of the domain's headline stats, read from the same readiness
/// data the AI reasons over — so the number and the narrative can't disagree.
class _StatChips extends ConsumerWidget {
  const _StatChips({required this.domain});

  final String domain;

  DomainReportRow? _rowFor(ReadinessReportData data) {
    for (final r in data.domains) {
      if (r.domain == domain) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(readinessReportDataProvider).asData?.value;
    final row = data == null ? null : _rowFor(data);
    if (row == null) return const SizedBox.shrink();
    final proven = row.transfer != null && row.mocks > 0;
    return Wrap(
      spacing: Dim.space2,
      runSpacing: Dim.space2,
      children: [
        _Chip(
          label: 'Readiness',
          value: '${pct(row.score)}%',
          color: _bandColor(row.score),
        ),
        _Chip(
          label: 'Coverage',
          value: '${pct(row.coverage)}%',
          color: _bandColor(row.coverage),
        ),
        _Chip(
          label: 'Strength',
          value: '${pct(row.strength)}%',
          color: _bandColor(row.strength),
        ),
        _Chip(
          label: 'Mocks',
          value: proven ? '${row.mocks}' : 'recall-only',
          color: proven ? StatusColor.good : StatusColor.muted,
        ),
      ],
    );
  }
}

/// Band color for a 0..1 score: red → amber → green, matching the dashboard bars.
Color _bandColor(double score) {
  if (score >= 0.75) return StatusColor.good;
  if (score >= 0.45) return StatusColor.warn;
  return StatusColor.bad;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Dim.space3, vertical: Dim.space2),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: Dim.brChip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: context.text.labelSmall
                  ?.copyWith(color: context.colors.onSurfaceVariant)),
          Text(value,
              style: context.text.labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// The AI explanation, with a plain spinner while it streams in.
class _Analysis extends ConsumerWidget {
  const _Analysis({required this.domain});

  final String domain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(weakAreaAnalysisProvider(domain)).when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: Dim.space5),
            child: LoadingView(label: 'Analyzing…'),
          ),
          error: (e, _) => Text(
            e is WeakAreaException
                ? e.message
                : 'Could not analyze this domain right now.',
            style: context.text.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant, height: 1.4),
          ),
          data: (text) => CardMarkdown(text),
        );
  }
}

/// Honest AI-off state: a short line + a one-tap way to add a key.
class _NoKey extends StatelessWidget {
  const _NoKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add an AI key to explain why this domain is weak and what to do next. '
          'The stats above work without AI.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: Dim.space4),
        FilledButton.tonal(
          onPressed: () {
            Navigator.of(context).pop();
            showApiKeySheet(context);
          },
          child: const Text('Add AI key'),
        ),
      ],
    );
  }
}
