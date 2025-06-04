// lib/features/selection/kbs/selection_rules.dart

import '../../../core/kbs/frames/game_state_frame.dart';
import '../../../core/kbs/rules/rule_base.dart';
import '../../../core/models/card_model.dart';
import '../../../core/models/combo_definitions.dart'; // For ComboResult
import 'probability_estimators.dart'; // Import the estimators

class CardSelectionRules {
  static List<Rule> getRules() {
    return [
      // --- Card Selection for PLAY ---
      Rule(
        name: 'Select Cards For Best Detected Combo',
        description:
            'Selects the indices of the cards forming the highest-scoring detected combo when decision is PLAY.',
        phase: InferencePhase.selection,
        priority: 100, // High priority for play selection
        reads: {
          GameStateFrame.currentDecision,
          GameStateFrame.detectedCombos,
          GameStateFrame.handCards,
        },
        writes: {GameStateFrame.recommendedIndices},
        tags: ['selection', 'play'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final decision = wm.slots[GameStateFrame.currentDecision] as String?;
          // Fire only if decision starts with 'play' and combos were detected
          return decision != null &&
              decision.startsWith('play') &&
              (wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>?)
                      ?.isNotEmpty ==
                  true;
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          final hand = wm.slots[GameStateFrame.handCards] as List<CardModel>;
          // Get the best combo determined by the detection/sorting phase
          final bestCombo =
              (wm.slots[GameStateFrame.detectedCombos] as List<ComboResult>)
                  .first;

          // Find the indices in the current hand that match the cards in the best combo
          final indices = <int>[];
          final handCopy = List.from(
            hand,
          ); // Work on a copy if needed for index finding

          for (final cardToFind in bestCombo.cards) {
            // Find the first matching card in the hand that hasn't been selected yet
            int foundIndex = -1;
            for (int i = 0; i < handCopy.length; ++i) {
              // Use == operator defined in CardModel for comparison
              if (handCopy[i] == cardToFind) {
                // Check if this original index is already selected
                bool alreadySelected = indices.contains(i);
                if (!alreadySelected) {
                  foundIndex = i;
                  break;
                }
                // If index 'i' IS selected, maybe the combo used duplicates?
                // This simple index finding might fail if hand has duplicates and combo uses them.
                // A more robust approach might involve tracking used hand indices.
                // For now, assume first match works for non-duplicate combos.
              }
            }

            if (foundIndex != -1 && !indices.contains(foundIndex)) {
              indices.add(foundIndex);
            } else {
              // Handle case where a card from the combo wasn't found in hand (shouldn't happen if detection is correct)
              print(
                "WARN: Card ${cardToFind.shortName} from detected combo not found in hand indices!",
              );
            }
          }

          // Balatro often plays 5 cards. If the best combo has fewer, add highest other cards?
          // Example: Play Pair + 3 highest kickers. This adds complexity.
          // Let's stick to selecting *only* the cards from the detected combo for now.

          // if (indices.length < 5 && indices.length < hand.length) {
          //   final remainingIndices =
          //       List.generate(
          //         hand.length,
          //         (i) => i,
          //       ).where((i) => !indices.contains(i)).toList();
          //   remainingIndices.sort(
          //     (a, b) => hand[b].chipValue.compareTo(hand[a].chipValue),
          //   ); // Sort by chip value desc
          //   indices.addAll(remainingIndices.take(5 - indices.length));
          // }

          indices.sort(); // Sort indices for consistency
          wm.updateSlot(GameStateFrame.recommendedIndices, indices);
          print(
            "Selection Rule: Recommending indices $indices for playing ${bestCombo.name}",
          );
        },
      ),

      // --- Card Selection for DISCARD ---
      Rule(
        name: 'Select Weakest Cards For Discard',
        description:
            'Selects card indices with the lowest "keep score" when decision is DISCARD.',
        phase: InferencePhase.selection,
        priority: 90, // High priority for discard selection
        reads: {
          GameStateFrame.currentDecision,
          GameStateFrame.handCards,
          GameStateFrame.deckCards, // Needed for probability estimation
          GameStateFrame.remainingDiscards,
        },
        writes: {
          GameStateFrame.recommendedIndices,
          GameStateFrame.discardCandidatesEval,
        },
        tags: ['selection', 'discard'],
        condition: (wm) {
          if (wm is! GameStateFrame) return false;
          final decision = wm.slots[GameStateFrame.currentDecision] as String?;
          // Fire only if decision starts with 'discard' and cards exist in hand
          return decision != null &&
              decision.startsWith('discard') &&
              (wm.slots[GameStateFrame.handCards] as List<CardModel>?)
                      ?.isNotEmpty ==
                  true &&
              (wm.slots[GameStateFrame.remainingDiscards] as int? ?? 0) >
                  0; // And have discards left
        },
        action: (wm) {
          if (wm is! GameStateFrame) return;
          final hand = wm.slots[GameStateFrame.handCards] as List<CardModel>;
          final deck = wm.slots[GameStateFrame.deckCards] as List<CardModel>;
          final discardsAvailable =
              wm.slots[GameStateFrame.remainingDiscards] as int;

          // Calculate the 'keep score' for each card in the hand
          final cardScores =
              <MapEntry<int, double>>[]; // Map index to keep score
          for (int i = 0; i < hand.length; ++i) {
            final card = hand[i];
            final score = ProbabilityEstimators.estimateKeepScore(
              card,
              hand,
              deck,
            );
            cardScores.add(MapEntry(i, score));
            // print("DEBUG: Keep score for ${card.shortName} (Idx $i): $score"); // Debugging
          }

          // Sort cards by keep score (ascending - lowest score is worst to keep)
          cardScores.sort((a, b) => a.value.compareTo(b.value));

          // Select the indices of the cards with the lowest scores, up to the number of available discards
          final indicesToDiscard =
              cardScores
                  .take(discardsAvailable)
                  .map((entry) => entry.key)
                  .toList();

          indicesToDiscard.sort(); // Sort for consistency
          wm.updateSlot(GameStateFrame.recommendedIndices, indicesToDiscard);
          print(
            "Selection Rule: Recommending indices $indicesToDiscard for discard.",
          );

          // --- Populate discard analysis for explanation ---
          final discardAnalysis = <MapEntry<int, Map<String, dynamic>>>[];
          // Limit analysis shown, e.g., top 5 candidates or all evaluated
          for (final entry in cardScores.take(hand.length)) {
            // Analyze all cards scored
            final index = entry.key;
            final card = hand[index];
            final keepScore = entry.value;
            // Get detailed probabilities (more expensive calculation)
            final probabilities =
                ProbabilityEstimators.estimateImprovementProbabilities(
                  card,
                  hand,
                  deck,
                );
            discardAnalysis.add(
              MapEntry(index, {
                'cardName': card.shortName,
                'keepScore': keepScore, // Lower = better to discard
                'probabilities':
                    probabilities, // Detailed chance to make specific hands
              }),
            );
          }
          // Sort analysis by keep score asc for display
          discardAnalysis.sort(
            (a, b) => (a.value['keepScore'] as double).compareTo(
              b.value['keepScore'] as double,
            ),
          );
          wm.updateSlot(GameStateFrame.discardCandidatesEval, discardAnalysis);
        },
      ),
    ];
  }
}
