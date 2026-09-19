part of 'insights_screen.dart';

// ── 1. Mock-interview skills ────────────────────────────────────────────────

class _MockSkillsSection extends ConsumerWidget {
  const _MockSkillsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(mockSkillsProvider);
    return _Section(
      title: 'Mock-interview skills',
      subtitle: 'How you perform under pressure — not just what you recall.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (m) {
          if (m.isEmpty) {
            return const _NoData(
                'No mock interviews yet — run one to see your rubric.');
          }
          final keys = [
            for (final k in sweRubricDimensions)
              if (m.dims.containsKey(k)) k,
            for (final k in m.dims.keys)
              if (!sweRubricDimensions.contains(k)) k,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.count} mock${m.count == 1 ? '' : 's'} · avg score '
                '${m.avgScore.round()} · hints ~${m.avgHintLevel.toStringAsFixed(1)}/5 '
                '· ${(m.novelFraction * 100).round()}% novel',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              for (final k in keys)
                _StatBar(
                  label: rubricLabel(k),
                  fraction: m.dims[k]! / 5,
                  value: m.dims[k]!.toStringAsFixed(1),
                  color: _dimColor(m.dims[k]!, theme.colorScheme),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── 1a-ii. System-design mocks ──────────────────────────────────────────────
class _SystemDesignSection extends ConsumerWidget {
  const _SystemDesignSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(systemDesignSkillsProvider);
    return _Section(
      title: 'System-design mocks',
      subtitle: 'How you perform in full design interviews.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (m) {
          if (m.isEmpty) {
            return const _NoData(
                'No system-design mocks yet — run one to see your rubric.');
          }
          final keys = [
            for (final k in systemDesignRubricDimensions)
              if (m.dims.containsKey(k)) k,
            for (final k in m.dims.keys)
              if (!systemDesignRubricDimensions.contains(k)) k,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.count} mock${m.count == 1 ? '' : 's'} · avg score '
                '${m.avgScore.round()}/100',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              for (final k in keys)
                _StatBar(
                  label: rubricLabel(k),
                  fraction: m.dims[k]! / 5,
                  value: m.dims[k]!.toStringAsFixed(1),
                  color: _dimColor(m.dims[k]!, theme.colorScheme),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── 1a-iii. Behavioral mocks ────────────────────────────────────────────────
class _BehavioralSection extends ConsumerWidget {
  const _BehavioralSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(behavioralSkillsProvider);
    return _Section(
      title: 'Behavioral mocks',
      subtitle: 'How you deliver your STAR stories under probing.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (m) {
          if (m.isEmpty) {
            return const _NoData(
                'No behavioral mocks yet — run one from Interview prep.');
          }
          final keys = [
            for (final k in behavioralRubricDimensions)
              if (m.dims.containsKey(k)) k,
            for (final k in m.dims.keys)
              if (!behavioralRubricDimensions.contains(k)) k,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.count} mock${m.count == 1 ? '' : 's'} · avg score '
                '${m.avgScore.round()}/100',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              for (final k in keys)
                _StatBar(
                  label: rubricLabel(k),
                  fraction: m.dims[k]! / 5,
                  value: m.dims[k]!.toStringAsFixed(1),
                  color: _dimColor(m.dims[k]!, theme.colorScheme),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── 1b. Algorithm practice ──────────────────────────────────────────────────

class _AlgoSection extends ConsumerWidget {
  const _AlgoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(algoStatsProvider);
    final recognition = ref.watch(algoRecognitionProvider).asData?.value;
    return _Section(
      title: 'Algorithm practice',
      subtitle: 'Solving problems cold — the execution clock. Counts toward '
          'readiness alongside recall.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (a) {
          if (a.isEmpty) {
            return const _NoData(
                'No problems logged yet — work the Algorithms track.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${a.distinctProblems} problem${a.distinctProblems == 1 ? '' : 's'} '
                'across ${a.patterns} pattern${a.patterns == 1 ? '' : 's'} · '
                '${a.logged} solve${a.logged == 1 ? '' : 's'} logged · '
                '${a.last7} this week',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              _StatBar(
                label: 'Clean-solve rate',
                fraction: a.cleanRate,
                value: '${(a.cleanRate * 100).round()}%',
                color: _recallColor(a.cleanRate, theme.colorScheme),
                subtitle: 'Solved without a hint or a struggle.',
              ),
              if (recognition != null && recognition.maintained > 0)
                Text(
                  'Explain clock: ${recognition.maintained} '
                  'problem${recognition.maintained == 1 ? '' : 's'} kept sharp'
                  '${recognition.due > 0 ? ' · ${recognition.due} due to explain' : ''}.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── 1c. Patterns mastered ───────────────────────────────────────────────────

class _PatternsSection extends ConsumerWidget {
  const _PatternsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(patternMasteryProvider);
    return _Section(
      title: 'Patterns mastered',
      subtitle: 'How much of each pattern you can durably solve — the goal is '
          'breadth across patterns, not depth on a few.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (patterns) {
          if (patterns.isEmpty) {
            return const _NoData(
                'No algorithm patterns yet — add some to your vault.');
          }
          final mastered = patterns.where((p) => p.mastered).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$mastered of ${patterns.length} '
                'pattern${patterns.length == 1 ? '' : 's'} mastered',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              for (final p in patterns) _patternBar(context, p),
            ],
          );
        },
      ),
    );
  }

  Widget _patternBar(BuildContext context, PatternMastery p) {
    final cs = Theme.of(context).colorScheme;
    final color = p.mastered ? StatusColor.good : _recallColor(p.score, cs);
    return _StatBar(
      label: p.pattern,
      fraction: p.score,
      value: p.mastered ? '✓' : '${(p.score * 100).round()}%',
      color: color,
      subtitle: '${p.started}/${p.total} problems solved'
          '${p.mastered ? ' · mastered' : (p.started == 0 ? ' · not started' : '')}',
    );
  }
}

// ── 2. Retention by domain ──────────────────────────────────────────────────

class _RetentionSection extends ConsumerWidget {
  const _RetentionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(retentionByDomainProvider);
    return _Section(
      title: 'Retention by domain',
      subtitle: 'Recall (you didn’t forget) and how durable it is, '
          'last ${retentionWindow.inDays} days.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (domains) {
          if (domains.isEmpty) {
            return const _NoData('Review some cards to see this.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final d in domains) _domainBar(context, d)],
          );
        },
      ),
    );
  }

  Widget _domainBar(BuildContext context, DomainRetention d) {
    final cs = Theme.of(context).colorScheme;
    final recall = d.recall;
    final parts = <String>[
      if (d.avgStabilityDays != null)
        'stability ~${d.avgStabilityDays!.round()}d',
      if (recall != null)
        '${d.reviews} reviews'
      else if (d.reviews == 0)
        'no reviews yet'
      else
        'only ${d.reviews} review${d.reviews == 1 ? '' : 's'} — keep going',
    ];
    return _StatBar(
      label: prettyDomain(d.domain),
      fraction: recall,
      value: recall == null ? '—' : '${(recall * 100).round()}%',
      color: recall == null ? cs.onSurfaceVariant : _recallColor(recall, cs),
      subtitle: parts.join(' · '),
    );
  }
}

// ── 3. Upcoming review load ─────────────────────────────────────────────────

class _DueForecastSection extends ConsumerWidget {
  const _DueForecastSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dueForecastProvider);
    return _Section(
      title: 'Upcoming review load',
      subtitle: 'Cards coming due over the next 2 weeks — spot a crunch early.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (counts) {
          final total = counts.fold(0, (a, b) => a + b);
          if (total == 0) {
            return const _NoData('Nothing due in the next 2 weeks.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BarStrip(values: counts),
              const _StripAxis('Due now', '+2 weeks'),
              const SizedBox(height: 6),
              Text('${counts.first} due now · $total over the next 2 weeks',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          );
        },
      ),
    );
  }
}

// ── 4. Struggling cards ─────────────────────────────────────────────────────

class _StrugglingSection extends ConsumerWidget {
  const _StrugglingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(strugglingCardsProvider);
    return _Section(
      title: 'Struggling cards',
      subtitle: 'Where you keep pressing “Again” — worth reformulating or '
          'splitting.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (cards) {
          if (cards.isEmpty) {
            return const _NoData('No repeat lapses — nothing to fix.');
          }
          return Column(
            children: [
              for (final c in cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 16, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(c.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text('${c.lapses} lapses / ${c.reviews}',
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── 5. Study consistency ────────────────────────────────────────────────────

class _ConsistencySection extends ConsumerWidget {
  const _ConsistencySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studyConsistencyProvider);
    // Consistency is a cross-subject habit (the activity log isn't card-scoped),
    // so under multiple goals it's honestly labelled "all subjects" — unlike the
    // other panels, it isn't this lane's number.
    final multiGoal =
        (ref.watch(activeGoalCountProvider).asData?.value ?? 1) >= 2;
    return _Section(
      title: 'Study consistency',
      subtitle: multiGoal
          ? 'Study actions per day across all subjects, last 4 weeks. Showing '
              'up beats cramming.'
          : 'Study actions per day, last 4 weeks. Showing up beats cramming.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (counts) {
          final activeDays = counts.where((c) => c > 0).length;
          if (activeDays == 0) return const _NoData('No study logged yet.');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BarStrip(values: counts, height: 48),
              const _StripAxis('4 weeks ago', 'Today'),
              const SizedBox(height: 6),
              Text('Studied $activeDays of the last ${counts.length} days',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          );
        },
      ),
    );
  }
}
