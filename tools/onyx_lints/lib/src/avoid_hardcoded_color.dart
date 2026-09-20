import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart' show ErrorReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a hardcoded color constructed outside the design layer —
/// `Color(0xFF..)`, `Color.fromARGB(..)`, `Color.fromRGBO(..)`. Colors must come
/// from the palette via `OnyxColors` / `StatusColor` / the M3 `ColorScheme`, so a
/// single source (and a future light / colorblind theme) stays authoritative
/// (design-system §2.5 "never hardcode a hex").
///
/// The palette itself (`lib/shared/design/`) is exempt — that's where raw colors
/// legitimately live.
class AvoidHardcodedColor extends DartLintRule {
  const AvoidHardcodedColor() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_hardcoded_color',
    problemMessage:
        'Hardcoded color — use OnyxColors / StatusColor / the ColorScheme.',
    correctionMessage:
        'Add the hue to the palette (lib/shared/design/_palette.dart) and '
        'surface it as a token; reference context.onyx / StatusColor here.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // The design layer is the one place raw colors are defined.
    if (resolver.path.contains('shared/design/')) return;

    context.registry.addInstanceCreationExpression((node) {
      if (node.constructorName.type.toSource() != 'Color') return;
      reporter.atNode(node, _code);
    });
  }
}
