import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/avoid_hardcoded_color.dart';
import 'src/avoid_raw_icon_size.dart';

/// Entry point discovered by the `custom_lint` runner. Registers Onyx's
/// design-token rules; they run alongside riverpod_lint's (the runner aggregates
/// every dependency that exposes a `createPlugin`).
PluginBase createPlugin() => _OnyxLints();

class _OnyxLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        AvoidRawIconSize(),
        AvoidHardcodedColor(),
      ];
}
