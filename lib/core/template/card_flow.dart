import '../../shared/models/card.dart';
import 'active_template.dart';
import 'flow_spec.dart';

export 'flow_spec.dart' show FlowSpec, SchedulingModel, QuizzabilityPolicy;

/// Card → flow resolution, layered **on top of** the [Card] model so the domain model
/// never depends "up" on the flow/query config (which would cycle:
/// `flow_spec → card_query → card`). Engines that need to dispatch on a card's flow
/// import this and use `card.flow` / `card.schedulingModel` — the config-driven
/// alternative to a hardcoded `type == kType…` branch (invariant #2, ADR-0020).
extension CardFlow on Card {
  /// The [FlowSpec] this card belongs to — the first flow whose [FlowSpec.selector]
  /// matches it, resolved against this card's OWN subject config (task #30d;
  /// single-subject vaults resolve to the one active subject), else the subject's
  /// [DeckTemplate.defaultFlow] (ADR-0023) so this resolves the SAME flow the parser
  /// did. Null only when the subject declares no flows. With the default
  /// `type:`-matching selectors a recognized card matches its own flow — exactly the
  /// pre-selector `flowForType(type)` lookup — so SWE is unchanged.
  FlowSpec? get flow {
    final template = templateFor(templateId);
    for (final f in template.flows) {
      if (f.selector.matches(this)) return f;
    }
    return template.defaultFlow;
  }

  /// This card's [SchedulingModel] (recall / twoClock / mock), or null only when the
  /// subject declares no flows. Lets an engine dispatch on the *model* (e.g. the
  /// algorithms two-clock) rather than a card-type branch.
  SchedulingModel? get schedulingModel => flow?.scheduling;
}
