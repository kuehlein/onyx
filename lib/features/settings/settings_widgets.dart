part of 'settings_screen.dart';

/// A compact −/value/+ stepper for an integer setting, clamped to [min]..[max]
/// and moving in [step] (used by the daily-budget + gym-rest settings). Workload
/// knobs (pace, algo range) were removed — the engine derives the mix (ADR-0010).
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 100,
    this.step = 1,
  });

  final int value;
  final void Function(int) onChanged;
  final int min;
  final int max;
  final int step;

  // Fixed width of the centered value column so the +/- buttons don't shift as
  // the number's digit count changes.
  static const _valueWidth = 34.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Decrease',
          onPressed: value > min ? () => onChanged(value - step) : null,
        ),
        SizedBox(
          width: _valueWidth,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Increase',
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
      padding: const EdgeInsets.fromLTRB(
          Dim.space4, Dim.space5, Dim.space4, Dim.space2),
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
