// lib/features/decision/kbs/decision_rules.dart

import '../../../core/kbs/frames/game_state_frame.dart';
import '../../../core/kbs/rules/rule_base.dart';
import '../../../core/models/combo_definitions.dart'; // For ComboResult

class DecisionRules {
  static List<Rule> getRules() {
    return [
      // --- Play Decisions ---
      Rule(
        name: 'Play If Target Reached By Top Combo',
        description:
            'Decide to PLAY if the best detected combo meets or exceeds the remaining points needed.',
        phase: InferencePhase.decision,
        priority: 100, // Highest priority play decision
        reads: {GameStateFrame.pointsGap, GameStateFrame.detectedCombos},
        writes: {GameStateFrame.currentDecision},
        tags: ['decision', 'play', 'goal', 'win-condition'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final gap =
              wm.slots[GameStateFrame.pointsGap] as int? ??
              1; // Default to >0 if null
          if (gap <= 0) return false; // No need to play if target already met

          final combos =
              wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>?;
          return combos != null &&
              combos.isNotEmpty &&
              combos.first.score >= gap;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          final comboName =
              (wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>)
                  .first
                  .name;
          wm.updateSlot(
            GameStateFrame.currentDecision,
            'play:target_met_by_${comboName.toLowerCase().replaceAll(' ', '_')}',
          );
        },
      ),

      Rule(
        name: 'Play If High Score Needed Urgently',
        description:
            'Decide to PLAY the best available combo if high scores are needed and the combo is decent.',
        phase: InferencePhase.decision,
        priority: 90,
        // Reads strategic advice set in the previous phase
        reads: {GameStateFrame.strategicAdvice, GameStateFrame.detectedCombos},
        writes: {GameStateFrame.currentDecision},
        tags: ['decision', 'play', 'risk', 'urgent'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final advice = wm.slots[GameStateFrame.strategicAdvice] as String?;
          // Check if strategy phase flagged high risk
          if (advice != 'high_risk_needed') return false;

          final combos =
              wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>?;
          // Play even a moderate combo if risk is high (e.g., score >= 40)
          return combos != null &&
              combos.isNotEmpty &&
              combos.first.score >= 40;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          final comboName =
              (wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>)
                  .first
                  .name;
          wm.updateSlot(
            GameStateFrame.currentDecision,
            'play:urgent_score_${comboName.toLowerCase().replaceAll(' ', '_')}',
          );
        },
      ),

      Rule(
        name: 'Play Strong Combo If Safe',
        description:
            'Decide to PLAY a strong combo if not under pressure to discard.',
        phase: InferencePhase.decision,
        priority: 80,
        reads: {GameStateFrame.strategicAdvice, GameStateFrame.detectedCombos},
        writes: {GameStateFrame.currentDecision},
        tags: ['decision', 'play', 'opportunity', 'strong-combo'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final advice = wm.slots[GameStateFrame.strategicAdvice] as String?;
          // Don't force play if strategy suggests conservative might be better, unless combo is very strong
          if (advice == 'high_risk_needed') {
            return false; // Handled by higher priority rule
          }

          final combos =
              wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>?;
          // Play if combo is generally strong (e.g., score >= 50)
          return combos != null &&
              combos.isNotEmpty &&
              combos.first.score >= 50;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          final comboName =
              (wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>)
                  .first
                  .name;
          wm.updateSlot(
            GameStateFrame.currentDecision,
            'play:strong_combo_${comboName.toLowerCase().replaceAll(' ', '_')}',
          );
        },
      ),

      Rule(
        name: 'Play Decent Combo In Late Game',
        description: 'Decide to PLAY a decent combo if few moves remain.',
        phase: InferencePhase.decision,
        priority: 85, // Higher than generic strong combo, lower than urgent
        reads: {GameStateFrame.strategicAdvice, GameStateFrame.detectedCombos},
        writes: {GameStateFrame.currentDecision},
        tags: ['decision', 'play', 'late-game'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final advice = wm.slots[GameStateFrame.strategicAdvice] as String?;
          // Check if strategy phase flagged late game
          if (advice != 'push_for_points') return false;

          final combos =
              wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>?;
          // Play even a moderate combo in late game (e.g., score >= 30)
          return combos != null &&
              combos.isNotEmpty &&
              combos.first.score >= 30;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          final comboName =
              (wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>)
                  .first
                  .name;
          wm.updateSlot(
            GameStateFrame.currentDecision,
            'play:late_game_push_${comboName.toLowerCase().replaceAll(' ', '_')}',
          );
        },
      ),

      // --- Discard Decisions ---
      Rule(
        name: 'Discard Weak Hand If Discards Available',
        description:
            'Decide to DISCARD if the hand potential is weak and discards remain.',
        phase: InferencePhase.decision,
        priority: 70,
        reads: {
          GameStateFrame.strategicAdvice, // Check for 'has_weak_hand' flag
          GameStateFrame.remainingDiscards,
          GameStateFrame.detectedCombos, // Double check combo score here too
        },
        writes: {GameStateFrame.currentDecision},
        tags: ['decision', 'discard', 'weak-hand', 'improve'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final discardsLeft =
              wm.slots[GameStateFrame.remainingDiscards] as int? ?? 0;
          if (discardsLeft <= 0) return false; // Cannot discard

          final advice = wm.slots[GameStateFrame.strategicAdvice] as String?;
          final combos =
              wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>?;

          // Discard if strategy flagged weak OR if best combo is objectively weak (e.g. < 30)
          bool isWeak =
              advice == 'has_weak_hand' ||
              (combos == null || combos.isEmpty || combos.first.score < 30);

          return isWeak;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          wm.updateSlot(
            GameStateFrame.currentDecision,
            'discard:improve_weak_hand',
          );
        },
      ),

      Rule(
        name: 'Discard If Conservative Play Advised And No Strong Play',
        description:
            'Decide to DISCARD if playing conservatively is okay and no compelling play exists.',
        phase: InferencePhase.decision,
        priority: 65, // Lower than weak hand discard, higher than fallback
        reads: {
          GameStateFrame.strategicAdvice,
          GameStateFrame.remainingDiscards,
          GameStateFrame.detectedCombos, // Check best combo score
        },
        writes: {GameStateFrame.currentDecision},
        tags: ['decision', 'discard', 'conservative', 'improve'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final discardsLeft =
              wm.slots[GameStateFrame.remainingDiscards] as int? ?? 0;
          if (discardsLeft <= 0) return false;

          final advice = wm.slots[GameStateFrame.strategicAdvice] as String?;
          if (advice != 'conservative_play_ok') {
            return false; // Only applies if conservative is flagged
          }

          final combos =
              wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>?;
          // If conservative is okay, discard unless there's a reasonably good combo (e.g. >= 50)
          bool hasStrongPlay =
              combos != null && combos.isNotEmpty && combos.first.score >= 50;

          return !hasStrongPlay; // Discard if no strong play available while conservative
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          wm.updateSlot(
            GameStateFrame.currentDecision,
            'discard:conservative_improvement',
          );
        },
      ),

      // --- Fallback Decisions ---
      Rule(
        name: 'Fallback Play If Reasonable Combo Exists',
        description:
            'Default to PLAYING if no other rule fired and a reasonable combo exists.',
        phase: InferencePhase.decision,
        priority: 10, // Low priority fallback
        reads: {GameStateFrame.detectedCombos, GameStateFrame.currentDecision},
        writes: {GameStateFrame.currentDecision},
        tags: ['decision', 'play', 'fallback'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;  
          // Only fire if no decision has been made yet by higher priority rules
          if (wm.slots[GameStateFrame.currentDecision] != null) return false;

          final combos =
              wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>?;
          // Play if at least a Pair or better exists (e.g., score >= 20)
          return combos != null &&
              combos.isNotEmpty &&
              combos.first.score >= 20;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          final comboName =
              (wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>)
                  .first
                  .name;
          wm.updateSlot(
            GameStateFrame.currentDecision,
            'play:fallback_${comboName.toLowerCase().replaceAll(' ', '_')}',
          );
        },
      ),

      Rule(
        name: 'Fallback Discard If Possible',
        description:
            'Default to DISCARDING if no other rule fired and discards are available.',
        phase: InferencePhase.decision,
        priority: 5, // Lowest priority
        reads: {
          GameStateFrame.remainingDiscards,
          GameStateFrame.currentDecision,
        },
        writes: {GameStateFrame.currentDecision},
        tags: ['decision', 'discard', 'fallback'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          // Only fire if no decision has been made yet
          if (wm.slots[GameStateFrame.currentDecision] != null) return false;

          final discardsLeft =
              wm.slots[GameStateFrame.remainingDiscards] as int? ?? 0;
          return discardsLeft > 0;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          wm.updateSlot(
            GameStateFrame.currentDecision,
            'discard:fallback_no_play',
          );
        },
      ),
      Rule(
        name: 'No Action Possible',
        description:
            'Sets decision to none if no plays or discards are left and no decision made.',
        phase: InferencePhase.decision,
        priority: 0, // Absolutely last resort
        reads: {
          GameStateFrame.remainingDiscards,
          GameStateFrame.remainingHands,
          GameStateFrame.currentDecision,
        },
        writes: {GameStateFrame.currentDecision},
        tags: ['decision', 'fallback', 'none'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          // Only fire if no decision has been made yet
          if (wm.slots[GameStateFrame.currentDecision] != null) return false;

          final discardsLeft =
              wm.slots[GameStateFrame.remainingDiscards] as int? ?? 0;
          final handsLeft =
              wm.slots[GameStateFrame.remainingHands] as int? ?? 0;
          return discardsLeft <= 0 && handsLeft <= 0;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          wm.updateSlot(GameStateFrame.currentDecision, 'none:no_moves_left');
        },
      ),
    ];
  }
}
