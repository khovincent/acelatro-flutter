import '../models/game_state.dart';

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
        'deckSize': gs.deck.length,
        'handSize': gs.hand.length,
        'playedCount': gs.playedCards.length,
        'discardedCount': gs.discardedCards.length,
      };
}
