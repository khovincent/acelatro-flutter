// lib/core/utils/combinations_util.dart

/// Generates all combinations of size k from the given list.
Iterable<List<T>> combinations<T>(List<T> list, int k) sync* {
  if (k < 0 || k > list.length) {
    return;
  }
  if (k == 0) {
    yield <T>[];
    return;
  }
  if (k == list.length) {
    yield List<T>.from(list);
    return;
  }
  if (k == 1) {
    for (final item in list) {
      yield [item];
    }
    return;
  }

  // Standard recursive approach
  // Need a temporary list inside to avoid issues with modifying during iteration if sync* state is complex
  List<T> currentCombination = List<T>.filled(
    k,
    list.isNotEmpty ? list[0] : null as T,
    growable: false,
  ); // Placeholder, ensure list isn't empty for default value

  if (list.isNotEmpty) {
    // Guard against empty list for initial value
    yield* _combinationsRecursive(list, k, 0, 0, currentCombination);
  } else if (k == 0) {
    // Special case: combination of 0 from empty list is one empty list
    yield <T>[];
  }
  // Otherwise, combinations(emptyList, k>0) yields nothing.
}

Iterable<List<T>> _combinationsRecursive<T>(
  List<T> list,
  int k,
  int start, // Starting index in the original list
  int index, // Current index in the combination being built
  List<T> currentCombination,
) sync* {
  if (index == k) {
    yield List<T>.from(currentCombination); // Found a combination, yield a copy
    return;
  }

  // Check bounds carefully: i must not exceed list.length - remaining needed elements
  final remainingElementsNeeded = k - index;
  final iterationLimit = list.length - remainingElementsNeeded;

  // Iterate through possible elements to add at the current index
  for (int i = start; i <= iterationLimit; i++) {
    // Corrected loop limit
    currentCombination[index] = list[i];
    yield* _combinationsRecursive(
      list,
      k,
      i + 1,
      index + 1,
      currentCombination,
    );
  }
}

// Helper extension for checking if a list contains all elements from another list (useful for straight checks)
extension ListContainsAll<T> on List<T> {
  bool containsAll(Iterable<T> elements) {
    final selfSet = toSet(); // Optimize lookup
    for (final element in elements) {
      if (!selfSet.contains(element)) {
        return false;
      }
    }
    return true;
  }
}
