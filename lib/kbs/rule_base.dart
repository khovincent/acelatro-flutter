// lib/kbs/rule_base.dart

import 'frame.dart';
import '../models/game_state.dart';
import '../models/combo_definitions.dart';

/// A single production rule with a condition and an action
class Rule {
  final String name;
  final String description;
  final int priority; // Higher = evaluated first
  final bool Function(GameStateFrame wm) condition;
  final void Function(GameStateFrame wm) action;
  bool fired = false;

  Rule({
    required this.name,
    required this.description,
    this.priority = 1,
    required this.condition,
    required this.action,
  });
}

/// A forward‑chaining inference engine
class InferenceEngine {
  final List<Rule> rules;
  final GameStateFrame wm;
  final List<String> activationHistory = [];

  InferenceEngine(this.rules, this.wm);

  void forwardChain() {
    // Sort rules by descending priority
    final sorted = [...rules]..sort((a, b) => b.priority - a.priority);
    bool any;
    do {
      any = false;
      for (var rule in sorted) {
        if (!rule.fired && rule.condition(wm)) {
          rule.action(wm);
          rule.fired = true;
          activationHistory.add('Fired rule: ${rule.name}');
          any = true;
        }
      }
    } while (any);
  }

  /// Returns all rules whose condition holds right now
  List<Rule> getApplicableRules() =>
      rules.where((r) => r.condition(wm)).toList();
}

/// A collection of default rules for Balatro KBS
class BalatroRuleSet {
  static List<Rule> getDefaultRules() {
    return [
      // — Game Phase Rules —
      Rule(
        name: 'Early Game Strategy',
        description: 'Focuses on building hand value in early game',
        priority: 10,
        condition: (wm) => wm.gs.movesSoFar < 3,
        action: (wm) => wm.gs.notification +=
            '\n📝 Early Game: Focus on building strong combos',
      ),
      Rule(
        name: 'Mid Game Balance',
        description: 'Balances risk/reward in mid-game',
        priority: 10,
        condition: (wm) => wm.gs.movesSoFar >= 3 && wm.gs.movesSoFar < 6,
        action: (wm) =>
            wm.gs.notification += '\n📊 Mid Game: Balance risk and reward',
      ),
      Rule(
        name: 'Late Game Push',
        description: 'Aggressive strategy for final moves',
        priority: 10,
        condition: (wm) => wm.gs.movesSoFar >= 6,
        action: (wm) => wm.gs.notification +=
            '\n🏁 Late Game: Take calculated risks to reach target',
      ),

      // — Point Gap Rules —
      Rule(
        name: 'High Risk Strategy',
        description: 'When close to target, take risks for high rewards',
        priority: 20,
        condition: (wm) => wm.gs.requiredPoints - wm.gs.currentPoints <= 50,
        action: (wm) => wm.gs.notification +=
            '\n🔥 Strategy: High-Risk Activated! Consider playing for high-scoring combos.',
      ),
      Rule(
        name: 'Desperate Measures',
        description: 'When far behind with few moves left, take maximum risks',
        priority: 20,
        condition: (wm) {
          final movesLeft = 8 - wm.gs.movesSoFar;
          final pointsNeeded = wm.gs.requiredPoints - wm.gs.currentPoints;
          return movesLeft <= 2 && pointsNeeded > movesLeft * 50;
        },
        action: (wm) => wm.gs.notification +=
            '\n⚠️ Strategy: Desperate Measures! Go for highest possible combos only.',
      ),
      Rule(
        name: 'Conservative Play',
        description: 'When ahead of schedule, play conservatively',
        priority: 15,
        condition: (wm) {
          final movesLeft = 8 - wm.gs.movesSoFar;
          final pointsNeeded = wm.gs.requiredPoints - wm.gs.currentPoints;
          return movesLeft >= 3 && pointsNeeded < movesLeft * 30;
        },
        action: (wm) => wm.gs.notification +=
            '\n🛡️ Strategy: Conservative Play! You\'re ahead of schedule.',
      ),

      // — Hand Evaluation Rules —
      Rule(
        name: 'Strong Hand Detected',
        description: 'When a very strong hand is available',
        priority: 25,
        condition: (wm) {
          final combos = wm.gs.analyzeHand();
          return combos.isNotEmpty && combos.first.score > 150;
        },
        action: (wm) {
          final combo = wm.gs.analyzeHand().first;
          wm.gs.notification +=
              '\n💪 Strong Hand! ${combo.name} detected (${combo.score} points)';
        },
      ),
      Rule(
        name: 'Suggest Discard',
        description: 'When hand is weak, suggest discarding',
        priority: 5,
        condition: (wm) {
          final combos = wm.gs.analyzeHand();
          return wm.gs.hand.length >= 6 &&
              (combos.isEmpty || combos.every((c) => c.score < 30));
        },
        action: (wm) => wm.gs.notification +=
            '\n💡 Suggestion: Consider discarding weak hand.',
      ),
      Rule(
        name: 'Almost Complete Combo',
        description: 'When close to completing a high-value combo',
        priority: 10,
        condition: (wm) {
          final suits = <String, int>{};
          for (var c in wm.gs.hand) {
            suits[c.suit] = (suits[c.suit] ?? 0) + 1;
          }
          return suits.values.any((cnt) => cnt >= 4);
        },
        action: (wm) => wm.gs.notification +=
            '\n👀 Notice: Almost have a Flush! Consider holding these cards.',
      ),

      // — Special Situations —
      Rule(
        name: 'Final Move',
        description: 'Special handling for the final move of the game',
        priority: 30,
        condition: (wm) => wm.gs.movesSoFar == 7,
        action: (wm) {
          final need = wm.gs.requiredPoints - wm.gs.currentPoints;
          wm.gs.notification +=
              '\n🔄 Final Move! Need $need points to meet target.';
        },
      ),
      Rule(
        name: 'Target Reached',
        description: 'When the target score is reached',
        priority: 100,
        condition: (wm) => wm.gs.currentPoints >= wm.gs.requiredPoints,
        action: (wm) => wm.gs.notification +=
            '\n🎉 Target Reached! Consider moving to next round.',
      ),
    ];
  }
}
