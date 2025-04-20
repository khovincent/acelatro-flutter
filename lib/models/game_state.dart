import 'dart:math';
import 'card_model.dart';
import 'combo_definitions.dart';
import '../kbs/frame.dart';
import '../kbs/rule_base.dart';
import '../kbs/strategic_algorithms.dart';

enum GameMode { demo, live }

class GameState {
  GameMode mode = GameMode.demo;

  // **Frame**-based state
  List<CardModel> deck = [];
  List<CardModel> hand = [];
  List<CardModel> playedCards = [];
  List<CardModel> discardedCards = [];

  int currentPoints = 0;
  int requiredPoints = 300;
  int roundNumber = 0;
  final int maxHandSize = 8;
  String notification = '';
  int get movesSoFar => playedCards.length + discardedCards.length;

  // KBS specific properties
  final List<String> _kbsLog = [];
  Map<String, dynamic>? _latestRecommendation;

  GameState() {
    startRound();
  }

  /// Mulai ronde baru
  void startRound() {
    roundNumber++;
    currentPoints = 0;
    playedCards.clear();
    discardedCards.clear();
    hand.clear();
    _kbsLog.clear();
    _latestRecommendation = null;
    _initializeDeck();
    _dealInitialHand();

    // Initial KBS evaluation on round start
    runKbsEvaluation();
  }

  /// Inisialisasi dan shuffle deck
  void _initializeDeck() {
    deck = [];
    // generate 52 kartu
    for (var suit in CardModel.suitSymbols.keys) {
      for (var value in CardModel.values.keys) {
        deck.add(CardModel(suit, value));
      }
    }
    deck.shuffle(Random());
  }

  /// Bagi kartu awal sebanyak [maxHandSize]
  void _dealInitialHand() {
    for (int i = 0; i < maxHandSize; i++) {
      dealCard();
    }
  }

  /// Ambil 1 kartu dari deck ke tangan
  void dealCard() {
    if (deck.isNotEmpty) {
      hand.add(deck.removeLast());
    }
  }

  /// Run the knowledge-based system evaluation
  void runKbsEvaluation() {
    // Create frame for current game state
    final gameStateFrame = GameStateFrame(this);

    // Run rules engine
    final engine =
        InferenceEngine(BalatroRuleSet.getDefaultRules(), gameStateFrame);
    engine.forwardChain();

    // Log activations
    _kbsLog.addAll(engine.activationHistory);

    // Get strategic recommendation
    _latestRecommendation = getStrategyRecommendation();

    // Add recommendation to notification
    final action =
        _latestRecommendation!['action'] == 'play' ? 'Play' : 'Discard';
    final cards = _latestRecommendation!['cards'].join(', ');

    if (cards.isNotEmpty) {
      notification += '\n🤖 KBS Recommends: $action $cards';
      notification += '\n💭 Reasoning: ${_latestRecommendation!['reason']}';
    }
  }

  List<ComboResult> analyzeHand() {
    var results = <ComboResult>[];

    // Cek tiap definisi combo
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

    // Tambahkan High Card sebagai fallback
    if (hand.isNotEmpty) {
      var maxCard = hand.reduce((a, b) => a.value > b.value ? a : b);
      var score = (5 + maxCard.chipValue) * 1;
      results.add(ComboResult('High Card', [maxCard], score));
    }

    // Hilangkan duplikat (berdasarkan set nilai & nama), kemudian sort
    var seen = <String>{};
    var unique = <ComboResult>[];
    for (var r in results) {
      var key = '${r.name}-${r.cards.map((c) => c.value).join(",")}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(r);
      }
    }
    unique.sort((a, b) {
      var cmp = b.score.compareTo(a.score);
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });

    return unique;
  }

  ComboResult identifyCombo(List<CardModel> selected) {
    for (var def in comboDefinitions) {
      if (selected.length >= def.cardCount &&
          def.check(selected.sublist(0, def.cardCount))) {
        var chipSum = selected.fold<int>(0, (sum, c) => sum + c.chipValue);
        var score = (def.base + chipSum) * def.multiplier;
        return ComboResult(def.name, selected, score);
      }
    }
    // Jika tidak match, kembalikan High Card:
    var mc = selected.reduce((a, b) => a.value > b.value ? a : b);
    return ComboResult('High Card', [mc], (5 + mc.chipValue) * 1);
  }

  /// Identifikasi & mainkan combo, update points & notification
  ComboResult playCombo(List<int> indices) {
    if (indices.isEmpty) {
      notification = 'No cards selected to play!';
      return ComboResult('None', [], 0);
    }
    var selectedCards = indices.map((i) => hand[i]).toList();
    var combo = identifyCombo(selectedCards);

    indices.toSet().toList()
      ..sort((a, b) => b.compareTo(a))
      ..forEach(hand.removeAt);
    playedCards.addAll(selectedCards);

    while (hand.length < maxHandSize) {
      dealCard();
    }

    currentPoints += combo.score;
    notification = 'Played ${combo.name} and earned ${combo.score} points!';

    // Run KBS after move
    runKbsEvaluation();

    return combo;
  }

  /// Buang kartu, tanpa scoring
  void discard(List<int> indices) {
    if (indices.isEmpty) {
      notification = 'No cards selected to discard!';
      return;
    }
    if (indices.length >= hand.length) {
      notification = 'Cannot discard all cards—must keep at least one.';
      return;
    }

    var selectedCards = indices.map((i) => hand[i]).toList();
    indices.toSet().toList()
      ..sort((a, b) => b.compareTo(a))
      ..forEach(hand.removeAt);
    discardedCards.addAll(selectedCards);

    while (hand.length < maxHandSize) {
      dealCard();
    }

    notification = 'Discarded ${selectedCards.length} cards.';

    // Run KBS after move
    runKbsEvaluation();
  }

  void sortHandByRank() {
    hand.sort((a, b) => a.value.compareTo(b.value));
    notification = 'Hand sorted by rank.';
  }

  void sortHandBySuit() {
    hand.sort((a, b) {
      int suitOrder(String suit) {
        switch (suit) {
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

      int suitCompare = suitOrder(a.suit).compareTo(suitOrder(b.suit));
      return suitCompare != 0 ? suitCompare : a.value.compareTo(b.value);
    });
    notification = 'Hand sorted by suit.';
  }

  void addCardToHand(CardModel card) {
    if (hand.length < maxHandSize) {
      hand.add(card);
      notification = 'Card ${card.shortName} added to hand.';
      // Run KBS after adding card
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

  /// Get KBS log for debugging
  List<String> get kbsLog => List.unmodifiable(_kbsLog);

  /// Get latest recommendation
  Map<String, dynamic>? get latestRecommendation => _latestRecommendation;

  /// Convenience method to automatically select recommended cards
  List<int> selectRecommendedCards() {
    if (_latestRecommendation != null &&
        _latestRecommendation!['cardIndices'].isNotEmpty) {
      return List<int>.from(_latestRecommendation!['cardIndices']);
    }
    return [];
  }
}
