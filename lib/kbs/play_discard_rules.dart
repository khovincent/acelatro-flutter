// lib/kbs/play_discard_rules.dart

import '../models/combo_definitions.dart';
import 'frame.dart';
import 'rule_base.dart';

/// Rules to decide PLAY vs DISCARD
class PlayDiscardRules {
  static List<Rule> getRules() {
    return [
      Rule(
        name: 'Play If Combo Meets Target',
        description: 'Play when top combo score ≥ points remaining to target',
        priority: 50,
        condition: (wm) {
          final gap = wm.gs.requiredPoints - wm.gs.currentPoints;
          final combos = wm.gs.analyzeHand();
          return combos.isNotEmpty && combos.first.score >= gap;
        },
        action: (wm) => wm.slots['decision'] = 'play:combo reaches target',
      ),
      Rule(
        name: 'Play Strong Combo Above Avg Needed',
        description:
            'Play if top combo score ≥ average needed per remaining hand',
        priority: 40,
        condition: (wm) {
          final gs = wm.gs;
          final gap = gs.requiredPoints - gs.currentPoints;
          final handsLeft = 4 - gs.playedCards.length ~/ 5;
          final avgNeeded = handsLeft > 0 ? gap / handsLeft : double.infinity;
          final combos = gs.analyzeHand();
          return combos.isNotEmpty && combos.first.score >= avgNeeded;
        },
        action: (wm) => wm.slots['decision'] = 'play:strong combo',
      ),
      Rule(
        name: 'Discard Weak Hand',
        description:
            'Discard when hand is weak (top combo < 30) and discards remain',
        priority: 30,
        condition: (wm) {
          final gs = wm.gs;
          final combos = gs.analyzeHand();
          final discardsLeft = 4 - gs.discardedCards.length ~/ 5;
          return discardsLeft > 0 &&
              (combos.isEmpty || combos.first.score < 30);
        },
        action: (wm) => wm.slots['decision'] = 'discard:weak hand',
      ),
      Rule(
        name: 'Fallback Play Reasonable',
        description: 'Play if nothing else triggered but combo ≥ 20',
        priority: 10,
        condition: (wm) {
          final combos = wm.gs.analyzeHand();
          return combos.isNotEmpty && combos.first.score >= 20;
        },
        action: (wm) => wm.slots['decision'] = 'play:fallback',
      ),
      Rule(
        name: 'Fallback Discard If Possible',
        description: 'Default to discard if no good combo and discards remain',
        priority: 5,
        condition: (wm) {
          final gs = wm.gs;
          final combos = gs.analyzeHand();
          final discardsLeft = 4 - gs.discardedCards.length ~/ 5;
          return (combos.isEmpty || combos.first.score < 20) &&
              discardsLeft > 0;
        },
        action: (wm) => wm.slots['decision'] = 'discard:fallback',
      ),
    ];
  }
}
