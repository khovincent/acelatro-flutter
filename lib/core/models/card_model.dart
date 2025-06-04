// lib/core/models/card_model.dart
import 'package:flutter/material.dart'; // For Color, optional but convenient

class CardModel {
  final String suit; // 'Spades', 'Hearts', 'Diamonds', 'Clubs'
  final int value; // 2-10, Jack=11, Queen=12, King=13, Ace=14

  // Static data for easy lookup
  static const Map<String, String> suitSymbols = {
    'Spades': '♠',
    'Hearts': '♥',
    'Diamonds': '♦',
    'Clubs': '♣',
  };

  static const Map<String, Color> suitColors = {
    'Spades': Colors.black,
    'Hearts': Colors.red,
    'Diamonds': Colors.red,
    'Clubs': Colors.black,
  };

  static const Map<int, String> valueNames = {
    2: '2',
    3: '3',
    4: '4',
    5: '5',
    6: '6',
    7: '7',
    8: '8',
    9: '9',
    10: '10',
    11: 'Jack',
    12: 'Queen',
    13: 'King',
    14: 'Ace',
  };

  static const Map<String, int> nameToValue = {
    '2': 2,
    '3': 3,
    '4': 4,
    '5': 5,
    '6': 6,
    '7': 7,
    '8': 8,
    '9': 9,
    'T': 10, // Ten (short code)
    '10': 10, // Ten (full code)
    'J': 11, // Jack
    'Q': 12, // Queen
    'K': 13, // King
    'A': 14, // Ace
  };

  CardModel({required this.suit, required this.value}) {
    // print("Creating Card: Value=$value, Suit=$suit"); // Optional: for debugging
    assert(suitSymbols.containsKey(suit), 'Invalid suit: $suit');
    assert(value >= 2 && value <= 14, 'Invalid value: $value');
  }

  // --- Computed Properties ---

  String get shortName {
    String valueStr;
    if (value >= 2 && value <= 9) {
      valueStr = value.toString();
    } else if (value == 10) {
      valueStr = 'T'; // Use 'T' for Ten for consistency in short names
    } else {
      valueStr = valueNames[value]![0]; // J, Q, K, A (first letter)
    }
    // Note: suitSymbols[suit]! is safe due to the assertion in the constructor.
    return '$valueStr${suitSymbols[suit]!}';
  }

  /// Returns the string representation for the corner rank display.
  String get cornerRankDisplay {
    if (value == 10) return '10'; // Use '10' specifically for 10
    if (value >= 2 && value <= 9) {
      return value.toString(); // Use '2' through '9'
    }
    // For J, Q, K, A use the first letter
    // Note: valueNames[value]! is safe due to the assertion in the constructor.
    return valueNames[value]![0];
  }

  String get longName => '${valueNames[value]} of $suit';

  // Note: suitColors[suit]! is safe due to the assertion in the constructor.
  Color get displayColor => suitColors[suit]!;

  // Balatro specific chip value calculation
  int get chipValue {
    if (value == 14) return 11; // Ace
    if (value >= 11 && value <= 13) return 10; // Face cards (J, Q, K)
    return value; // Number cards (2-10)
  }

  bool get isFaceCard => value >= 11 && value <= 13;
  bool get isAce => value == 14;

  /// Number of suit symbols to display in the central area of the card.
  /// For number cards (2-10), this is the card's value.
  /// For Ace and Face cards, this is typically 1 (representing a single large symbol or a picture).
  int get centralDisplaySymbolCount {
    print("[CardModel DEBUG] Card: ${this.shortName}, Value: $value, Returning count: ${value >= 2 && value <= 10 ? value : 1}");
    if (value >= 2 && value <= 10) {
      return value; // e.g., a 7 will show 7 symbols
    } else {
      // Ace, Jack, Queen, King
      return 1; // Typically show one large symbol or a picture
    }
  }

  /// Returns the suit symbol character (e.g., '♥', '♠').
  String get suitSymbolCharacter => suitSymbols[suit]!;


  // --- Factory Constructor for Parsing ---

  static CardModel? fromCode(String code) {
    code = code.trim().toUpperCase();
    if (code.length < 2) return null;

    final Map<String, String> codeToSuit = {
      'S': 'Spades',
      'H': 'Hearts',
      'D': 'Diamonds',
      'C': 'Clubs',
    };

    // Suit is usually the last character, e.g., "10S", "KH", "AC"
    // Value can be one or two characters, e.g., "2", "9", "10", "T", "J", "Q", "K", "A"
    String suitChar = code.substring(code.length - 1);
    String valuePart = code.substring(0, code.length - 1);

    String? suit = codeToSuit[suitChar];
    if (suit == null) {
      // Try alternative if suit might be first char (less common for parsing "AS" vs "SA")
      // This part depends on expected code format. Standard is RankSuit (e.g., AS, KH, TD, 2C).
      // If format can be SuitRank (e.g. SA, HK, DT, C2), then more logic is needed.
      // Assuming RankSuit format (e.g. "AS", "TD").
      return null;
    }

    int? value = nameToValue[valuePart];
    if (value == null) return null; // Handles invalid values implicitly

    return CardModel(suit: suit, value: value);
  }

  // --- Equality and HashCode ---
  // Important for using Cards in Sets or as Map keys

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardModel &&
          runtimeType == other.runtimeType &&
          suit == other.suit &&
          value == other.value;

  @override
  int get hashCode => suit.hashCode ^ value.hashCode;

  @override
  String toString() => shortName; // Convenient for debugging
}