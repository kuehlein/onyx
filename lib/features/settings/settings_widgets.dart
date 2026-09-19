part of 'settings_screen.dart';

/// A "what-if" pace planner: drag the new-sections/day and see when relevance-
/// weighted recall readiness would cross your target, reusing the same forecast
/// curve as Home's calendar (#49). Lets you apply the pace in one tap, so
/// planning and the actual setting stay in sync.
class _PacePlanner extends ConsumerStatefulWidget {
  const _PacePlanner();

  @override
  ConsumerState<_PacePlanner> createState() => _PacePlannerState();
}

class _PacePlannerState extends ConsumerState<_PacePlanner> {
  int? _perDay; // null → track the saved new-cards/day

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final async = ref.watch(readinessForecastProvider);
    final r = ref.watch(readinessProvider).asData?.value;
    final limit = ref.watch(newCardLimitProvider).asData?.value ??
        NewCardLimit.defaultValue;

    if (async.isLoading) {
      return const ListTile(
        leading: Icon(Icons.timeline_outlined),
        title: Text('Pace planner'),
        subtitle: Text('Estimating your timeline…'),
      );
    }
    final f = async.asData?.value;
    if (f == null) {
      return ListTile(
        leading: const Icon(Icons.timeline_outlined),
        title: const Text('Pace planner'),
        subtitle: Text(
            'Set a target on Home and study a little to plan a pace.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      );
    }
    if (f.alreadyReady) {
      return ListTile(
        leading: const Icon(Icons.timeline_outlined),
        title: const Text('Pace planner'),
        subtitle: Text('You’re already at your target for this aim.',
            style:
                theme.textTheme.bodySmall?.copyWith(color: StatusColor.good)),
      );
    }

    final perDay = _perDay ?? f.currentPerDay;
    // Slider spans a light floor up to the fastest pace we simulated. Cap the
    // lower clamp bound at NewCardLimit.max: dragging to the far end makes perDay
    // reach the max, and clamp(perDay + 1, max) would throw (lower > upper).
    final headroom =
        (perDay + 1) > NewCardLimit.max ? NewCardLimit.max : perDay + 1;
    final maxPace = f.maxSampledPerDay.clamp(headroom, NewCardLimit.max);
    const minPace = NewCardLimit.min;
    final value = perDay.clamp(minPace, maxPace);

    // Two DISTINCT, non-competing dates (see the coverage-vs-readiness split):
    //   1. Coverage: when you'll have SEEN every section at this pace (cheap,
    //      linear — remaining / pace). This is "time to get through the deck".
    //   2. Readiness: when recall MATURES past the target (the FSRS forecast).
    // Readiness is always on/after coverage — covering is the prerequisite.
    final total = r == null ? 0 : r.domains.fold(0, (a, d) => a + d.total);
    final studied = r == null ? 0 : r.domains.fold(0, (a, d) => a + d.studied);
    final remaining = (total - studied).clamp(0, total);
    final coveragePct = total == 0 ? 0 : (studied / total * 100).round();
    final coverDate = remaining == 0
        ? null
        : f.today.add(Duration(days: (remaining / value).ceil()));
    final coverText =
        remaining == 0 ? 'done — all cards seen' : _fmtDate(coverDate!);
    final readyDate = f.readyDateFor(value);
    final readyText = readyDate == null
        ? 'over a year out at this pace'
        : _fmtDate(readyDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.timeline_outlined, color: muted),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('At ~$value new/day:',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    _PaceLine(
                        label: 'Get through all cards',
                        value: coverText,
                        color: theme.colorScheme.primary),
                    _PaceLine(
                        label: 'Interview-ready',
                        value: readyText,
                        color: StatusColor.good),
                    const SizedBox(height: 4),
                    Text(
                      total == 0
                          ? 'A what-if forecast for your saved target.'
                          : 'Covered ~$coveragePct% so far. Seeing the material '
                              'comes first; reviews then deepen it into readiness '
                              '(recall only — mocks are a separate axis).',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Slider(
            value: value.toDouble(),
            min: minPace.toDouble(),
            max: maxPace.toDouble(),
            divisions: (maxPace - minPace).clamp(1, 100),
            label: '$value/day',
            onChanged: (v) => setState(() => _perDay = v.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
          child: Row(
            children: [
              Text('Your pace: $limit/day',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              const Spacer(),
              if (value != limit)
                TextButton(
                  onPressed: () {
                    ref.read(newCardLimitProvider.notifier).set(value);
                    setState(() => _perDay = null); // follow the saved value
                  },
                  child: Text('Set to $value/day'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

/// One labeled milestone line in the pace planner (a color dot + "label:
/// value"), used to show the coverage and readiness dates distinctly.
class _PaceLine extends StatelessWidget {
  const _PaceLine(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(text: '$label: '),
                TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

/// A plain-language load rating for a daily problems-per-day target, grounded in
/// interview-prep guidance: ~1–2/day is sustainable, 3–4 is intense, 5+ risks
/// burnout and shallow retention (mitigated here by spaced re-solving).
String _algoLoadLabel(int perDay) {
  if (perDay <= 2) return 'light';
  if (perDay <= 4) return 'moderate';
  if (perDay <= 6) return 'heavy';
  return 'very heavy';
}

/// The Algorithms daily range (min floor / max ceiling), each a compact stepper
/// with a plain-language load read on the ceiling.
class _AlgoDailySetting extends ConsumerWidget {
  const _AlgoDailySetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final min = ref.watch(algoDailyMinProvider).asData?.value;
    final max = ref.watch(algoDailyMaxProvider).asData?.value;
    if (min == null || max == null) {
      return const ListTile(
        leading: Icon(Icons.terminal_outlined),
        title: Text('Problems per day'),
        subtitle: Text('Loading…'),
      );
    }
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.terminal_outlined),
          title: const Text('Problems per day'),
          subtitle: Text(
              '$min–$max per day — up to $max is a ${_algoLoadLabel(max)} load. '
              'A quiet day still gets at least $min (topped up with new '
              'problems); a busy day is capped at $max so due re-solves can’t '
              'pile up.'),
        ),
        ListTile(
          title: const Text('Fewest per day'),
          trailing: _Stepper(
            value: min,
            min: AlgoDailyMin.min,
            max: AlgoDailyMin.max,
            step: AlgoDailyMin.step,
            onChanged: (v) => ref.read(algoDailyMinProvider.notifier).set(v),
          ),
        ),
        ListTile(
          title: const Text('Most per day'),
          trailing: _Stepper(
            value: max,
            min: AlgoDailyMax.min,
            max: AlgoDailyMax.max,
            step: AlgoDailyMax.step,
            onChanged: (v) => ref.read(algoDailyMaxProvider.notifier).set(v),
          ),
        ),
      ],
    );
  }
}

/// A compact −/value/+ stepper for an integer setting, clamped to the
/// NewCardLimit range and moving in its step.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onChanged,
    this.min = NewCardLimit.min,
    this.max = NewCardLimit.max,
    this.step = NewCardLimit.step,
  });

  final int value;
  final void Function(int) onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          visualDensity: VisualDensity.compact,
          onPressed: value > min ? () => onChanged(value - step) : null,
        ),
        SizedBox(
          width: 34,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          visualDensity: VisualDensity.compact,
          onPressed: value < max ? () => onChanged(value + step) : null,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
