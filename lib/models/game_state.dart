// lib/models/game_state.dart

import 'dart:math';
import 'card_model.dart';
import 'combo_definitions.dart';

import '../kbs/frame.dart';
import '../kbs/rule_base.dart';
import '../kbs/combo_rules.dart';
import '../kbs/play_discard_rules.dart';
import '../kbs/card_selection_rules.dart';

enum GameMode { demo, live }

class GameState {
  GameMode mode = GameMode.demo;

  // Core game data
  List<CardModel> deck = [];
  List<CardModel> hand = [];
  List<CardModel> playedCards = [];
  List<CardModel> discardedCards = [];

  int currentPoints = 0;
  int requiredPoints = 300;
  int roundNumber = 0;
  final int maxHandSize = 8;

  /// Combined KBS notifications + user messages
  String notification = '';

  int get movesSoFar => playedCards.length + discardedCards.length;

  // For debugging / explainability
  final List<String> _kbsLog = [];
  Map<String, dynamic>? _latestRecommendation;

  GameState() {
    startRound();
  }

  /// Starts a new round: shuffle, deal, reset state & run initial KBS
  void startRound() {
    roundNumber++;
    currentPoints = 0;
    playedCards.clear();
    discardedCards.clear();
    hand.clear();
    _kbsLog.clear();
    _latestRecommendation = null;
    notification = '';

    _initializeDeck();
    _dealInitialHand();
    runKbsEvaluation();
  }

  void _initializeDeck() {
    deck = [];
    for (var suit in CardModel.suitSymbols.keys) {
      for (var value in CardModel.values.keys) {
        deck.add(CardModel(suit, value));
      }
    }
    deck.shuffle(Random());
  }

  void _dealInitialHand() {
    for (int i = 0; i < maxHandSize; i++) {
      dealCard();
    }
  }

  void dealCard() {
    if (deck.isNotEmpty) hand.add(deck.removeLast());
  }

  /// **Central KBS invocation** — builds WM, runs all rules, logs + notifies
  void runKbsEvaluation() {
    // 1. Build working memory
    final wm = GameStateFrame(this);

    // 2. Instantiate inference engine with all rule sets
    final engine = InferenceEngine(
      [
        ...BalatroRuleSet.getDefaultRules(),
        ...ComboDetectionEngine.getComboRules(),
        ...PlayDiscardRules.getRules(),
        ...CardSelectionRules.getRules(),
      ],
      wm,
    );

    // 3. Fire forward chains
    engine.forwardChain();

    // 4. Record what fired
    _kbsLog.addAll(engine.activationHistory);

    // 5. Extract decision + indices + build recommendation
    final decision = (wm.slots['decision'] as String?) ?? 'play:fallback';
    final action = decision.startsWith('play') ? 'Play' : 'Discard';
    final indices =
        List<int>.from(wm.slots['recommendedCardIndices'] as List<int>? ?? []);
    final cardNames = indices.map((i) => hand[i].shortName).join(', ');
    final reason = decision.contains(':') ? decision.split(':')[1] : decision;

    // 6. Store for external inspection (if needed)
    _latestRecommendation = {
      'action': action.toLowerCase(), // 'play' or 'discard'
      'cardIndices': indices, // List<int>
      'cards': cardNames.split(', '), // List<String>
      'reason': reason, // String
      'firedRules': engine.activationHistory, // List<String>
      'detectedCombos': wm.slots['detectedCombos'], // List<ComboResult>
    };

    // 7. Append to notification area
    if (cardNames.isNotEmpty) {
      notification +=
          '\n🤖 KBS Recommends: $action $cardNames\n💭 Reasoning: $reason';
    }
  }

  /// Analyze hand for all combos (unchanged)
  List<ComboResult> analyzeHand() {
    var results = <ComboResult>[];
    for (var def in comboDefinitions) {
      if (hand.length < def.cardCount) continue;
      for (var combo in combinations(hand, def.cardCount)) {
        if (def.check(combo)) {
          var chipSum = combo.fold<int>(0, (sum, c) => sum + c.chipValue);
          var score = (def.base + chipSum) * def.multiplier;
          results.add(ComboResult(def.name, combo, score));
        }
      }
    }
    // High Card fallback
    if (hand.isNotEmpty) {
      var maxCard = hand.reduce((a, b) => a.value > b.value ? a : b);
      var score = (5 + maxCard.chipValue) * 1;
      results.add(ComboResult('High Card', [maxCard], score));
    }
    // Dedupe & sort
    final seen = <String>{};
    final unique = <ComboResult>[];
    for (var r in results) {
      final key = '${r.name}-${r.cards.map((c) => c.value).join(",")}';
      if (seen.add(key)) unique.add(r);
    }
    unique.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });
    return unique;
  }

  /// Identify a combo from selected cards (unchanged)
  ComboResult identifyCombo(List<CardModel> selected) {
    for (var def in comboDefinitions) {
      if (selected.length >= def.cardCount &&
          def.check(selected.sublist(0, def.cardCount))) {
        var chipSum = selected.fold<int>(0, (sum, c) => sum + c.chipValue);
        var score = (def.base + chipSum) * def.multiplier;
        return ComboResult(def.name, selected, score);
      }
    }
    // fallback High Card
    var mc = selected.reduce((a, b) => a.value > b.value ? a : b);
    return ComboResult('High Card', [mc], (5 + mc.chipValue) * 1);
  }

  /// Play the selected combo, update points + re-run KBS
  ComboResult playCombo(List<int> indices) {
    if (indices.isEmpty) {
      notification = 'No cards selected to play!';
      return ComboResult('None', [], 0);
    }
    var selected = indices.map((i) => hand[i]).toList();
    var combo = identifyCombo(selected);

    // Remove from hand (descending to keep indices valid)
    indices.toSet().toList()
      ..sort((a, b) => b.compareTo(a))
      ..forEach(hand.removeAt);
    playedCards.addAll(selected);

    // Refill to maxHandSize
    while (hand.length < maxHandSize) dealCard();

    currentPoints += combo.score;
    notification = 'Played ${combo.name} and earned ${combo.score} points!';

    runKbsEvaluation();
    return combo;
  }

  /// Discard selected cards, draw fresh + re-run KBS
  void discard(List<int> indices) {
    if (indices.isEmpty) {
      notification = 'No cards selected to discard!';
      return;
    }
    if (indices.length >= hand.length) {
      notification = 'Cannot discard all cards—must keep at least one.';
      return;
    }
    var selected = indices.map((i) => hand[i]).toList();
    indices.toSet().toList()
      ..sort((a, b) => b.compareTo(a))
      ..forEach(hand.removeAt);
    discardedCards.addAll(selected);

    while (hand.length < maxHandSize) dealCard();

    notification = 'Discarded ${selected.length} cards.';
    runKbsEvaluation();
  }

  void sortHandByRank() {
    hand.sort((a, b) => a.value.compareTo(b.value));
    notification = 'Hand sorted by rank.';
  }

  void sortHandBySuit() {
    int suitOrder(String s) {
      switch (s) {
        case 'Spades':
          return 0;
        case 'Hearts':
          return 1;
        case 'Diamonds':
          return 2;
        case 'Clubs':
          return 3;
        default:
          return 4;
      }
    }

    hand.sort((a, b) {
      final cmp = suitOrder(a.suit).compareTo(suitOrder(b.suit));
      return cmp != 0 ? cmp : a.value.compareTo(b.value);
    });
    notification = 'Hand sorted by suit.';
  }

  void addCardToHand(CardModel card) {
    if (hand.length < maxHandSize) {
      hand.add(card);
      notification = 'Card ${card.shortName} added to hand.';
      runKbsEvaluation();
    } else {
      notification = 'Cannot add more than $maxHandSize cards.';
    }
  }

  List<CardModel> getFullDeck() {
    final cards = <CardModel>[];
    for (var suit in CardModel.suitSymbols.keys) {
      for (var value in CardModel.values.keys) {
        cards.add(CardModel(suit, value));
      }
    }
    return cards;
  }

  /// Expose for debugging
  List<String> get kbsLog => List.unmodifiable(_kbsLog);

  /// Latest recommendation summary
  Map<String, dynamic>? get latestRecommendation => _latestRecommendation;

  /// Convenience: list of indices from last KBS run
  List<int> selectRecommendedCards() {
    return List<int>.from(_latestRecommendation?['cardIndices'] ?? []);
  }

  /// Returns a list of strings explaining what the KBS decided and why
  List<String> getExplanationLog() {
    final log = <String>[];

    if (_latestRecommendation != null) {
      log.add('🤖 Decision: ${_latestRecommendation!['action'].toUpperCase()}');
      log.add('💭 Reason: ${_latestRecommendation!['reason']}');

      if (_latestRecommendation!['detectedCombos'] != null) {
        final combos =
            _latestRecommendation!['detectedCombos'] as List<ComboResult>;
        if (combos.isNotEmpty) {
          log.add('🃏 Detected Combos:');
          for (var combo in combos.take(3)) {
            log.add('• ${combo.name} (${combo.score} pts)');
          }
        }
      }

      if (_latestRecommendation!['firedRules'] != null) {
        final rules = _latestRecommendation!['firedRules'] as List<String>;
        log.add('🔥 Rules Fired:');
        for (var rule in rules) {
          log.add('• $rule');
        }
      }
    } else {
      log.add('No reasoning available yet.');
    }

    return log;
  }
}
