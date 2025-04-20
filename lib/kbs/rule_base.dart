import 'frame.dart';
import '../models/game_state.dart';
import '../models/combo_definitions.dart';

class Rule {
  final String name;
  final String description;
  final int priority; // Higher number = higher priority
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

class InferenceEngine {
  final List<Rule> rules;
  final GameStateFrame wm;
  final List<String> activationHistory = [];

  InferenceEngine(this.rules, this.wm);

  void forwardChain() {
    // Sort rules by priority (higher first)
    final sortedRules = List<Rule>.from(rules)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    bool anyFired;
    do {
      anyFired = false;
      for (var rule in sortedRules) {
        if (!rule.fired && rule.condition(wm)) {
          rule.action(wm);
          rule.fired = true;
          activationHistory.add('Fired rule: ${rule.name}');
          anyFired = true;
        }
      }
    } while (anyFired);
  }

  List<Rule> getApplicableRules() {
    return rules.where((rule) => rule.condition(wm)).toList();
  }
}

/// A collection of rules for Balatro KBS
class BalatroRuleSet {
  static List<Rule> getDefaultRules() {
    return [
      // Game Phase Rules
      Rule(
        name: 'Early Game Strategy',
        description: 'Focuses on building hand value in early game',
        priority: 10,
        condition: (wm) {
          final gs = wm.gs;
          return gs.movesSoFar < 3;
        },
        action: (wm) {
          final gs = wm.gs;
          gs.notification += '\n📝 Early Game: Focus on building strong combos';
        },
      ),

      Rule(
        name: 'Mid Game Balance',
        description: 'Balances risk/reward in mid-game',
        priority: 10,
        condition: (wm) {
          final gs = wm.gs;
          return gs.movesSoFar >= 3 && gs.movesSoFar < 6;
        },
        action: (wm) {
          final gs = wm.gs;
          gs.notification += '\n📊 Mid Game: Balance risk and reward';
        },
      ),

      Rule(
        name: 'Late Game Push',
        description: 'Aggressive strategy for final moves',
        priority: 10,
        condition: (wm) {
          final gs = wm.gs;
          return gs.movesSoFar >= 6;
        },
        action: (wm) {
          final gs = wm.gs;
          gs.notification +=
              '\n🏁 Late Game: Take calculated risks to reach target';
        },
      ),

      // Point Gap Rules
      Rule(
        name: 'High Risk Strategy',
        description: 'When close to target, take risks for high rewards',
        priority: 20,
        condition: (wm) {
          final gs = wm.gs;
          return gs.requiredPoints - gs.currentPoints <= 50;
        },
        action: (wm) {
          final gs = wm.gs;
          gs.notification +=
              '\n🔥 Strategy: High-Risk Activated! Consider playing for high-scoring combos.';
        },
      ),

      Rule(
        name: 'Desperate Measures',
        description: 'When far behind with few moves left, take maximum risks',
        priority: 20,
        condition: (wm) {
          final GameState gs = wm.gs;
          final int movesLeft = 8 - gs.movesSoFar; // Assuming 8 total moves
          final int pointsNeeded = gs.requiredPoints - gs.currentPoints;
          return movesLeft <= 2 && pointsNeeded > movesLeft * 50;
        },
        action: (wm) {
          final gs = wm.gs;
          gs.notification +=
              '\n⚠️ Strategy: Desperate Measures! Go for highest possible combos only.';
        },
      ),

      Rule(
        name: 'Conservative Play',
        description: 'When ahead of schedule, play conservatively',
        priority: 15,
        condition: (wm) {
          final GameState gs = wm.gs;
          final int movesLeft = 8 - gs.movesSoFar; // Assuming 8 total moves
          final int pointsNeeded = gs.requiredPoints - gs.currentPoints;
          return movesLeft >= 3 && pointsNeeded < movesLeft * 30;
        },
        action: (wm) {
          final gs = wm.gs;
          gs.notification +=
              '\n🛡️ Strategy: Conservative Play! You\'re ahead of schedule.';
        },
      ),

      // Hand Evaluation Rules
      Rule(
        name: 'Strong Hand Detected',
        description: 'When a very strong hand is available',
        priority: 25,
        condition: (wm) {
          final gs = wm.gs;
          final combos = gs.analyzeHand();
          return combos.isNotEmpty && combos.first.score > 150;
        },
        action: (wm) {
          final gs = wm.gs;
          final combos = gs.analyzeHand();
          if (combos.isNotEmpty) {
            final topCombo = combos.first;
            gs.notification +=
                '\n💪 Strong Hand! ${topCombo.name} detected (${topCombo.score} points)';
          }
        },
      ),

      Rule(
        name: 'Suggest Discard',
        description: 'When hand is weak, suggest discarding',
        priority: 5,
        condition: (wm) {
          final gs = wm.gs;
          final combos = gs.analyzeHand();
          return gs.hand.length >= 6 &&
              (combos.isEmpty || combos.every((combo) => combo.score < 30));
        },
        action: (wm) {
          final gs = wm.gs;
          gs.notification += '\n💡 Suggestion: Consider discarding weak hand.';
        },
      ),

      Rule(
        name: 'Almost Complete Combo',
        description: 'When close to completing a high-value combo',
        priority: 10,
        condition: (wm) {
          final gs = wm.gs;
          // Check for 4 cards of same suit (almost flush)
          final suits = <String, int>{};
          for (var card in gs.hand) {
            suits[card.suit] = (suits[card.suit] ?? 0) + 1;
          }
          return suits.values.any((count) => count >= 4);
        },
        action: (wm) {
          final gs = wm.gs;
          gs.notification +=
              '\n👀 Notice: Almost have a Flush! Consider holding these cards.';
        },
      ),

      // Special Situations
      Rule(
        name: 'Final Move',
        description: 'Special handling for the final move of the game',
        priority: 30,
        condition: (wm) {
          final gs = wm.gs;
          return gs.movesSoFar == 7; // Assuming 8 total moves
        },
        action: (wm) {
          final gs = wm.gs;
          final pointsNeeded = gs.requiredPoints - gs.currentPoints;
          gs.notification +=
              '\n🔄 Final Move! Need ${pointsNeeded} points to meet target.';
        },
      ),

      Rule(
        name: 'Target Reached',
        description: 'When the target score is reached',
        priority: 100,
        condition: (wm) {
          final gs = wm.gs;
          return gs.currentPoints >= gs.requiredPoints;
        },
        action: (wm) {
          final gs = wm.gs;
          gs.notification +=
              '\n🎉 Target Reached! Consider moving to next round.';
        },
      ),
    ];
  }
}
