import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart' show ErrorReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a raw numeric icon size — `Icon(size: 20)`, `IconButton(iconSize: 18)`,
/// `IconThemeData(size: 24)`, `ImageIcon(size: 16)` — and steers it to the `Dim`
/// icon scale (`Dim.iconSm` 16 / `Dim.iconMd` 20 / `Dim.iconLg` 44).
///
/// The whole app was swept onto that scale; this keeps a new edit (or an AI
/// agent working without the design context) from drifting back to ad-hoc sizes.
/// Only literal sizes are flagged — `Dim.iconMd` and other expressions pass, and
/// genuinely off-scale glyphs use a named const (which also isn't a literal here).
class AvoidRawIconSize extends DartLintRule {
  const AvoidRawIconSize() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_raw_icon_size',
    problemMessage:
        'Raw icon size — use the Dim icon scale (Dim.iconSm / iconMd / iconLg).',
    correctionMessage:
        'Replace the literal with Dim.iconSm (16), Dim.iconMd (20) or '
        'Dim.iconLg (44). A deliberately off-scale glyph gets a named const.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  /// Constructors whose `size:` argument is an icon size.
  static const _iconTypes = {'Icon', 'ImageIcon', 'IconThemeData'};

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedExpression((node) {
      final label = node.name.label.name;
      final isIconSize = label == 'iconSize';
      final isSize = label == 'size';
      if (!isIconSize && !isSize) return;

      final value = node.expression;
      if (value is! IntegerLiteral && value is! DoubleLiteral) return;

      // The named arg belongs directly to this constructor invocation.
      final call = node.parent?.parent;
      if (call is! InstanceCreationExpression) return;
      final typeName = call.constructorName.type.toSource();

      // `iconSize:` is icon-specific anywhere (IconButton); a bare `size:` only
      // counts on the icon widgets (a custom widget may have its own `size:`).
      if (isIconSize || _iconTypes.contains(typeName)) {
        reporter.atNode(value, _code);
      }
    });
  }
}
