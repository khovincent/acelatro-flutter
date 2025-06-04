// lib/core/models/game_state.dart
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../kbs/frames/game_state_frame.dart';
import '../kbs/inference_engine.dart';
import '../kbs/rules/rule_registry.dart';
import '../utils/combinations_util.dart';
import 'card_model.dart';
import 'combo_definitions.dart';

// Enum to track different modes (e.g., for manual input vs. random dealing)
enum GameMode { demo, live }

// Represents the result of the KBS evaluation for explanation purposes
class KbsRecommendation {
  final String decision; // e.g., 'play:high_score', 'discard:improve_flush'
  final String action; // 'play' or 'discard'
  final String reason; // Extracted reason part of the decision
  final List<int> recommendedIndices;
  final List<CardModel> recommendedCards;
  final List<ComboResult> detectedCombosInHand;
  final List<String> firedRules; // From InferenceEngine activation history
  final List<MapEntry<int, Map<String, dynamic>>>? discardAnalysis;

  KbsRecommendation({
    required this.decision,
    required this.action,
    required this.reason,
    required this.recommendedIndices,
    required this.recommendedCards,
    required this.detectedCombosInHand,
    required this.firedRules,
    this.discardAnalysis,
  });
}

// Using ChangeNotifier to allow UI updates via Provider
class GameState extends ChangeNotifier {
  // --- Game Configuration ---
  final int maxHandSize = 8;
  final int initialHands = 4; // Starting number of allowed plays
  final int initialDiscards = 4; // Starting number of allowed discards
  final int defaultRequiredPoints = 300;

  // --- Core Game State ---
  List<CardModel> _deck = [];
  List<CardModel> _hand = [];
  final List<CardModel> _playedCards =
      []; // Cards successfully played as combos
  final List<CardModel> _discardedCards = []; // Cards explicitly discarded

  int roundNumber = 0;
  int currentPoints = 0;
  int requiredPoints = 300;
  int remainingHands = 4;
  int remainingDiscards = 4;
  GameMode mode = GameMode.demo;

  // --- KBS Interaction State ---
  bool _isKbsRunning = false; // Prevent concurrent runs
  KbsRecommendation? _latestRecommendation;
  final List<String> _kbsActivationLog = []; // Detailed log from engine
  String?
  _transientMessage; // Temporary messages for UI (e.g., "Played Flush!")

  // --- NEW: State for Live Mode Draw Input ---
  bool _needsDrawInput = false;
  int _cardsNeeded = 0;

  bool get needsDrawInput => _needsDrawInput;
  int get cardsNeeded => _cardsNeeded;
  // --- End New State ---

  // --- Getters for Read-Only Access to State ---
  List<CardModel> get hand => List.unmodifiable(_hand);
  List<CardModel> get deck =>
      List.unmodifiable(_deck); // Mostly for display (deck size)
  List<CardModel> get playedCards => List.unmodifiable(_playedCards);
  List<CardModel> get discardedCards => List.unmodifiable(_discardedCards);
  bool get isKbsRunning => _isKbsRunning;
  KbsRecommendation? get latestRecommendation => _latestRecommendation;
  List<String> get kbsActivationLog => List.unmodifiable(_kbsActivationLog);
  String? get transientMessage => _transientMessage; // Message from last action
  int get movesMade =>
      _playedCards.length + _discardedCards.length; // How many actions taken

  // --- Constructor ---
  GameState() {
    // Initialize the KBS rule system when the game state is first created
    _initializeKbsSystem();
    _switchToMode(GameMode.demo); // Start in demo mode initially
  }

  // --- Initialization ---
  void _initializeKbsSystem() {
    // Ensure the RuleRegistry is initialized (it's a singleton)
    RuleRegistry.instance.initialize();
    // Perform validation (optional but recommended)
    final errors = RuleRegistry.instance.validateDependencies();
    if (errors.isNotEmpty) {
      print("WARNING: Potential KBS Rule Dependency Issues Found:");
      errors.forEach(print);
    }
    // Add any other one-time KBS setup here
  }

  // Helper to switch mode and reset state accordingly
  void _switchToMode(GameMode newMode) {
    mode = newMode;
    _needsDrawInput = false; // Reset draw prompt on mode switch
    _cardsNeeded = 0;
    if (mode == GameMode.demo) {
      startNewRound(); // Reset everything for demo
    } else {
      // For live mode, start with empty state, waiting for initial input
      _hand.clear();
      _deck.clear(); // Deck will be initialized on first manual hand set
      _playedCards.clear();
      _discardedCards.clear();
      roundNumber = 1; // Or keep track differently?
      currentPoints = 0;
      requiredPoints = defaultRequiredPoints;
      remainingHands = initialHands;
      remainingDiscards = initialDiscards;
      _latestRecommendation = null;
      _kbsActivationLog.clear();
      _transientMessage = "Switched to Live Mode. Use Live Input tab.";
      notifyListeners();
      // No KBS run until hand is submitted
    }
  }

  // Public method to toggle mode
  void toggleMode() {
    _switchToMode(mode == GameMode.demo ? GameMode.live : GameMode.demo);
  }

  /// Sets up a new round of the game.
  void startNewRound() {
    if (mode != GameMode.demo) {
      print("Warning: startNewRound called while not in Demo mode.");
      // Optionally switch to demo mode? Or just ignore?
      // _switchToMode(GameMode.demo); // Force switch?
      return; // Ignore if not in demo mode
    }

    roundNumber++;
    currentPoints = 0;
    requiredPoints = defaultRequiredPoints; // Or adjust based on roundNumber
    remainingHands = initialHands;
    remainingDiscards = initialDiscards;
    _hand.clear();
    _playedCards.clear();
    _discardedCards.clear();
    _deck = _createStandardDeck();
    _deck.shuffle(Random());
    _dealInitialHand(); // Deals AND removes from _deck

    _latestRecommendation = null;
    _kbsActivationLog.clear();
    _transientMessage = "Round $roundNumber started (Demo).";
    _needsDrawInput = false;
    _cardsNeeded = 0;

    notifyListeners(); // Notify UI about the reset
    runKbsEvaluation(); // Run KBS for initial hand assessment
  }

  List<CardModel> _createStandardDeck() {
    final List<CardModel> newDeck = [];
    for (final suit in CardModel.suitSymbols.keys) {
      for (final value in CardModel.valueNames.keys) {
        // print("Adding card to deck: Value=$value, Suit=$suit");
        newDeck.add(CardModel(suit: suit, value: value));
      }
    }
    return newDeck;
  }

  void _dealInitialHand() {
    // Only used in Demo startNewRound
    int cardsToDeal = min(maxHandSize, _deck.length);
    for (int i = 0; i < cardsToDeal; i++) {
      if (_deck.isNotEmpty) {
        // Check deck isn't empty
        _hand.add(_deck.removeLast());
      }
    }
  }

  // --- Core Game Actions (Modified for Live Mode) ---
  void playCards(List<int> indicesToPlay) {
    if (_isKbsRunning) return;
    if (remainingHands <= 0) {
      _transientMessage = "No hands remaining!";
      notifyListeners();
      return;
    }
    if (indicesToPlay.isEmpty) {
      _transientMessage = "No cards selected to play.";
      notifyListeners();
      return;
    }

    // Validate indices
    indicesToPlay.sort((a, b) => b.compareTo(a));
    if (indicesToPlay.any((index) => index < 0 || index >= _hand.length)) {
      _transientMessage = "Invalid card selection for play.";
      notifyListeners();
      return;
    }

    final cardsToPlay = indicesToPlay.map((index) => _hand[index]).toList();
    // Identify the best combo these *specific* cards make
    // (This might differ from the best combo available in the whole hand)
    final playedComboResult = identifyCombo(cardsToPlay); // Use helper

    if (playedComboResult == null) {
      _transientMessage = "Selected cards do not form a recognized combo.";
      notifyListeners();
      return;
    }

    // --- Execute Play ---
    currentPoints += playedComboResult.score;
    remainingHands--;
    _transientMessage =
        "Played ${playedComboResult.name} for ${playedComboResult.score} points!";

    // Remove played cards from hand
    for (final index in indicesToPlay) {
      _hand.removeAt(index); // Safe due to descending sort
    }
    _playedCards.addAll(cardsToPlay);

    // --- Live Mode: Trigger Draw Input ---
    if (mode == GameMode.live) {
      _needsDrawInput = true;
      _cardsNeeded = cardsToPlay.length;
      _transientMessage =
          "$_transientMessage\nPlease input the $_cardsNeeded card(s) drawn.";
      _latestRecommendation = null; // Clear old recommendation
      notifyListeners(); // Signal UI to show prompt
      // DO NOT run KBS evaluation yet
    }
    // --- Demo Mode: Draw Automatically ---
    else {
      // mode == GameMode.demo
      _drawCardsFromDeck(cardsToPlay.length); // Use internal deck
      notifyListeners(); // Update UI with new hand/deck size
      runKbsEvaluation(); // Re-evaluate state after drawing
    }
  }

  /// Discards cards at the given indices.
  void discardCards(List<int> indicesToDiscard) {
    if (_isKbsRunning) return;
    if (remainingDiscards <= 0) {
      _transientMessage = "No discards remaining!";
      notifyListeners();
      return;
    }
    if (indicesToDiscard.isEmpty) {
      _transientMessage = "No cards selected to discard.";
      notifyListeners();
      return;
    }
    if (indicesToDiscard.length >= _hand.length && _hand.isNotEmpty) {
      _transientMessage = "Cannot discard all cards.";
      notifyListeners();
      return;
    }

    // Validate indices
    indicesToDiscard.sort(
      (a, b) => b.compareTo(a),
    ); // Sort descending for safe removal
    if (indicesToDiscard.any((index) => index < 0 || index >= _hand.length)) {
      _transientMessage = "Invalid card selection for discard.";
      notifyListeners();
      return;
    }

    final cardsToDiscard =
        indicesToDiscard.map((index) => _hand[index]).toList();

    // --- Execute Discard ---
    remainingDiscards--;
    _transientMessage = "Discarded ${cardsToDiscard.length} card(s).";

    // Remove discarded cards from hand
    for (final index in indicesToDiscard) {
      _hand.removeAt(index); // Safe due to descending sort
    }
    _discardedCards.addAll(cardsToDiscard);

    // --- Live Mode: Trigger Draw Input ---
    if (mode == GameMode.live) {
      _needsDrawInput = true;
      _cardsNeeded = cardsToDiscard.length;
      _transientMessage =
          "$_transientMessage\nPlease input the $_cardsNeeded card(s) drawn.";
      _latestRecommendation = null; // Clear old recommendation
      notifyListeners(); // Signal UI to show prompt
      // DO NOT run KBS evaluation yet
    }
    // --- Demo Mode: Draw Automatically ---
    else {
      // mode == GameMode.demo
      _drawCardsFromDeck(cardsToDiscard.length); // Use internal deck
      notifyListeners(); // Update UI with new hand/deck size
      runKbsEvaluation(); // Re-evaluate state after drawing
    }
  }

  // Helper for automatic drawing in Demo mode
  void _drawCardsFromDeck(int count) {
    if (mode != GameMode.demo) return; // Should only be called in demo
    int cardsToDraw = min(count, _deck.length);
    if (cardsToDraw <= 0) {
      if (_deck.isEmpty) {
        _transientMessage = "${_transientMessage ?? ""}\nDeck is empty!";
      }
      return;
    }
    for (int i = 0; i < cardsToDraw; i++) {
      if (_hand.length < maxHandSize) {
        _hand.add(_deck.removeLast());
      } else {
        break;
      }
    }
  }

  // --- NEW Method to handle dialog cancel ---
  void resetDrawInputFlag() {
    if (_needsDrawInput) {
      print("Resetting draw input requirement due to cancel.");
      _needsDrawInput = false;
      _cardsNeeded = 0;
      // Restore previous message or set a new one?
      _transientMessage = "Draw input cancelled. Select action again.";
      notifyListeners();
      // Optionally re-run KBS if cancelling should revert to pre-action state?
      // runKbsEvaluation();
    }
  }
  // --- End New Method ---

  // --- NEW Method for Live Mode Draw Input ---
  void addDrawnCards(List<CardModel> drawnCards) {
    if (mode != GameMode.live || !_needsDrawInput) {
      print(
        "Warning: addDrawnCards called inappropriately. Mode: $mode, NeedsInput: $_needsDrawInput",
      );
      return;
    }
    if (drawnCards.length != _cardsNeeded) {
      _transientMessage =
          "Error: Expected $_cardsNeeded drawn cards, received ${drawnCards.length}. Please try again.";
      notifyListeners();
      // Keep _needsDrawInput = true so UI prompt stays
      return;
    }

    // Validate that drawn cards are theoretically in the app's deck representation
    bool allCardsValid = true;
    List<CardModel> tempDeck = List.from(_deck); // Check against a copy
    for (final drawnCard in drawnCards) {
      int deckIndex = tempDeck.indexWhere((deckCard) => deckCard == drawnCard);
      if (deckIndex == -1) {
        print(
          "Error: Card ${drawnCard.shortName} reported as drawn, but not found in internal deck representation.",
        );
        _transientMessage =
            "Error: Card ${drawnCard.shortName} is not expected to be in the deck. Check input.";
        allCardsValid = false;
        break; // Stop checking
      } else {
        tempDeck.removeAt(
          deckIndex,
        ); // Remove from temp copy for duplicate checks
      }
    }

    if (!allCardsValid) {
      notifyListeners();
      // Keep _needsDrawInput = true
      return;
    }

    // --- Update State ---
    _hand.addAll(drawnCards); // Add to hand

    // Remove *exact* cards from internal deck
    for (final drawnCard in drawnCards) {
      _deck.remove(drawnCard); // Assumes CardModel equality works
    }

    _needsDrawInput = false; // Reset flags
    _cardsNeeded = 0;
    _transientMessage =
        "Received ${drawnCards.length} drawn card(s). Analyzing new hand...";

    print(
      "Live Mode: Added drawn cards: ${drawnCards.map((c) => c.shortName).join(',')}",
    );
    print("Live Mode: New hand: ${_hand.map((c) => c.shortName).join(',')}");
    print("Live Mode: Updated internal deck size: ${_deck.length}");

    notifyListeners(); // Update UI first
    runKbsEvaluation(); // Now analyze the completed hand
  }
  // --- End New Method ---

  // --- Hand Manipulation ---
  void sortHandByRank() {
    _hand.sort((a, b) => a.value.compareTo(b.value));
    _transientMessage = "Hand sorted by rank.";
    notifyListeners();
  }

  void sortHandBySuit() {
    const suitOrder = {'Spades': 0, 'Hearts': 1, 'Diamonds': 2, 'Clubs': 3};
    _hand.sort((a, b) {
      final suitCompare = (suitOrder[a.suit] ?? 4).compareTo(
        suitOrder[b.suit] ?? 4,
      );
      if (suitCompare != 0) return suitCompare;
      return a.value.compareTo(b.value); // Sort by rank within suit
    });
    _transientMessage = "Hand sorted by suit.";
    notifyListeners();
  }

  // Used in Live mode to manually set the hand
  void setHandManually(List<CardModel> newHand) {
    // This is now the primary way to START a live session tracking
    if (mode != GameMode.live && newHand.isNotEmpty) {
      print("Switching to Live Mode due to manual hand set.");
      mode = GameMode.live; // Automatically switch if needed
    } else if (mode != GameMode.live && newHand.isEmpty) {
      // If setting empty hand while not in live mode, maybe switch to live? Or ignore?
      print("Ignoring empty hand set while not in Live mode.");
      return;
    }

    print("--- GameState: setHandManually called ---"); // START log
    print("Received hand: ${newHand.map((c) => c.shortName).join(', ')}");

    // 1. Set the hand
    _hand = List.from(newHand.take(maxHandSize)); // Ensure max size

    // 2. Initialize/Reset other state for the live session
    _playedCards.clear();
    _discardedCards.clear();
    currentPoints = 0; // Assuming score resets per tracked session
    remainingHands = initialHands;
    remainingDiscards = initialDiscards;
    _needsDrawInput = false; // Start fresh, not needing input
    _cardsNeeded = 0;

    // 3. Initialize internal deck representation
    _deck = _createStandardDeck();
    // Remove cards currently in hand from the internal deck
    for (final handCard in _hand) {
      _deck.remove(handCard); // Assumes equality works
    }
    _deck.shuffle(Random()); // Shuffle the remaining deck

    _transientMessage = "Live hand set. Deck size: ${_deck.length}";
    _latestRecommendation = null; // Clear previous recommendation

    print(
      "Internal _hand updated to: ${_hand.map((c) => c.shortName).join(', ')}",
    );
    print("Internal _deck initialized. Size: ${_deck.length}");
    print("Calling notifyListeners...");
    notifyListeners();

    print("Calling runKbsEvaluation...");
    // Run analysis immediately on the submitted hand
    if (_hand.isNotEmpty) {
      runKbsEvaluation();
    } else {
      _transientMessage = "Live hand cleared. Input a hand.";
      notifyListeners();
    }

    print("--- GameState: setHandManually finished ---");
  }

  // --- KBS Orchestration ---
  /// Runs the KBS inference engine to analyze the current state and generate recommendations.
  Future<void> runKbsEvaluation() async {
    if (_isKbsRunning) {
      print("GameState: KBS evaluation already in progress, skipping.");
      return;
    }
    print("--- GameState: runKbsEvaluation START ---"); // START log
    _isKbsRunning = true;
    _transientMessage = "🤖 Analyzing hand..."; // Indicate KBS is working
    notifyListeners(); // Notify UI that analysis is starting

    try {
      // 1. Create the Working Memory Frame
      final workingMemory = GameStateFrame(
        this,
      ); // 'this' provides the snapshot
      print(
        "Created GameStateFrame with hand: ${workingMemory.hand.map((c) => c.shortName).join(', ')}",
      ); // Log hand going into KBS

      // 2. Initialize and Run the Inference Engine
      final engine = InferenceEngine(
        ruleRegistry: RuleRegistry.instance,
        workingMemory: workingMemory,
      );
      engine.run(); // This executes all phases
      print(
        "KBS Engine run complete. History: ${engine.activationHistory.length} rules fired.",
      ); // Log engine completion

      // 3. Extract Results from Working Memory
      _extractKbsResults(workingMemory, engine.activationHistory);
      print(
        "KBS Results extracted. Recommendation: ${_latestRecommendation?.decision}",
      ); // Log result extraction
    } catch (e, stackTrace) {
      print(
        "FATAL ERROR during KBS Evaluation: $e \n $stackTrace",
      ); // Log errors
      _transientMessage = "⚠️ Error during analysis.";
      // Reset recommendation?
      _latestRecommendation = null;
    } finally {
      _isKbsRunning = false;
      // Clear the "Analyzing" message if no other message replaced it
      if (_transientMessage == "🤖 Analyzing hand...") {
        _transientMessage =
            _latestRecommendation != null
                ? "Analysis complete. Recommendation available."
                : "Analysis complete.";
      }
      print("--- GameState: runKbsEvaluation END ---"); // END log
      notifyListeners(); // Update UI with results/status
    }
  }

  /// Parses the results from the Working Memory slots after inference.
  void _extractKbsResults(GameStateFrame wm, List<String> history) {
    _kbsActivationLog.clear();
    _kbsActivationLog.addAll(history);

    final decision =
        wm.slots[GameStateFrame.currentDecision] as String? ??
        'none:no_decision';

    final recommendedIndices = List<int>.from(
      wm.slots[GameStateFrame.recommendedIndices] as List? ?? [],
    );

    final detectedCombos = List<ComboResult>.from(
      wm.slots[GameStateFrame.detectedCombos] as List? ?? [],
    );
    print(
      "Extracted detectedCombos (count: ${detectedCombos.length}): ${detectedCombos.map((c) => c.name).join(', ')}",
    ); // Log extracted combos

    final discardAnalysisRaw =
        wm.slots[GameStateFrame.discardCandidatesEval] as List?;

    // Process discard analysis if present
    final List<MapEntry<int, Map<String, dynamic>>>? discardAnalysis =
        discardAnalysisRaw
            ?.whereType<MapEntry>() // Ensure items are MapEntry
            .map((entry) {
              // Basic type check for key and value structure
              if (entry.key is int && entry.value is Map) {
                return MapEntry<int, Map<String, dynamic>>(
                  entry.key,
                  Map<String, dynamic>.from(entry.value),
                );
              }
              return null; // Invalid entry format
            })
            .where((item) => item != null) // Filter out invalid entries
            .cast<
              MapEntry<int, Map<String, dynamic>>
            >() // Cast to the correct type
            .toList();

    // Ensure recommended indices are valid for the current hand
    final validRecommendedIndices =
        recommendedIndices
            .where((index) => index >= 0 && index < _hand.length)
            .toList();

    final recommendedCards =
        validRecommendedIndices.map((i) => _hand[i]).toList();

    // Parse decision string 'action:reason'
    String action = 'none';
    String reason = 'no_decision';
    if (decision.contains(':')) {
      final parts = decision.split(':');
      action = parts[0];
      reason = parts.length > 1 ? parts[1] : action;
    } else {
      action = decision; // Handle cases where there's no colon
      reason = decision;
    }

    _latestRecommendation = KbsRecommendation(
      decision: decision,
      action: action,
      reason: reason,
      recommendedIndices: validRecommendedIndices,
      recommendedCards: recommendedCards,
      detectedCombosInHand: detectedCombos, // Combos found in the hand
      firedRules: history,
      discardAnalysis: discardAnalysis,
    );

    // Update transient message based on recommendation
    if (validRecommendedIndices.isNotEmpty) {
      final cardNames = recommendedCards.map((c) => c.shortName).join(', ');
      _transientMessage =
          "🤖 Suggests: ${action.toUpperCase()} $cardNames ($reason)";
    } else if (action != 'none') {
      _transientMessage = "🤖 Suggests: ${action.toUpperCase()} ($reason)";
    } else {
      _transientMessage = "Analysis complete. No specific action recommended.";
    }

    // No notifyListeners here, called by runKbsEvaluation's finally block
  }

  // --- Hand Analysis Helper (Can be called by UI or KBS Rules) ---

  /// Analyzes the current hand for all possible combos based on definitions.
  /// Returns a sorted list of ComboResult (best first).
  List<ComboResult> analyzeHand() {
    var results = <ComboResult>[];
    final currentHand = _hand; // Use the internal mutable hand

    for (final definition in balatroComboDefinitions) {
      // Skip checks if hand doesn't have enough cards for the core requirement
      if (currentHand.length < definition.requiredCardCount) continue;

      // Generate combinations of the size needed for the combo check
      // Balatro often plays 5 cards, even for smaller combos like pairs.
      // But the *detection* might look for the core N cards.
      // Let's check all relevant sizes up to hand size, prioritizing definition size.
      // Simplification: Let's check using *all possible subsets* that meet the min requirement.
      // A more Balatro-specific approach might be needed.

      // Check combinations of exactly the required size first
      if (currentHand.length >= definition.requiredCardCount) {
        for (final comboCards in combinations(
          currentHand,
          definition.requiredCardCount,
        )) {
          if (definition.check(comboCards)) {
            final score = definition.calculateScore(comboCards);
            // Check for duplicates before adding? Depends on how combinations yields.
            results.add(
              ComboResult(
                name: definition.name,
                cards: comboCards,
                score: score,
                definition: definition,
              ),
            );
          }
        }
      }
      // Optional: Check larger hand sizes if the check supports it (e.g., finding a pair within 5 cards)
      // This logic can get complex. Sticking to requiredCardCount check for now.
    }

    // Sort results: Higher score first, then by name for ties.
    results.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      // Optional: Prioritize combos using more cards if scores are equal
      // final cardCountCompare = b.cards.length.compareTo(a.cards.length);
      // if (cardCountCompare != 0) return cardCountCompare;
      return a.name.compareTo(b.name); // Alphabetical for final tie-break
    });

    // Deduplication (important if combinations yields subsets)
    // A simple dedupe based on exact card set and name might be needed.
    final uniqueResults = <ComboResult>[];
    final seenSignatures = <String>{};
    for (final result in results) {
      final signature =
          "${result.name}-${result.cards.map((c) => c.shortName).toList()..sort()}";
      if (seenSignatures.add(signature)) {
        uniqueResults.add(result);
      }
    }

    // Add High Card as a fallback if nothing else was found and hand is not empty
    if (uniqueResults.isEmpty && currentHand.isNotEmpty) {
      final highCardDef = balatroComboDefinitions.firstWhere(
        (def) => def.name == 'High Card',
      );
      final highestCard = currentHand.reduce(
        (a, b) => a.chipValue > b.chipValue ? a : b,
      );
      uniqueResults.add(
        ComboResult(
          name: highCardDef.name,
          cards: [highestCard], // High card combo is just the one card
          score: highCardDef.calculateScore([highestCard]),
          definition: highCardDef,
        ),
      );
    }

    return uniqueResults;
  }

  /// Identifies the best combo formed by a *specific* list of cards.
  /// Used when playing cards. Returns null if no combo is formed.
  ComboResult? identifyCombo(List<CardModel> selectedCards) {
    if (selectedCards.isEmpty) return null;

    ComboResult? bestMatch;

    for (final definition in balatroComboDefinitions) {
      // Check if the selected cards *meet the requirements* of the definition
      // Note: A player might select 5 cards for a "Pair". The check needs to handle this.
      // The `check` function should ideally work correctly regardless of extra cards,
      // but the `requiredCardCount` is a hint.
      if (selectedCards.length >= definition.requiredCardCount &&
          definition.check(selectedCards)) {
        final score = definition.calculateScore(selectedCards);
        // If we find a match, keep it if it's better than the current best
        if (bestMatch == null || score > bestMatch.score) {
          bestMatch = ComboResult(
            name: definition.name,
            cards: selectedCards, // The cards actually played
            score: score,
            definition: definition,
          );
        }
        // Since definitions are ordered, the first match is the highest rank.
        // So we can potentially break early if score isn't the only factor.
        // Sticking to highest score for simplicity here.
        break; // Found the highest-ranking combo these cards satisfy
      }
    }
    // Add high card fallback if *absolutely nothing* else matched?
    // Usually, a play action requires a valid combo > High Card.
    // Let's return null if no standard combo is met by the selection.
    // if (bestMatch == null && selectedCards.isNotEmpty) {
    //    final highCardDef = balatroComboDefinitions.firstWhere((def) => def.name == 'High Card');
    //    final highestCard = selectedCards.reduce((a, b) => a.chipValue > b.chipValue ? a : b);
    //    return ComboResult( name: highCardDef.name, cards: [highestCard], score: highCardDef.calculateScore([highestCard]), definition: highCardDef);
    // }

    return bestMatch;
  }
}
