import '../models/game_state.dart';
import '../models/card_model.dart';
import '../models/combo_definitions.dart';

abstract class Frame {
  String get name;
  Map<String, dynamic> get slots;
}

/// Frame for GameState
class GameStateFrame implements Frame {
  final GameState gs;
  GameStateFrame(this.gs);

  @override
  String get name => 'GameState';

  @override
  Map<String, dynamic> get slots => {
        'roundNumber': gs.roundNumber,
        'currentPoints': gs.currentPoints,
        'requiredPoints': gs.requiredPoints,
        'pointsGap': gs.requiredPoints - gs.currentPoints,
        'deckSize': gs.deck.length,
        'handSize': gs.hand.length,
        'playedCount': gs.playedCards.length,
        'discardedCount': gs.discardedCards.length,
        'handsRemaining':
            4 - gs.playedCards.length ~/ 5, // Assuming max 5 cards per hand
        'discardsRemaining': 4 -
            gs.discardedCards.length ~/ 5, // Assuming max 5 cards per discard
        'movesSoFar': gs.playedCards.length + gs.discardedCards.length,
        'averagePointsNeeded': (gs.requiredPoints - gs.currentPoints) /
            (4 - gs.playedCards.length ~/ 5).clamp(1, 4),
      };
}

/// Frame for a Card
class CardFrame implements Frame {
  final CardModel card;
  CardFrame(this.card);

  @override
  String get name => 'Card';

  @override
  Map<String, dynamic> get slots => {
        'suit': card.suit,
        'value': card.value,
        'color': card.color,
        'chipValue': card.chipValue,
        'isRed': card.color == 'red',
        'isFaceCard': card.value >= 11 && card.value <= 13,
        'isAce': card.value == 14,
        'shortName': card.shortName,
      };
}

/// Frame for a Combo
class ComboFrame implements Frame {
  final ComboResult combo;
  ComboFrame(this.combo);

  @override
  String get name => 'Combo';

  @override
  Map<String, dynamic> get slots => {
        'comboName': combo.name,
        'score': combo.score,
        'cardCount': combo.cards.length,
        'cardValues': combo.cards.map((c) => c.value).toList(),
        'suits': combo.cards.map((c) => c.suit).toSet().toList(),
        'uniqueValues': combo.cards.map((c) => c.value).toSet().length,
        'uniqueSuits': combo.cards.map((c) => c.suit).toSet().length,
        'totalChipValue':
            combo.cards.fold<int>(0, (sum, c) => sum + c.chipValue),
        'averageCardValue':
            combo.cards.fold<int>(0, (sum, c) => sum + c.value) /
                combo.cards.length,
      };
}

/// Frame for Strategy Recommendation
class StrategyFrame implements Frame {
  final String strategyType;
  final double riskLevel; // 0.0 to 1.0
  final String description;
  final List<String> recommendations;

  StrategyFrame({
    required this.strategyType,
    required this.riskLevel,
    required this.description,
    required this.recommendations,
  });

  @override
  String get name => 'Strategy';

  @override
  Map<String, dynamic> get slots => {
        'strategyType': strategyType,
        'riskLevel': riskLevel,
        'description': description,
        'recommendations': recommendations,
      };
}
