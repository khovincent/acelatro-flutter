// lib/features/selection/kbs/probability_estimators.dart
import 'dart:math'; // Need max

import '../../../core/models/card_model.dart';
// Removed unused imports: combo_definitions.dart, combinations_util.dart

/// Provides static methods to estimate probabilities of forming combos after discarding.
/// These are heuristics and not exact probabilities, designed for comparative ranking.
class ProbabilityEstimators {
  // Helper to count remaining cards of a specific value in the deck
  static int _countValueInDeck(int value, List<CardModel> deck) {
    return deck.where((card) => card.value == value).length;
  }

  // Helper to count remaining cards of a specific suit in the deck
  static int _countSuitInDeck(String suit, List<CardModel> deck) {
    return deck.where((card) => card.suit == suit).length;
  }

  /// Estimates the potential contribution of keeping a card towards making a Pair, 3oaK, or 4oaK.
  /// Higher value if the card's rank is already present multiple times in hand or deck.
  static double estimateOfAKindPotential(
    CardModel cardToKeep,
    List<CardModel> currentHand,
    List<CardModel> remainingDeck,
  ) {
    final value = cardToKeep.value;
    final countInHand = currentHand.where((c) => c.value == value).length;
    final countInDeck = _countValueInDeck(value, remainingDeck);
    final deckSize = remainingDeck.length;
    if (deckSize == 0) return 0.0;

    double potential = 0.0;

    // Potential to make a pair (needs 1 more) - high if already 1 in hand
    if (countInHand == 1) {
      potential += (countInDeck / deckSize) * 0.5; // Weight based on usefulness
    }

    // Potential to make 3oaK (needs 1 or 2 more)
    if (countInHand == 2) {
      potential += (countInDeck / deckSize) * 0.8; // High chance if 1 needed
    }
    if (countInHand == 1 && countInDeck >= 2) {
      potential +=
          _calculateDrawProbability(countInDeck, 2, deckSize) *
          0.3; // Use helper for better approx
    }

    // Potential to make 4oaK (needs 1, 2, or 3 more)
    if (countInHand == 3) {
      potential +=
          (countInDeck / deckSize) * 1.0; // Very high chance if 1 needed
    }
    if (countInHand == 2 && countInDeck >= 2) {
      potential += _calculateDrawProbability(countInDeck, 2, deckSize) * 0.4;
    }
    if (countInHand == 1 && countInDeck >= 3) {
      potential +=
          _calculateDrawProbability(countInDeck, 3, deckSize) *
          0.1; // Lower chance
    }

    // Give a small base value just for having the card
    potential += 0.05;

    return potential.clamp(0.0, 1.0); // Clamp to valid probability range
  }

  /// Estimates the potential contribution of keeping a card towards making a Flush.
  /// Higher value if the card's suit is common in the hand or deck.
  static double estimateFlushPotential(
    CardModel cardToKeep,
    List<CardModel> currentHand,
    List<CardModel> remainingDeck,
  ) {
    final suit = cardToKeep.suit;
    final countInHand = currentHand.where((c) => c.suit == suit).length;
    final countInDeck = _countSuitInDeck(suit, remainingDeck);
    final deckSize = remainingDeck.length;
    if (deckSize == 0) return 0.0;

    double potential = 0.0;
    final cardsNeededForFlush = 5 - countInHand;

    if (cardsNeededForFlush <= 0) {
      return 1.0; // Already have a flush with this suit
    }

    if (countInDeck >= cardsNeededForFlush) {
      // Approximation: probability increases significantly as we get closer
      if (countInHand == 4) {
        potential +=
            _calculateDrawProbability(countInDeck, 1, deckSize) * 1.0; // Need 1
      }
      if (countInHand == 3) {
        potential +=
            _calculateDrawProbability(countInDeck, 2, deckSize) * 0.6; // Need 2
      }
      if (countInHand == 2) {
        potential +=
            _calculateDrawProbability(countInDeck, 3, deckSize) * 0.3; // Need 3
      }
    }

    // Small base value for keeping a suited card
    potential += 0.1;

    return potential.clamp(0.0, 1.0);
  }

  /// Estimates the potential contribution of keeping a card towards making a Straight.
  /// Higher value if the card connects potential straight sequences.
  static double estimateStraightPotential(
    CardModel cardToKeep,
    List<CardModel> currentHand,
    List<CardModel> remainingDeck,
  ) {
    final handValues =
        currentHand.map((c) => c.value).toSet(); // Use Set for uniqueness
    final deckSize = remainingDeck.length;
    if (deckSize == 0) return 0.0;

    double potential = 0.0;
    final value = cardToKeep.value;

    // Check for potential straights involving this card's value
    // Look for sequences of 5 around the kept card's value
    for (int startValue = value - 4; startValue <= value; ++startValue) {
      // Removed unused variable: cardsPresent
      int cardsNeededFromDeck = 0;
      // Removed unused variable: possible
      final neededValues = <int>{};
      Set<int> currentSequence =
          {}; // Track the specific sequence being checked

      // Check sequence from startValue to startValue + 4
      bool validSequence = true;
      for (int i = 0; i < 5; ++i) {
        int currentValue = startValue + i;
        if (currentValue < 2 || currentValue > 14) {
          // Handle standard ranks
          validSequence = false;
          break;
        }
        currentSequence.add(currentValue);
        if (!handValues.contains(currentValue)) {
          neededValues.add(currentValue);
          cardsNeededFromDeck++;
        }
      }

      if (validSequence && cardsNeededFromDeck > 0) {
        int availableInDeck = neededValues
            .map((v) => _countValueInDeck(v, remainingDeck))
            .fold(0, (sum, count) => sum + count);
        if (availableInDeck >= cardsNeededFromDeck) {
          double prob = _calculateDrawProbability(
            availableInDeck,
            cardsNeededFromDeck,
            deckSize,
          );
          potential = max(
            potential,
            prob * (cardsNeededFromDeck == 1 ? 0.8 : 0.4),
          );
        }
      } else if (validSequence && cardsNeededFromDeck == 0) {
        potential = max(potential, 1.0); // Already have this straight
      }
    }

    // Special check for Ace-low straight (A, 2, 3, 4, 5)
    final Set<int> aceLowSequence = {14, 2, 3, 4, 5};
    if (aceLowSequence.contains(value)) {
      // Only check if the card could be part of it
      int aceLowNeeded = 0;
      final aceLowNeededValues = <int>{};
      for (int val in aceLowSequence) {
        if (!handValues.contains(val)) {
          aceLowNeeded++;
          aceLowNeededValues.add(val);
        }
      }
      if (aceLowNeeded > 0 && aceLowNeeded <= deckSize) {
        int availableInDeck = aceLowNeededValues
            .map((v) => _countValueInDeck(v, remainingDeck))
            .fold(0, (sum, count) => sum + count);
        if (availableInDeck >= aceLowNeeded) {
          double prob = _calculateDrawProbability(
            availableInDeck,
            aceLowNeeded,
            deckSize,
          );
          potential = max(
            potential,
            prob * (aceLowNeeded == 1 ? 0.9 : 0.6),
          ); // Higher weight if closer
        }
      } else if (aceLowNeeded == 0) {
        potential = max(potential, 1.0); // Already have Ace-low straight
      }
    }

    // Small base value for keeping any card
    potential += 0.05;

    return potential.clamp(0.0, 1.0);
  }

  /// Helper to estimate probability of drawing 'neededCount' specific cards from 'availableCount' in deck of 'deckSize'.
  /// This is a simplification (hypergeometric distribution is complex).
  static double _calculateDrawProbability(
    int availableCount,
    int neededCount,
    int deckSize,
  ) {
    if (deckSize <= 0 || neededCount <= 0) {
      return (neededCount <= 0)
          ? 1.0
          : 0.0; // Handle deck empty or nothing needed
    }
    if (availableCount < neededCount) return 0.0;

    // Very rough approximation: chance of getting the first needed * chance of second etc.
    double prob = 1.0;
    for (int i = 0; i < neededCount; ++i) {
      double currentAvailable = (availableCount - i).toDouble();
      double currentDeckSize = (deckSize - i).toDouble();
      if (currentDeckSize <= 0) return 0.0; // Avoid division by zero
      prob *= (currentAvailable / currentDeckSize);
    }

    // Reduce probability somewhat if multiple cards are needed, as draws aren't independent
    // This factor is arbitrary and adjusts the heuristic
    if (neededCount > 1) {
      prob *= pow(0.7, neededCount - 1); // Exponential reduction factor
    }

    return prob.clamp(0.0, 1.0);
  }

  /// Calculates an overall 'keep score' for a card based on its potential contribution.
  /// Higher score means the card is more valuable to keep.
  static double estimateKeepScore(
    CardModel cardToKeep,
    List<CardModel> currentHand,
    List<CardModel> remainingDeck,
  ) {
    // Weighted sum of different potentials
    double score = 0;
    score +=
        estimateOfAKindPotential(cardToKeep, currentHand, remainingDeck) *
        0.4; // Weight 'of a kind' potential
    score +=
        estimateFlushPotential(cardToKeep, currentHand, remainingDeck) *
        0.3; // Weight flush potential
    score +=
        estimateStraightPotential(cardToKeep, currentHand, remainingDeck) *
        0.3; // Weight straight potential

    // Bonus for high value cards (Aces, Face cards) - these contribute more chips
    score +=
        cardToKeep.chipValue * 0.01; // Add a small bonus based on chip value

    // Ensure score is not negative and has a small floor
    return max(0.01, score); // Avoid zero scores, give every card minimal value
  }

  // --- Specific Combo Probability Estimation (More granular, used for explanation) ---

  static Map<String, double> estimateImprovementProbabilities(
    CardModel cardToDiscard,
    List<CardModel> currentHand,
    List<CardModel> remainingDeck,
  ) {
    final probabilities = <String, double>{};
    // Create hand as if the card was discarded
    final handAfterDiscard =
        currentHand.where((c) => c != cardToDiscard).toList();
    // Assume we draw 1 card to replace the discarded one
    final int cardsToDraw = 1; // Simple assumption for this estimation
    final deckSize = remainingDeck.length;

    if (deckSize < cardsToDraw) {
      return probabilities; // Cannot draw if deck empty
    }

    // --- Estimate chance of drawing into specific improvements ---
    // This requires iterating through deck possibilities or using more complex math.
    // Let's simplify: Calculate potential *before* discard vs *after* discard for comparison?
    // Or estimate direct probability based on needing 1 specific card type.

    // Example: Probability of drawing a pair for an existing card
    final valuesInHandAfter = <int, int>{};
    for (var card in handAfterDiscard) {
      valuesInHandAfter[card.value] = (valuesInHandAfter[card.value] ?? 0) + 1;
    }

    for (var entry in valuesInHandAfter.entries) {
      if (entry.value == 1) {
        // If we have one card of this rank left
        int value = entry.key;
        int available = _countValueInDeck(value, remainingDeck);
        if (available > 0) {
          probabilities['Pair (${CardModel.valueNames[value]})'] = max(
            probabilities['Pair (${CardModel.valueNames[value]})'] ?? 0.0,
            _calculateDrawProbability(
              available,
              1,
              deckSize,
            ), // Chance to draw the needed card
          );
        }
      }
      // Can add similar logic for 3oaK, 4oaK if countInHandAfter is 2 or 3
      if (entry.value == 2) {
        int value = entry.key;
        int available = _countValueInDeck(value, remainingDeck);
        if (available > 0) {
          probabilities['3oaK (${CardModel.valueNames[value]})'] = max(
            probabilities['3oaK (${CardModel.valueNames[value]})'] ?? 0.0,
            _calculateDrawProbability(available, 1, deckSize),
          );
        }
      }
      if (entry.value == 3) {
        int value = entry.key;
        int available = _countValueInDeck(value, remainingDeck);
        if (available > 0) {
          probabilities['4oaK (${CardModel.valueNames[value]})'] = max(
            probabilities['4oaK (${CardModel.valueNames[value]})'] ?? 0.0,
            _calculateDrawProbability(available, 1, deckSize),
          );
        }
      }
    }

    // Example: Probability of drawing a card to complete a 4-flush
    final suitsInHandAfter = <String, int>{};
    for (var card in handAfterDiscard) {
      suitsInHandAfter[card.suit] = (suitsInHandAfter[card.suit] ?? 0) + 1;
    }
    for (var entry in suitsInHandAfter.entries) {
      if (entry.value == 4) {
        // If we have 4 of a suit left
        String suit = entry.key;
        int available = _countSuitInDeck(suit, remainingDeck);
        if (available > 0) {
          probabilities['Flush ($suit)'] = max(
            probabilities['Flush ($suit)'] ?? 0.0,
            _calculateDrawProbability(available, 1, deckSize),
          );
        }
      }
    }

    // Example: Probability of drawing card for open-ended straight draw (e.g., have 5,6,7,8 needs 4 or 9)
    final uniqueValuesAfter = handAfterDiscard.map((c) => c.value).toSet();
    for (int val in uniqueValuesAfter) {
      // Check for 4 consecutive values (e.g., val, val+1, val+2, val+3)
      if (uniqueValuesAfter.containsAll({val, val + 1, val + 2, val + 3})) {
        // Needs val-1 or val+4
        int needed1 = val - 1;
        int needed2 = val + 4;
        int available1 =
            (needed1 >= 2 && needed1 <= 14)
                ? _countValueInDeck(needed1, remainingDeck)
                : 0;
        int available2 =
            (needed2 >= 2 && needed2 <= 14)
                ? _countValueInDeck(needed2, remainingDeck)
                : 0;
        if (available1 + available2 > 0) {
          probabilities['Straight Draw (${CardModel.valueNames[val]}..${CardModel.valueNames[val + 3]})'] =
              max(
                probabilities['Straight Draw (${CardModel.valueNames[val]}..${CardModel.valueNames[val + 3]})'] ??
                    0.0,
                _calculateDrawProbability(
                  available1 + available2,
                  1,
                  deckSize,
                ), // Chance to draw either needed card
              );
        }
      }
      // Add check for gutshot draws (e.g., have 5,6,8,9 needs 7)
      if (uniqueValuesAfter.containsAll({val, val + 1, val + 3, val + 4})) {
        int needed = val + 2;
        int available =
            (needed >= 2 && needed <= 14)
                ? _countValueInDeck(needed, remainingDeck)
                : 0;
        if (available > 0) {
          probabilities['Gutshot Draw (${CardModel.valueNames[needed]})'] = max(
            probabilities['Gutshot Draw (${CardModel.valueNames[needed]})'] ??
                0.0,
            _calculateDrawProbability(available, 1, deckSize),
          );
        }
      }
    }
    // Add check for Ace-low draws

    // Keep only top N probabilities for clarity?
    final sortedProbs =
        probabilities.entries.toList()..sort(
          (a, b) => b.value.compareTo(a.value),
        ); // Sort descending by probability

    // Return limited, sorted map
    return Map.fromEntries(
      sortedProbs.take(5),
    ); // Show top 5 improvement chances
  }
}
