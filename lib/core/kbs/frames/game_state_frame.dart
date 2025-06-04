// lib/core/kbs/frames/game_state_frame.dart
import '../../models/card_model.dart';
import '../../models/combo_definitions.dart';
import '../../models/game_state.dart';
import 'frame.dart';

/// Represents the primary Working Memory content, derived from the GameState.
class GameStateFrame implements Frame {
  /// A reference to the original GameState, primarily for reading initial state.
  /// Rules should ideally interact only with the 'slots'.
  final GameState gameState;

  @override
  final String frameType = 'GameState';

  /// The mutable Working Memory slots for rules to read and write.
  @override
  final Map<String, dynamic> slots = {};

  /// Standard keys used for slots in the GameStateFrame.
  /// Defining these as constants improves maintainability and reduces typos.
  static const String roundNumber = 'roundNumber';
  static const String currentPoints = 'currentPoints';
  static const String requiredPoints = 'requiredPoints';
  static const String pointsGap = 'pointsGap';
  static const String remainingHands = 'remainingHands';
  static const String remainingDiscards = 'remainingDiscards';
  static const String initialHands = 'initialHands';
  static const String initialDiscards = 'initialDiscards';
  static const String maxHandSize = 'maxHandSize';
  static const String deckSize = 'deckSize';
  static const String handSize = 'handSize';
  static const String playedCount = 'playedCount';
  static const String discardedCount = 'discardedCount';
  static const String movesLeft =
      'movesLeft'; // Calculated: total possible - played - discarded
  static const String handCards = 'handCards'; // List<CardModel>
  static const String deckCards =
      'deckCards'; // List<CardModel> - Represents remaining deck
  static const String notification = 'notification'; // String for messages

  // Slots written by rules
  static const String detectedCombos = 'detectedCombos'; // List<ComboResult>
  static const String potentialCombos =
      'potentialCombos'; // List<PotentialComboInfo> (optional advanced)
  static const String strategicAdvice =
      'strategicAdvice'; // String or StrategyFrame
  static const String currentDecision =
      'currentDecision'; // e.g., 'play:strong_combo', 'discard:improve_hand'
  static const String recommendedIndices =
      'recommendedIndices'; // List<int> for play/discard
  static const String discardCandidatesEval =
      'discardCandidatesEval'; // List<MapEntry<int, Map>> for analysis

  GameStateFrame(this.gameState) {
    // Initialize slots from the current GameState snapshot
    slots[roundNumber] = gameState.roundNumber;
    slots[currentPoints] = gameState.currentPoints;
    slots[requiredPoints] = gameState.requiredPoints;
    slots[pointsGap] = gameState.requiredPoints - gameState.currentPoints;
    slots[remainingHands] = gameState.remainingHands;
    slots[remainingDiscards] = gameState.remainingDiscards;
    slots[initialHands] = gameState.initialHands;
    slots[initialDiscards] = gameState.initialDiscards;
    slots[maxHandSize] = gameState.maxHandSize;
    slots[deckSize] = gameState.deck.length;
    slots[handSize] = gameState.hand.length;
    slots[playedCount] = gameState.playedCards.length;
    slots[discardedCount] = gameState.discardedCards.length;

    // Calculation for movesLeft might be better here using the newly added initial values
    final playedHandsCount = gameState.initialHands - gameState.remainingHands;
    final usedDiscardsCount =
        gameState.initialDiscards - gameState.remainingDiscards;
    slots[movesLeft] =
        (gameState.initialHands + gameState.initialDiscards) -
        (playedHandsCount + usedDiscardsCount);
    // Alternative simpler calculation if played/discarded lists accurately track actions:
    // slots[movesLeft] = (gameState.initialHands + gameState.initialDiscards) - (gameState.playedCards.length + gameState.discardedCards.length); // Choose based on which counts are more reliable

    // Provide immutable views of collections to prevent accidental modification
    // outside the explicit KBS rule actions (which modify slots).
    slots[handCards] = List<CardModel>.unmodifiable(gameState.hand);
    slots[deckCards] = List<CardModel>.unmodifiable(gameState.deck);

    // Initialize slots that rules will populate
    slots[notification] =
        gameState.transientMessage ?? ''; // Start with any existing message
    slots[detectedCombos] = <ComboResult>[];
    slots[strategicAdvice] = null; // Initialize strategy slot
    slots[currentDecision] = null; // No decision yet
    slots[recommendedIndices] = <int>[];
    slots[discardCandidatesEval] = []; // Initialize as empty list
  }

  // --- Convenience Accessors (Optional but can be helpful) ---
  // These provide slightly more type safety than direct slot access,
  // but rules can still access slots directly.

  List<CardModel> get hand => slots[handCards] as List<CardModel>;
  List<CardModel> get deck => slots[deckCards] as List<CardModel>;
  int get reqPoints => slots[requiredPoints] as int;
  int get currPoints => slots[currentPoints] as int;
  int get handsLeft => slots[remainingHands] as int;
  int get discardsLeft => slots[remainingDiscards] as int;
  List<ComboResult> get combos => slots[detectedCombos] as List<ComboResult>;

  // Method to safely update a slot (used by rule actions)
  @override
  void updateSlot(String key, dynamic value) {
    slots[key] = value;
  }

  // Method to append to notification
  void appendNotification(String message) {
    final current = slots[notification] as String? ?? '';
    slots[notification] = current.isEmpty ? message : '$current\n$message';
  }

  // Add accessors if needed, though rules often access slots directly
  int get initHands => slots[initialHands] as int;
  int get initDiscards => slots[initialDiscards] as int;
}
