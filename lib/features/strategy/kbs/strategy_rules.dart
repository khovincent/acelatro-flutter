// lib/features/strategy/kbs/strategy_rules.dart

import '../../../core/kbs/frames/game_state_frame.dart';
import '../../../core/kbs/rules/rule_base.dart';
import '../../../core/models/combo_definitions.dart';

class StrategyRules {
  static List<Rule> getRules() {
    return [
      // --- Game Phase Assessment ---
      Rule(
        name: 'Identify Early Game',
        description: 'Identifies the early stage of the round.',
        phase: InferencePhase.strategy,
        priority: 90,
        reads: {
          GameStateFrame.movesLeft,
          GameStateFrame.initialHands,
          GameStateFrame.initialDiscards,
        }, // Read initial counts if needed
        writes: {
          GameStateFrame.strategicAdvice,
          GameStateFrame.notification,
        }, // Could write a specific 'gamePhase' slot
        tags: ['strategy', 'phase', 'early-game'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          // Example: Define early game as having used less than 1/3 of total possible moves
          final movesLeft = wm.slots[GameStateFrame.movesLeft] as int? ?? 0;
          // Calculate total moves possible, ensure initial values are available if needed
          // Or base it simply on moves left > some threshold
          return movesLeft >=
              6; // Assuming 8 total moves, more than 5 left = early
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          wm.updateSlot(
            GameStateFrame.strategicAdvice,
            'focus_building',
          ); // Set a strategic flag
          wm.appendNotification(
            '📝 Early Game: Focus on building hand value and identifying potential strong combos.',
          );
        },
      ),
      Rule(
        name: 'Identify Mid Game',
        description: 'Identifies the middle stage of the round.',
        phase: InferencePhase.strategy,
        priority: 90,
        reads: {GameStateFrame.movesLeft},
        writes: {GameStateFrame.strategicAdvice, GameStateFrame.notification},
        tags: ['strategy', 'phase', 'mid-game'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final movesLeft = wm.slots[GameStateFrame.movesLeft] as int? ?? 0;
          return movesLeft >= 3 && movesLeft <= 5; // Example thresholds
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          wm.updateSlot(GameStateFrame.strategicAdvice, 'balance_risk_reward');
          wm.appendNotification(
            '📊 Mid Game: Balance playing scoring hands vs. discarding to improve.',
          );
        },
      ),
      Rule(
        name: 'Identify Late Game',
        description: 'Identifies the late stage of the round.',
        phase: InferencePhase.strategy,
        priority: 90,
        reads: {GameStateFrame.movesLeft},
        writes: {GameStateFrame.strategicAdvice, GameStateFrame.notification},
        tags: ['strategy', 'phase', 'late-game'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final movesLeft = wm.slots[GameStateFrame.movesLeft] as int? ?? 0;
          return movesLeft <= 2; // Example: 2 or fewer moves left
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          wm.updateSlot(GameStateFrame.strategicAdvice, 'push_for_points');
          wm.appendNotification(
            '🏁 Late Game: Prioritize scoring points needed to meet the target.',
          );
        },
      ),

      // --- Risk Assessment ---
      Rule(
        name: 'Assess High Risk Needed',
        description: 'Flags when high scores are needed urgently.',
        phase: InferencePhase.strategy,
        priority: 80,
        reads: {GameStateFrame.pointsGap, GameStateFrame.movesLeft},
        writes: {GameStateFrame.strategicAdvice, GameStateFrame.notification},
        tags: ['strategy', 'risk', 'urgent'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final gap = wm.slots[GameStateFrame.pointsGap] as int? ?? 0;
          final movesLeft = wm.slots[GameStateFrame.movesLeft] as int? ?? 0;
          // Example: Need > 50 points per remaining move on average
          return movesLeft > 0 && (gap / movesLeft) > 50;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          // Could overwrite previous advice or append based on priority/logic
          wm.updateSlot(GameStateFrame.strategicAdvice, 'high_risk_needed');
          wm.appendNotification(
            '🔥 High Risk: Significantly behind target. Need high-scoring plays!',
          );
        },
      ),
      Rule(
        name: 'Assess Conservative Play Possible',
        description: 'Flags when ahead of the required score curve.',
        phase: InferencePhase.strategy,
        priority: 80,
        reads: {GameStateFrame.pointsGap, GameStateFrame.movesLeft},
        writes: {GameStateFrame.strategicAdvice, GameStateFrame.notification},
        tags: ['strategy', 'risk', 'safe'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final gap = wm.slots[GameStateFrame.pointsGap] as int? ?? 0;
          final movesLeft = wm.slots[GameStateFrame.movesLeft] as int? ?? 0;
          // Example: Need < 20 points per remaining move, and not late game
          return movesLeft > 2 && gap > 0 && (gap / movesLeft) < 20;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          wm.updateSlot(GameStateFrame.strategicAdvice, 'conservative_play_ok');
          wm.appendNotification(
            '🛡️ Conservative: Comfortably ahead. Can afford to build or discard safely.',
          );
        },
      ),
      Rule(
        name: 'Target Already Reached',
        description: 'Flags when the required score is met or exceeded.',
        phase: InferencePhase.strategy,
        priority: 100, // High priority to state this fact
        reads: {GameStateFrame.pointsGap},
        writes: {GameStateFrame.strategicAdvice, GameStateFrame.notification},
        tags: ['strategy', 'goal', 'complete'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final gap = wm.slots[GameStateFrame.pointsGap] as int? ?? 0;
          return gap <= 0;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          wm.updateSlot(GameStateFrame.strategicAdvice, 'target_reached');
          wm.appendNotification(
            '🎉 Target Reached! No more points needed this round.',
          );
        },
      ),

      // --- Hand Potential Assessment (Based on Detection Phase) ---
      Rule(
        name: 'Assess Strong Hand Potential',
        description:
            'Flags if the detected combos include a very high-scoring one.',
        phase: InferencePhase.strategy,
        priority: 70,
        reads: {GameStateFrame.detectedCombos},
        writes: {
          GameStateFrame.strategicAdvice,
          GameStateFrame.notification,
        }, // May influence 'play' decision later
        tags: ['strategy', 'hand-eval', 'strong'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final combos =
              wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>?;
          // Check if best detected combo has score > threshold (e.g., 100 points)
          return combos != null &&
              combos.isNotEmpty &&
              combos.first.score > 100;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          // Note: This might conflict with other advice. Conflict resolution or more nuanced slots needed for complex strategies.
          // wm.updateSlot(GameStateFrame.strategicAdvice, 'has_strong_combo');
          final bestCombo =
              (wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>)
                  .first;
          wm.appendNotification(
            '💪 Strong Hand Potential: Detected ${bestCombo.name} (${bestCombo.score} pts).',
          );
        },
      ),
      Rule(
        name: 'Assess Weak Hand Potential',
        description: 'Flags if the best detected combo is very weak.',
        phase: InferencePhase.strategy,
        priority: 70,
        reads: {GameStateFrame.detectedCombos, GameStateFrame.handSize},
        writes: {
          GameStateFrame.strategicAdvice,
          GameStateFrame.notification,
        }, // May influence 'discard' decision later
        tags: ['strategy', 'hand-eval', 'weak'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final combos =
              wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>?;
          final handSize = wm.slots[GameStateFrame.handSize] as int? ?? 0;
          // Check if hand isn't tiny and best combo score < threshold (e.g., 30 points)
          return handSize > 4 &&
              (combos == null || combos.isEmpty || combos.first.score < 30);
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          // wm.updateSlot(GameStateFrame.strategicAdvice, 'has_weak_hand');
          wm.appendNotification(
            '🤔 Weak Hand: Best combo scores low. Consider improving via discard.',
          );
        },
      ),
    ];
  }
}
