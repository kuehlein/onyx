import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/practice/practice.dart';
import '../models/card.dart';
import 'vault.dart';

part 'practice.g.dart';

/// The practice set for a domain — a small, applied-first list of cards drawn
/// from the live index. Non-grading; used by the "do more" flow after the day's
/// reviews are cleared.
@riverpod
Future<List<Card>> practiceSet(Ref ref, String domain) async {
  final index = await ref.watch(vaultIndexProvider.future);
  return buildPracticeSet(cards: index.cards, domain: domain);
}
