import '../models/game_state.dart';
import '../models/card_model.dart';
import '../models/combo_definitions.dart';
import 'frame.dart';
import 'rule_base.dart';

class StrategyAdvisor {
  final GameState gameState;

  StrategyAdvisor(this.gameState);

  /// Evaluate whether to play or discard based on current game state
  String evaluatePlayOrDiscard() {
    final comboResults = gameState.analyzeHand();
    final topCombo = comboResults.isNotEmpty ? comboResults.first : null;

    // Points needed to meet target
    final pointsGap = gameState.requiredPoints - gameState.currentPoints;

    // Remaining moves
    final handsRemaining = 4 - gameState.playedCards.length ~/ 5;
    final discardsRemaining = 4 - gameState.discardedCards.length ~/ 5;
    final movesRemaining = handsRemaining + discardsRemaining;

    // Average points needed per remaining hand
    final avgPointsNeeded =
        movesRemaining > 0 ? pointsGap / handsRemaining : double.infinity;

    // If we have a good combo
    if (topCombo != null && topCombo.score > 0) {
      if (topCombo.score >= pointsGap) {
        return "PLAY: This combo will reach your target";
      }

      if (topCombo.score >= avgPointsNeeded) {
        return "PLAY: This combo scores above your needed average";
      }

      if (topCombo.score >= 60) {
        return "PLAY: This is a strong combo worth playing";
      }
    }

    // Low scoring hand and have discards left
    if ((topCombo == null || topCombo.score < 30) && discardsRemaining > 0) {
      return "DISCARD: Your hand is weak, better to refresh";
    }

    // Final moves with insufficient score
    if (movesRemaining <= 2 &&
        (topCombo == null || topCombo.score < pointsGap / movesRemaining)) {
      if (discardsRemaining > 0) {
        return "DISCARD: Need stronger combos to meet target";
      } else {
        return "PLAY: No discards left, play your best combo";
      }
    }

    // Default fallback
    if (topCombo != null && topCombo.score >= 20) {
      return "PLAY: This is a reasonable combo";
    } else if (discardsRemaining > 0) {
      return "DISCARD: Try to get better cards";
    } else {
      return "PLAY: No more discards available";
    }
  }

  /// Get recommended cards to play or discard
  List<int> recommendCardIndices(bool forPlay) {
    if (forPlay) {
      // Find best combo
      final combos = gameState.analyzeHand();
      if (combos.isEmpty) return [];

      final bestCombo = combos.first;
      // Find indices of those cards in current hand
      final indices = <int>[];
      for (final card in bestCombo.cards) {
        final index = gameState.hand
            .indexWhere((c) => c.suit == card.suit && c.value == card.value);
        if (index >= 0) indices.add(index);
      }
      return indices;
    } else {
      // Discard strategy: discard lowest value cards or ones that don't contribute to combos
      final List<int> discardCandidates = [];

      // Get all cards involved in top 3 combos
      final topCombos = gameState.analyzeHand().take(3);
      final Set<CardModel> valuableCards = {};
      for (final combo in topCombos) {
        valuableCards.addAll(combo.cards);
      }

      // Find cards not involved in top combos
      for (int i = 0; i < gameState.hand.length; i++) {
        final isInTopCombos = valuableCards.any((c) =>
            c.suit == gameState.hand[i].suit &&
            c.value == gameState.hand[i].value);

        if (!isInTopCombos) {
          discardCandidates.add(i);
        }
      }

      // If we found some cards to discard
      if (discardCandidates.isNotEmpty) {
        // Take up to 5 cards to discard
        return discardCandidates.take(5).toList();
      }

      // Fallback: discard lowest value cards
      final List<MapEntry<int, int>> indexedValues = [];
      for (int i = 0; i < gameState.hand.length; i++) {
        indexedValues.add(MapEntry(i, gameState.hand[i].value));
      }
      indexedValues.sort((a, b) => a.value.compareTo(b.value));

      return indexedValues
          .take(gameState.hand.length > 5 ? 5 : gameState.hand.length - 1)
          .map((e) => e.key)
          .toList();
    }
  }

  /// Get a full recommendation including reasoning
  Map<String, dynamic> getFullRecommendation() {
    final playOrDiscard = evaluatePlayOrDiscard();
    final forPlay = playOrDiscard.startsWith("PLAY");
    final cardIndices = recommendCardIndices(forPlay);

    final Map<String, dynamic> recommendation = {
      'action': forPlay ? 'play' : 'discard',
      'reason': playOrDiscard.substring(playOrDiscard.indexOf(':') + 1).trim(),
      'cardIndices': cardIndices,
      'cards': cardIndices.map((i) => gameState.hand[i].shortName).toList(),
    };

    if (forPlay) {
      final cardsToPlay = cardIndices.map((i) => gameState.hand[i]).toList();
      if (cardsToPlay.isNotEmpty) {
        final combo = gameState.identifyCombo(cardsToPlay);
        recommendation['combo'] = combo.name;
        recommendation['score'] = combo.score;
      }
    }

    // Get fired rules for context
    final wm = GameStateFrame(gameState);
    final rules = BalatroRuleSet.getDefaultRules();
    final engine = InferenceEngine(rules, wm);
    engine.forwardChain();
    recommendation['appliedRules'] = engine.activationHistory;
    return recommendation;
  }
}

/// Extension method for GameState to provide strategy recommendations
extension GameStateStrategy on GameState {
  Map<String, dynamic> getStrategyRecommendation() {
    final advisor = StrategyAdvisor(this);
    return advisor.getFullRecommendation();
  }
}
