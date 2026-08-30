import '../../shared/models/card.dart';

/// Builds a small, concrete "practice set" for a domain — the evidence-based
/// use of extra study time. It surfaces *applied* work (interview-question
/// cards) first, since transfer/problem-solving is the gap recall can't close,
/// then concept cards, foundational tiers first. Practice is deliberately
/// non-grading (it never writes an FSRS review), so it doesn't corrupt the
/// spaced-repetition schedule or become a way to re-drill due cards.
List<Card> buildPracticeSet({
  required List<Card> cards,
  required String domain,
  int limit = 5,
}) {
  final inDomain = [
    for (final c in cards)
      if (c.domain == domain) c,
  ];

  inDomain.sort((a, b) {
    // Applied problems (interview questions) first.
    final aApplied = a.type == CardType.interviewQuestion ? 0 : 1;
    final bApplied = b.type == CardType.interviewQuestion ? 0 : 1;
    if (aApplied != bApplied) return aApplied.compareTo(bApplied);
    // Then foundational tiers first (tier 1 = most foundational).
    final aTier = a.tiers[domain] ?? 99;
    final bTier = b.tiers[domain] ?? 99;
    if (aTier != bTier) return aTier.compareTo(bTier);
    return a.title.compareTo(b.title);
  });

  return inDomain.take(limit).toList();
}

/// The section a practice card's coach should treat as the "answer" reference —
/// its first quizzable section, else its first section, else null.
CardSection? practiceAnswerSection(Card card) {
  for (final s in card.sections) {
    if (s.quizzable) return s;
  }
  return card.sections.isEmpty ? null : card.sections.first;
}
