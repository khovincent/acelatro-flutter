import 'card_model.dart';

/// Hasil satu deteksi kombo
class ComboResult {
  final String name;
  final List<CardModel> cards;
  final int score;
  ComboResult(this.name, this.cards, this.score);
}

/// Definisi satu jenis kombo
typedef ComboCheck = bool Function(List<CardModel> cards);

class ComboDefinition {
  final String name;
  final int cardCount;
  final ComboCheck check;
  final int base;
  final int multiplier;

  ComboDefinition({
    required this.name,
    required this.cardCount,
    required this.check,
    required this.base,
    required this.multiplier,
  });
}

/// Helper: generate semua kombinasi k elemen dari list
Iterable<List<T>> combinations<T>(List<T> list, int k) sync* {
  if (k == 0) {
    yield <T>[];
  } else if (list.length >= k) {
    for (int i = 0; i <= list.length - k; i++) {
      var head = list[i];
      for (var tail in combinations(list.sublist(i + 1), k - 1)) {
        yield [head, ...tail];
      }
    }
  }
}

/// Fungsi-fungsi checker
bool isFlush(List<CardModel> cards) =>
    cards.every((c) => c.suit == cards.first.suit);

bool isStraight(List<CardModel> cards) {
  var vals = cards.map((c) => c.value).toList()..sort();
  for (int i = 1; i < vals.length; i++) {
    if (vals[i] != vals[i - 1] + 1) return false;
  }
  return true;
}

bool isRoyalFlush(List<CardModel> cards) =>
    cards.length == 5 &&
    isFlush(cards) &&
    isStraight(cards) &&
    Set.from(cards.map((c) => c.value)).containsAll([10, 11, 12, 13, 14]);

bool isStraightFlush(List<CardModel> cards) =>
    cards.length == 5 && isFlush(cards) && isStraight(cards);

bool isFourOfAKind(List<CardModel> cards) {
  var counts = <int, int>{};
  for (var c in cards) counts[c.value] = (counts[c.value] ?? 0) + 1;
  return counts.values.any((cnt) => cnt == 4);
}

bool isFullHouse(List<CardModel> cards) {
  var counts = <int, int>{};
  for (var c in cards) counts[c.value] = (counts[c.value] ?? 0) + 1;
  var vals = counts.values.toList()..sort();
  return vals.length == 2 && vals[0] == 2 && vals[1] == 3;
}

bool isThreeOfAKind(List<CardModel> cards) => cards
    .map((c) => c.value)
    .toList()
    .fold<Map<int, int>>({}, (m, v) {
      m[v] = (m[v] ?? 0) + 1;
      return m;
    })
    .values
    .any((cnt) => cnt == 3);

bool isTwoPair(List<CardModel> cards) {
  var counts = <int, int>{};
  for (var c in cards) counts[c.value] = (counts[c.value] ?? 0) + 1;
  return counts.values.where((cnt) => cnt >= 2).length >= 2;
}

bool isPair(List<CardModel> cards) =>
    cards.length == 2 && cards[0].value == cards[1].value;

/// Daftar semua combo berdasarkan urutan prioritas
final List<ComboDefinition> comboDefinitions = [
  ComboDefinition(
      name: 'Royal Flush',
      cardCount: 5,
      check: isRoyalFlush,
      base: 100,
      multiplier: 8),
  ComboDefinition(
      name: 'Straight Flush',
      cardCount: 5,
      check: isStraightFlush,
      base: 100,
      multiplier: 8),
  ComboDefinition(
      name: 'Four of a Kind',
      cardCount: 4,
      check: isFourOfAKind,
      base: 60,
      multiplier: 7),
  ComboDefinition(
      name: 'Full House',
      cardCount: 5,
      check: isFullHouse,
      base: 40,
      multiplier: 4),
  ComboDefinition(
      name: 'Flush', cardCount: 5, check: isFlush, base: 35, multiplier: 4),
  ComboDefinition(
      name: 'Straight',
      cardCount: 5,
      check: isStraight,
      base: 30,
      multiplier: 4),
  ComboDefinition(
      name: 'Three of a Kind',
      cardCount: 3,
      check: isThreeOfAKind,
      base: 30,
      multiplier: 3),
  ComboDefinition(
      name: 'Two Pair',
      cardCount: 4,
      check: isTwoPair,
      base: 20,
      multiplier: 2),
  ComboDefinition(
      name: 'Pair', cardCount: 2, check: isPair, base: 10, multiplier: 2),
];
