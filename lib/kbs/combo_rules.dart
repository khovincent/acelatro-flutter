// lib/kbs/combo_rules.dart

import '../models/combo_definitions.dart';
import 'frame.dart';
import 'rule_base.dart';

/// Generates one Rule per ComboDefinition to detect & register combos.
class ComboDetectionEngine {
  static List<Rule> getComboRules() {
    return comboDefinitions.map((def) {
      return Rule(
        name: '${def.name} Detection',
        description: 'Detects ${def.name} combinations in hand',
        priority: 100 - comboDefinitions.indexOf(def), // rarer => higher
        condition: (wm) {
          // only if hand large enough
          if (wm.gs.hand.length < def.cardCount) return false;
          return combinations(wm.gs.hand, def.cardCount).any(def.check);
        },
        action: (wm) {
          // collect every matching combo
          for (var combo in combinations(wm.gs.hand, def.cardCount)) {
            if (def.check(combo)) {
              final chipSum = combo.fold<int>(0, (sum, c) => sum + c.chipValue);
              final score = (def.base + chipSum) * def.multiplier;
              final result = ComboResult(def.name, combo, score);
              wm.slots['detectedCombos'] ??= <ComboResult>[];
              (wm.slots['detectedCombos'] as List<ComboResult>).add(result);
            }
          }
        },
      );
    }).toList();
  }
}
