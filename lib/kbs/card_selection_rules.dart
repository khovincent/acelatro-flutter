// lib/kbs/card_selection_rules.dart

import '../models/card_model.dart';
import 'frame.dart';
import 'rule_base.dart';

/// Rules to pick which card indices to play or discard
class CardSelectionRules {
  static List<Rule> getRules() {
    return [
      Rule(
        name: 'Recommend Combo Cards',
        description: 'Select indices of cards in the chosen combo',
        priority: 50,
        condition: (wm) =>
            (wm.slots['decision'] as String?)?.startsWith('play') ?? false,
        action: (wm) {
          final combos = wm.gs.analyzeHand();
          if (combos.isEmpty) return;
          final bestCards = combos.first.cards;
          final indices = <int>[];

          // for each card in the best combo, find one matching index in hand
          for (var card in bestCards) {
            for (var i = 0; i < wm.gs.hand.length; i++) {
              final c = wm.gs.hand[i];
              if (c.suit == card.suit &&
                  c.value == card.value &&
                  !indices.contains(i)) {
                indices.add(i);
                break;
              }
            }
          }

          wm.slots['recommendedCardIndices'] = indices;
        },
      ),
      Rule(
        name: 'Recommend Discard Cards',
        description:
            'Select lowest‑value or non‑contributing cards for discard',
        priority: 40,
        condition: (wm) =>
            (wm.slots['decision'] as String?)?.startsWith('discard') ?? false,
        action: (wm) {
          final gs = wm.gs;
          final topCombos = gs.analyzeHand().take(3);
          final valuable = topCombos.expand((c) => c.cards).toSet();
          final candidates = <int>[];

          // first pick any card not in those top combos
          for (var i = 0; i < gs.hand.length; i++) {
            if (!valuable.contains(gs.hand[i])) {
              candidates.add(i);
            }
          }

          // fallback: pick lowest‐value cards
          if (candidates.isEmpty) {
            final sorted = gs.hand.asMap().entries.toList()
              ..sort((a, b) => a.value.value.compareTo(b.value.value));
            candidates.addAll(sorted.map((e) => e.key));
          }

          wm.slots['recommendedCardIndices'] = candidates.take(5).toList();
        },
      ),
    ];
  }
}
