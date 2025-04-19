class CardModel {
  final String suit;
  final int value;

  static const suitSymbols = {
    'Spades': '♠',
    'Hearts': '♥',
    'Diamonds': '♦',
    'Clubs': '♣'
  };

  static const suitColors = {
    'Spades': 'black',
    'Hearts': 'red',
    'Diamonds': 'red',
    'Clubs': 'black'
  };

  static const values = {
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
    14: 'Ace'
  };

  CardModel(this.suit, this.value);

  String get shortName {
    var valueStr = values[value]!;
    var shortVal = valueStr == '10' ? '10' : valueStr[0];
    return '$shortVal${suitSymbols[suit]}';
  }

  String get color => suitColors[suit]!;

  int get chipValue {
    if (value == 14) return 11;
    if (value >= 11 && value <= 13) return 10;
    return value;
  }

  static CardModel? fromCode(String code) {
    code = code.trim().toUpperCase();
    if (code.length < 2) return null;

    final suitMap = {
      'S': 'Spades',
      'H': 'Hearts',
      'D': 'Diamonds',
      'C': 'Clubs'
    };
    final valueMap = {'J': 11, 'Q': 12, 'K': 13, 'A': 14};

    String suitLetter = code.substring(code.length - 1);
    String valuePart = code.substring(0, code.length - 1);

    String? suit = suitMap[suitLetter];
    if (suit == null) return null;

    int? value = int.tryParse(valuePart) ?? valueMap[valuePart];
    if (value == null || value < 2 || value > 14) return null;

    return CardModel(suit, value);
  }
}
