// lib/features/combo_detection/kbs/combo_rules.dart

import '../../../../core/kbs/frames/game_state_frame.dart';
import '../../../../core/kbs/rules/rule_base.dart';
import '../../../../core/models/card_model.dart';
import '../../../../core/models/combo_definitions.dart';
import '../../../../core/utils/combinations_util.dart'; // We need combinations here too

class ComboDetectionRules {
  static List<Rule> getRules() {
    final rules = <Rule>[];

    // Iterate through each combo definition to create a detection rule
    for (final definition in balatroComboDefinitions) {
      // Skip creating a rule for High Card, as it's handled as a fallback in GameState
      if (definition.name == 'High Card') continue;

      rules.add(
        Rule(
          name: 'Detect ${definition.name}',
          description:
              'Detects ${definition.name} combinations in the current hand.',
          phase: InferencePhase.detection,
          // Priority based on the definition order (higher rank = higher priority)
          // Subtracting index makes earlier definitions (higher rank) have higher priority values.
          priority: 100 - balatroComboDefinitions.indexOf(definition),
          // Reads the hand cards from the working memory
          reads: {GameStateFrame.handCards},
          // Writes the results into the detectedCombos slot
          writes: {GameStateFrame.detectedCombos},
          tags: [
            'detection',
            'combo',
            definition.name.toLowerCase().replaceAll(' ', '_'),
          ],

          // --- Condition ---
          condition: (wm) {
            // Check if the frame is the correct type and has the hand slot
            if (wm is! GameStateFrame) return false;
            final hand = wm.slots[GameStateFrame.handCards] as List<CardModel>?;
            if (hand == null || hand.length < definition.requiredCardCount) {
              return false; // Not enough cards in hand for this combo
            }

            // Check if *any* combination of the required size matches the definition
            // This condition is a bit expensive, could optimize if needed,
            // but ensures the action only runs if a combo *might* exist.
            // Alternatively, the action can just run and find nothing. Let's simplify:
            // Action will run if enough cards exist, and filter internally.
            return true; // Condition is simply having enough cards
          },

          // --- Action ---
          action: (wm) {
            // Ensure correct frame type
            if (wm is! GameStateFrame) return;
            final hand =
                wm.slots[GameStateFrame.handCards]
                    as List<
                      CardModel
                    >; // Already checked non-null in condition (or should handle null if condition changes)

            // Ensure the detectedCombos slot exists and is a list
            wm.slots.putIfAbsent(
              GameStateFrame.detectedCombos,
              () => <ComboResult>[],
            );
            final detectedList =
                wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>;

            // Find all combinations of the required size that match the check
            final combinationsToCheck = combinations(
              hand,
              definition.requiredCardCount,
            );

            for (final comboCards in combinationsToCheck) {
              if (definition.check(comboCards)) {
                // Found a combo, calculate score and create result
                // For detection, score based on the core N cards? Or the best 5 containing these N?
                // Let's score based on the N cards forming the core combo for detection clarity.
                // GameState.identifyCombo will score based on *played* cards later.
                final score = definition.calculateScore(comboCards);
                final comboResult = ComboResult(
                  name: definition.name,
                  cards: List.unmodifiable(comboCards), // Store immutable list
                  score: score,
                  definition: definition,
                );

                // Add the detected combo to the working memory slot
                // Optional: Add de-duplication here if combinations can yield equivalent sets
                detectedList.add(comboResult);
              }
            }
            // Optional: Sort the detectedList within the WM slot after adding all for this rule?
            // Sorting is currently done in GameState.analyzeHand(), maybe sufficient.
            // wm.slots[GameStateFrame.detectedCombos] = detectedList..sort(...);
          },
        ),
      );
    }

    // Add a rule to sort the detected combos at the end of the detection phase?
    rules.add(
      Rule(
        name: 'Sort Detected Combos',
        description: 'Sorts the list of detected combos by score.',
        phase: InferencePhase.detection,
        priority: 0, // Run last in detection phase
        reads: {GameStateFrame.detectedCombos},
        writes: {GameStateFrame.detectedCombos},
        tags: ['detection', 'cleanup'],
        condition:
            (wm) =>
                wm is GameStateFrame &&
                (wm.slots[GameStateFrame.detectedCombos] as List?)
                        ?.isNotEmpty ==
                    true,
        action: (wm) {
          if (wm is! GameStateFrame) return;
          final detectedList =
              wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>;
          detectedList.sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);
            if (scoreCompare != 0) return scoreCompare;
            return a.name.compareTo(b.name);
          });
          // The list in the slot is modified in place.
        },
      ),
    );

    return rules;
  }
}
