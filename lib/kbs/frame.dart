// lib/kbs/frame.dart

import '../models/game_state.dart';
import '../models/card_model.dart';
import '../models/combo_definitions.dart';

/// A generic Frame interface for the KBS working memory.
abstract class Frame {
  String get name;

  /// A mutable slot‐map where rules can both read and write.
  Map<String, dynamic> get slots;
}

/// Frame wrapping the entire game state
class GameStateFrame implements Frame {
  final GameState gs;

  /// We keep a mutable slots map separate from the GameState itself.
  @override
  final Map<String, dynamic> slots = {};

  GameStateFrame(this.gs) {
    // initialize slots from current game state
    slots.addAll({
      'roundNumber': gs.roundNumber,
      'currentPoints': gs.currentPoints,
      'requiredPoints': gs.requiredPoints,
      'pointsGap': gs.requiredPoints - gs.currentPoints,
      'deckSize': gs.deck.length,
      'handSize': gs.hand.length,
      'playedCount': gs.playedCards.length,
      'discardedCount': gs.discardedCards.length,
      'movesSoFar': gs.playedCards.length + gs.discardedCards.length,
      // leave space for:
      //   'detectedCombos': List<ComboResult>
      //   'decision': String e.g. 'play:strong combo'
      //   'recommendedCardIndices': List<int>
    });
  }

  @override
  String get name => 'GameState';
}

/// Frame for an individual card
class CardFrame implements Frame {
  final CardModel card;
  @override
  final Map<String, dynamic> slots = {};

  CardFrame(this.card) {
    slots.addAll({
      'suit': card.suit,
      'value': card.value,
      'color': card.color,
      'chipValue': card.chipValue,
      'isRed': card.color == 'red',
      'isFaceCard': card.value >= 11 && card.value <= 13,
      'isAce': card.value == 14,
      'shortName': card.shortName,
    });
  }

  @override
  String get name => 'Card';
}

/// Frame for a detected combo
class ComboFrame implements Frame {
  final ComboResult combo;
  @override
  final Map<String, dynamic> slots = {};

  ComboFrame(this.combo) {
    slots.addAll({
      'comboName': combo.name,
      'score': combo.score,
      'cardCount': combo.cards.length,
      'cardValues': combo.cards.map((c) => c.value).toList(),
      'suits': combo.cards.map((c) => c.suit).toSet().toList(),
      'totalChipValue': combo.cards.fold<int>(0, (sum, c) => sum + c.chipValue),
    });
  }

  @override
  String get name => 'Combo';
}

/// Frame for a strategic recommendation (for explainability)
class StrategyFrame implements Frame {
  final String strategyType;
  final double riskLevel; // 0.0 .. 1.0
  final String description;
  final List<String> recommendations;

  @override
  final Map<String, dynamic> slots = {};

  StrategyFrame({
    required this.strategyType,
    required this.riskLevel,
    required this.description,
    required this.recommendations,
  }) {
    slots.addAll({
      'strategyType': strategyType,
      'riskLevel': riskLevel,
      'description': description,
      'recommendations': recommendations,
    });
  }

  @override
  String get name => 'Strategy';
}
