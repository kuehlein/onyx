import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deck/deck.dart';
import '../../core/readiness/feasibility.dart';
import '../../core/readiness/readiness.dart';
import '../../core/template/active_template.dart';
import '../../shared/providers/decks.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/template.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/status_pill.dart';
import '../interview/interview_planner_sheet.dart';
import '../interview/interview_sheet.dart';
import 'target_sheet.dart';

/// The per-deck **Aims surface** (S5e / ADR-0009) — one calm place to see the
/// deck's aims: a weakest-link readiness band, then a list of aim rows (each with
/// its status + feasibility signal + date), with ended aims collapsed. A deck with
/// no aims reads as "building coverage", never a phantom interview.
///
/// Reached at `/aims` (Home's readiness chip + the interview-prep hub). A row taps
/// into the per-aim editor (live aim) or its outcome/debrief (ended); the AppBar
/// "+" adds a target aim, and the planner FAB adds a dated interview (assessment
/// decks only). Open-ended aims read as coverage (steady pace, no ready-by).
class AimsScreen extends ConsumerWidget {
  const AimsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deckAsync = ref.watch(activeDeckProvider);
    final feas = ref.watch(aimFeasibilityProvider).asData?.value ?? const [];
    final readiness = ref.watch(readinessProvider).asData?.value;
    final vocab =
        ref.watch(activeDeckTemplateProvider).asData?.value.vocabulary ??
            activeTemplate.vocabulary;
    final assessment = vocab.assessmentNounTitle ?? 'Target';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your aims'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add an aim',
            onPressed: () => showAimEditorSheet(context),
          ),
        ],
      ),
      // Assessment subjects (SWE) can plan a specific dated interview via the AI
      // planner; the AppBar "+" adds a general/target aim. Neutral subjects have
      // no assessment loop, so only the "+".
      floatingActionButton: vocab.hasAssessment
          ? FloatingActionButton.extended(
              onPressed: () => showInterviewPlannerSheet(context),
              icon: const Icon(Icons.add),
              label: Text('Plan ${_withArticle(vocab.assessmentNoun!)}'),
            )
          : null,
      body: deckAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goal) {
          final feasById = {for (final e in feas) e.aim.id: e.feasibility};
          final live = [
            for (final a in goal.aims)
              if (!a.status.isEnded) a
          ]..sort(_liveOrder);
          final past = [
            for (final a in goal.aims)
              if (a.status.isEnded) a
          ];

          // No active aim → coverage, not a phantom interview. Pure 0-aim decks
          // center it; if only ended aims remain, keep the Past section reachable.
          if (live.isEmpty) {
            if (past.isEmpty) return _CoverageState(readiness: readiness);
            return ListView(
              padding: _listPadding,
              children: [
                _CoverageState(readiness: readiness),
                _PastAims(past: past, assessment: assessment),
              ],
            );
          }

          return ListView(
            padding: _listPadding,
            children: [
              if (readiness != null && !readiness.isEmpty)
                _Headline(readiness: readiness, activeCount: live.length),
              const SizedBox(height: Dim.space4),
              for (final a in live)
                _AimRow(
                  aim: a,
                  feasibility: feasById[a.id],
                  assessment: assessment,
                ),
              if (past.isNotEmpty)
                _PastAims(past: past, assessment: assessment),
            ],
          );
        },
      ),
    );
  }

  // Active before paused; within each, dated soonest-first, open-ended last.
  static int _liveOrder(Aim a, Aim b) {
    if (a.active != b.active) return a.active ? -1 : 1;
    final da = a.currentRound()?.date;
    final db = b.currentRound()?.date;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }
}

/// The deck's weakest-link readiness as an HONEST band (a range, never a
/// false-precise single number) + a bar + a plain-language "weakest of N" caption.
class _Headline extends StatelessWidget {
  const _Headline({required this.readiness, required this.activeCount});

  final Readiness readiness;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final lo = (readiness.low * 100).round();
    final hi = (readiness.high * 100).round();
    final caption = activeCount > 1
        ? 'Weakest of $activeCount active aims'
        : (readiness.interview ? 'Applied-tested' : 'Recall only');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$lo–$hi% ready',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: Dim.space2),
        ClipRRect(
          borderRadius: Dim.brChip,
          child: LinearProgressIndicator(
            value: readiness.overall.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation(StatusColor.info),
          ),
        ),
        const SizedBox(height: Dim.space1),
        Text(caption, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}

/// One aim, read-only: a leading glyph (dated / open-ended / paused), the name +
/// subtitle (round + date, or "Open-ended"), and a calm feasibility [StatusPill].
class _AimRow extends StatelessWidget {
  const _AimRow({
    required this.aim,
    required this.feasibility,
    required this.assessment,
  });

  final Aim aim;
  final AimFeasibility? feasibility;
  final String assessment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final open = feasibility?.status == FeasibilityStatus.openEnded ||
        aim.currentRound()?.date == null;
    final leading = aim.status.isEnded
        ? Icons.history
        : !aim.active
            ? Icons.pause_circle_outline
            : (open ? Icons.all_inclusive : Icons.event_outlined);
    final name = aim.companyName.isEmpty ? assessment : aim.companyName;
    final sub = _subtitle();

    // Merge the glyph + name + subtitle + pill into one semantics node so a screen
    // reader announces the row as a single button, not four fragments.
    return MergeSemantics(
      child: InkWell(
        // A live aim → edit its knobs; an ended one → its outcome/debrief history.
        onTap: () => aim.status.isEnded
            ? showInterviewSheet(context, aim.id)
            : showAimEditorSheet(context, aimId: aim.id),
        borderRadius: Dim.brCard,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Dim.space2, vertical: Dim.space3),
          child: Row(
            children: [
              Icon(leading, size: Dim.iconMd, color: muted),
              const SizedBox(width: Dim.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    if (sub.isNotEmpty)
                      Text(sub,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: muted)),
                  ],
                ),
              ),
              const SizedBox(width: Dim.space2),
              _statusPill(aim, feasibility),
              Icon(Icons.chevron_right, size: Dim.iconMd, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    if (aim.status.isEnded) {
      final d = aim.currentRound()?.date;
      return d == null ? '' : _fmtDate(d);
    }
    if (!aim.active) return 'Paused';
    final cur = aim.currentRound();
    final date = cur?.date;
    if (date == null) return 'Open-ended · steady pace';
    final round = cur!.type.label;
    final readyBy = feasibility?.readyBy;
    final ready = readyBy == null ? '' : ' · ready ~${_fmtDate(readyBy)}';
    return '$round · ${_fmtDate(date)}$ready';
  }
}

/// The per-aim status pill — an ended aim shows its OUTCOME (offer = good, else
/// muted), otherwise the calm feasibility signal. Never a red alarm: `behind` is
/// `warn` (not `bad`), `infeasible` reads "Too soon", a paused aim is a muted text
/// pill. Color + shape + label always together (never color-alone).
StatusPill _statusPill(Aim aim, AimFeasibility? f) {
  if (aim.status.isEnded) {
    return StatusPill(
        tone: aim.status == InterviewStatus.offer
            ? StatusTone.good
            : StatusTone.muted,
        label: aim.status.label,
        variant: StatusPillVariant.text,
        dense: true);
  }
  if (!aim.active) {
    return const StatusPill(
        tone: StatusTone.muted,
        label: 'Paused',
        variant: StatusPillVariant.text,
        dense: true);
  }
  final status = f?.status ?? FeasibilityStatus.unknown;
  switch (status) {
    case FeasibilityStatus.openEnded:
      return const StatusPill(
          tone: StatusTone.muted,
          label: 'Open-ended',
          icon: Icons.all_inclusive,
          variant: StatusPillVariant.outline,
          dense: true);
    case FeasibilityStatus.unknown:
      return const StatusPill(
          tone: StatusTone.muted,
          label: 'No data yet',
          variant: StatusPillVariant.outline,
          dense: true);
    case FeasibilityStatus.ready:
      return const StatusPill(
          tone: StatusTone.good,
          label: 'Ready',
          icon: Icons.check_circle,
          dense: true);
    case FeasibilityStatus.onTrack:
      return const StatusPill(
          tone: StatusTone.good,
          label: 'On track',
          icon: Icons.check_circle,
          dense: true);
    case FeasibilityStatus.behind:
      return const StatusPill(
          tone: StatusTone.warn,
          label: 'Behind',
          icon: Icons.trending_up,
          dense: true);
    case FeasibilityStatus.infeasible:
      return const StatusPill(
          tone: StatusTone.bad,
          label: 'Too soon',
          icon: Icons.priority_high,
          dense: true);
  }
}

/// A deck with no aims isn't empty — it's building coverage (scored against the
/// template's baseline). Shown instead of a phantom empty interview list.
class _CoverageState extends StatelessWidget {
  const _CoverageState({required this.readiness});

  final Readiness? readiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // The honest "how much have you seen" for a target-less deck is COVERAGE
    // (sections studied / in-scope total), not the readiness score — a 0-aim deck
    // is about breadth-so-far, not a graded bar.
    var studied = 0, total = 0;
    for (final d in readiness?.domains ?? const <DomainReadiness>[]) {
      studied += d.studied;
      total += d.total;
    }
    final coverage = total == 0 ? null : studied / total;
    final pct = coverage == null ? null : (coverage * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dim.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.all_inclusive,
                size: Dim.iconLg, color: theme.colorScheme.primary),
            const SizedBox(height: Dim.space4),
            Text('Building coverage',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: Dim.space3),
            if (coverage != null)
              ClipRRect(
                borderRadius: Dim.brChip,
                child: LinearProgressIndicator(
                  value: coverage.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation(StatusColor.info),
                ),
              ),
            const SizedBox(height: Dim.space3),
            Text(
              pct == null
                  ? 'No aim set — you\'re learning at a steady pace.'
                  : 'No aim set — $pct% of the deck seen, learning at a steady pace.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: Dim.space4),
            Align(
              child: FilledButton.tonalIcon(
                onPressed: () => showAimEditorSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Set an aim'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ended aims, collapsed by default (kept for the record).
class _PastAims extends StatefulWidget {
  const _PastAims({required this.past, required this.assessment});

  final List<Aim> past;
  final String assessment;

  @override
  State<_PastAims> createState() => _PastAimsState();
}

class _PastAimsState extends State<_PastAims> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Dim.space2),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: Dim.brChip,
          // minHeight 48 keeps the disclosure toggle a full tap target (a11y #79).
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dim.space2),
              child: Row(
                children: [
                  Icon(_open ? Icons.expand_more : Icons.chevron_right,
                      size: Dim.iconMd, color: muted),
                  const SizedBox(width: Dim.space2),
                  Text('Past (${widget.past.length})',
                      style:
                          theme.textTheme.labelLarge?.copyWith(color: muted)),
                ],
              ),
            ),
          ),
        ),
        if (_open)
          for (final a in widget.past)
            _AimRow(aim: a, feasibility: null, assessment: widget.assessment),
      ],
    );
  }
}

const _listPadding =
    EdgeInsets.fromLTRB(Dim.space3, Dim.space3, Dim.space3, 96);

/// "interview" → "an interview", "recital" → "a recital" — for the plan-a-… CTA.
String _withArticle(String noun) {
  final vowel = noun.isNotEmpty && 'aeiou'.contains(noun[0].toLowerCase());
  return '${vowel ? 'an' : 'a'} $noun';
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
  ];
  return '${months[d.month - 1]} ${d.day}';
}
