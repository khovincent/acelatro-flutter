// lib/core/models/combo_definitions.dart
import 'card_model.dart';

// Represents the result of detecting a specific combo in a set of cards
class ComboResult {
  final String name;
  final List<CardModel> cards; // The specific cards forming this combo
  final int score; // Calculated score based on definition and card chips
  final ComboDefinition definition; // Link back to the definition used

  ComboResult({
    required this.name,
    required this.cards,
    required this.score,
    required this.definition,
  });

  @override
  String toString() => '$name (${score}pts): ${cards.join(" ")}';
}

// Type definition for a function that checks if a list of cards matches a combo type
typedef ComboCheck = bool Function(List<CardModel> cards);

// Defines a type of poker combo (e.g., Flush, Straight)
class ComboDefinition {
  final String name;
  final int baseScore; // Base points for the combo
  final int multiplier; // Score multiplier for the combo
  // The number of cards *required* to form this specific combo (e.g., 5 for Flush, 2 for Pair)
  // Note: For Balatro, combos like Four of a Kind might be played with 5 cards,
  // but the core definition requires 4 matching ranks. This count helps filter checks.
  final int requiredCardCount;
  final ComboCheck check; // Function to validate the combo

  ComboDefinition({
    required this.name,
    required this.baseScore,
    required this.multiplier,
    required this.requiredCardCount,
    required this.check,
  });

  // Calculates the score for a specific instance of this combo
  int calculateScore(List<CardModel> actualCards) {
    // Use only the required number of cards for chip calculation if definition specifies
    // Or use all provided cards if more flexible. Balatro usually uses played cards.
    // Let's assume Balatro scores based on *all* cards played for the combo.
    int chipSum = actualCards.fold(0, (sum, card) => sum + card.chipValue);
    return (baseScore + chipSum) * multiplier;
  }
}

// --- Combo Check Implementations (Static or Top-Level Functions) ---

// Helper to get value counts
Map<int, int> _getValueCounts(List<CardModel> cards) {
  final counts = <int, int>{};
  for (final card in cards) {
    counts[card.value] = (counts[card.value] ?? 0) + 1;
  }
  return counts;
}

// Helper to get suit counts
/// Returns a map of suit counts for the given cards.
/// The map will contain an entry for each suit represented in the list,
/// with the key being the suit name and the value being the count of cards with that suit.
/// Counts are 1-indexed, so a count of 1 means one card of that suit is present.
// ignore: unused_element
Map<String, int> _getSuitCounts(List<CardModel> cards) {
  final counts = <String, int>{};
  for (final card in cards) {
    counts[card.suit] = (counts[card.suit] ?? 0) + 1;
  }
  return counts;
}

bool isFlush(List<CardModel> cards) {
  if (cards.isEmpty) return false;
  final firstSuit = cards.first.suit;
  return cards.every((card) => card.suit == firstSuit);
}

bool isStraight(List<CardModel> cards) {
  if (cards.length < 5) return false; // Standard straight needs 5 cards
  final uniqueValues = cards.map((c) => c.value).toSet().toList()..sort();
  if (uniqueValues.length < 5) return false; // Need 5 distinct ranks

  // Check for standard straight
  for (int i = 0; i <= uniqueValues.length - 5; ++i) {
    bool straightFound = true;
    for (int j = 0; j < 4; ++j) {
      if (uniqueValues[i + j + 1] != uniqueValues[i + j] + 1) {
        straightFound = false;
        break;
      }
    }
    if (straightFound) return true;
  }

  // Check for A-2-3-4-5 straight (Ace low)
  // if (uniqueValues.containsAll([14, 2, 3, 4, 5])) {
  //   return true;
  // }
  // .containsAll() doesn't work for some reason so change with .every

  if ([14, 2, 3, 4, 5].every((element) => uniqueValues.contains(element))) {
    return true;
  }

  return false;
}

bool isStraightFlush(List<CardModel> cards) {
  return cards.length >= 5 && isFlush(cards) && isStraight(cards);
}

// Note: Royal Flush is just the highest Straight Flush, often handled by scoring
// rather than a separate check function if Straight Flush already exists.
// We can add it if specific rules target it differently.

bool isFourOfAKind(List<CardModel> cards) {
  if (cards.length < 4) return false;
  final counts = _getValueCounts(cards);
  return counts.values.any((count) => count >= 4);
}

bool isFullHouse(List<CardModel> cards) {
  if (cards.length < 5) return false;
  final counts = _getValueCounts(cards);
  // Needs at least one rank with 3+ cards and another rank with 2+ cards
  bool hasThree = counts.values.any((count) => count >= 3);
  bool hasPair =
      counts.values.where((count) => count >= 2).length >=
      2; // Checks for at least two ranks with pairs or better
  return hasThree && hasPair;
}

bool isThreeOfAKind(List<CardModel> cards) {
  if (cards.length < 3) return false;
  final counts = _getValueCounts(cards);
  // Ensure there's a three-of-a-kind but NOT a Four-of-a-kind or Full House (if checking strictly)
  // For Balatro detection, just checking for >= 3 is usually enough, priority handles overlap.
  return counts.values.any((count) => count >= 3);
}

bool isTwoPair(List<CardModel> cards) {
  if (cards.length < 4) return false;
  final counts = _getValueCounts(cards);
  // Needs at least two ranks with 2+ cards
  return counts.values.where((count) => count >= 2).length >= 2;
}

bool isPair(List<CardModel> cards) {
  if (cards.length < 2) return false;
  final counts = _getValueCounts(cards);
  // Needs at least one rank with 2+ cards
  return counts.values.any((count) => count >= 2);
}

bool isHighCard(List<CardModel> cards) {
  // This is the fallback if nothing else matches
  return cards.isNotEmpty;
}

// --- List of Combo Definitions (Order Matters for detection priority) ---

final List<ComboDefinition> balatroComboDefinitions = [
  // Highest rank first
  ComboDefinition(
    name: 'Straight Flush',
    baseScore: 100,
    multiplier: 8,
    requiredCardCount: 5,
    check: isStraightFlush,
  ),
  ComboDefinition(
    name: 'Four of a Kind',
    baseScore: 60,
    multiplier: 7,
    requiredCardCount: 4,
    check: isFourOfAKind,
  ),
  ComboDefinition(
    name: 'Full House',
    baseScore: 40,
    multiplier: 4,
    requiredCardCount: 5,
    check: isFullHouse,
  ),
  ComboDefinition(
    name: 'Flush',
    baseScore: 35,
    multiplier: 4,
    requiredCardCount: 5,
    check: isFlush,
  ),
  ComboDefinition(
    name: 'Straight',
    baseScore: 30,
    multiplier: 4,
    requiredCardCount: 5,
    check: isStraight,
  ),
  ComboDefinition(
    name: 'Three of a Kind',
    baseScore: 30,
    multiplier: 3,
    requiredCardCount: 3,
    check: isThreeOfAKind,
  ),
  ComboDefinition(
    name: 'Two Pair',
    baseScore: 20,
    multiplier: 2,
    requiredCardCount: 4,
    check: isTwoPair,
  ),
  ComboDefinition(
    name: 'Pair',
    baseScore: 10,
    multiplier: 2,
    requiredCardCount: 2,
    check: isPair,
  ),
  // High Card is typically handled as a fallback, not a definition rule fires on.
  // We'll add a default score calculation in GameState if no other combo is played.
  ComboDefinition(
    name: 'High Card',
    baseScore: 5,
    multiplier: 1,
    requiredCardCount: 1,
    check: isHighCard,
  ), // Fallback
];
