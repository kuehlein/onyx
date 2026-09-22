import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart' show ErrorReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a hardcoded card-**type** comparison — `card.type == kTypeAlgorithm`,
/// `c.type != 'flashcard'`, etc. — the "if/else on card type" that architecture
/// invariant #2 forbids. Behavior must dispatch through the flow/subject config
/// (`SubjectConfig.flowForType` / `isPracticeTrackType` / `isApproachType`, a
/// `FlowSpec` field, or `Card.isPracticeTrack` / `isApproachCard`), so that a new
/// subject is config, never an app-code branch — the drift this project is
/// actively burning down (#92).
///
/// Precise by construction: a comparison to a *dynamic* value passes, so
/// `c.type == flow.cardType` (the CORRECT config-driven pattern — the RHS is
/// config, not a constant) is NOT flagged. Only a `kType…` constant or one of the
/// known built-in type string literals trips it.
///
/// Two deliberate exemptions:
///  - the subject/config layer (`lib/core/subject/`), which *defines* the flows
///    and the `kType…` constants — exempt here by path;
///  - the built-in SWE flow engines (the algorithm / system-design / behavioral
///    providers + their screens), each carrying an `ignore` with its reason: they
///    ARE one specific built-in flow's runtime, and a NEW subject uses the generic
///    vault-flow path (`flow_runner`) instead, so the invariant still holds.
class NoCardTypeBranch extends DartLintRule {
  const NoCardTypeBranch() : super(code: _code);

  static const _code = LintCode(
    name: 'no_card_type_branch',
    problemMessage:
        'Hardcoded card-type branch — dispatch through the flow/subject config '
        '(invariant #2), not `card.type == <constant>`.',
    correctionMessage:
        'Use a config predicate (flowForType / isPracticeTrackType / '
        'isApproachType / Card.isPracticeTrack) or a FlowSpec field, or compare '
        'against a config value (c.type == flow.cardType).',
    errorSeverity: ErrorSeverity.WARNING,
  );

  /// The built-in SWE card-type string values — a bare literal comparison to one
  /// of these is the same branch as comparing to its `kType…` constant.
  static const _builtinTypeLiterals = {
    'flashcard',
    'interview-question',
    'algorithm',
    'system-design',
    'behavioral',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // The config layer defines the flows + the `kType…` constants themselves.
    if (resolver.path.contains('/core/subject/')) return;

    context.registry.addBinaryExpression((node) {
      final op = node.operator.lexeme;
      if (op != '==' && op != '!=') return;
      final left = node.leftOperand;
      final right = node.rightOperand;
      // One side must be a `.type` access, the other a card-type constant/literal.
      final Expression? typeSide = _isTypeAccess(left)
          ? left
          : _isTypeAccess(right)
              ? right
              : null;
      if (typeSide == null) return;
      final other = identical(typeSide, left) ? right : left;
      if (_isCardTypeConstant(other)) reporter.atNode(node, _code);
    });
  }

  /// A property access named `type` (e.g. `c.type`, `widget.card.type`).
  bool _isTypeAccess(Expression e) {
    if (e is PrefixedIdentifier) return e.identifier.name == 'type';
    if (e is PropertyAccess) return e.propertyName.name == 'type';
    return false;
  }

  /// A `kType…` constant reference or a known built-in card-type string literal.
  bool _isCardTypeConstant(Expression e) {
    if (e is SimpleIdentifier && e.name.startsWith('kType')) return true;
    if (e is SimpleStringLiteral && _builtinTypeLiterals.contains(e.value)) {
      return true;
    }
    return false;
  }
}
