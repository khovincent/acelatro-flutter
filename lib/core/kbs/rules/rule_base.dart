// lib/core/kbs/rules/rule_base.dart
import '../frames/frame.dart'; // Depends on the Frame definition

/// Defines the distinct phases of the KBS inference process.
/// Rules are typically grouped and fired based on these phases.
enum InferencePhase {
  // Initial data extraction, observation, basic facts
  detection,
  // Analyzing the situation, assessing risk, identifying strategic goals
  strategy,
  // Making high-level decisions (e.g., play vs. discard)
  decision,
  // Selecting specific items based on the decision (e.g., which cards)
  selection,
  // Optional: Final actions, cleanup, generating explanations
  // action,
}

/// Type alias for a slot name (key in the Frame's slots map).
typedef SlotName = String;

/// Type alias for a Rule's condition function.
/// Takes the Working Memory (typically the main GameStateFrame) and returns true if the rule applies.
typedef Condition = bool Function(Frame wm);

/// Type alias for a Rule's action function.
/// Takes the Working Memory and performs actions, usually modifying the WM's slots.
typedef Action = void Function(Frame wm);

/// Represents a single Production Rule (IF condition THEN action).
class Rule {
  final String name;
  final String description;
  final InferencePhase phase; // Which phase this rule belongs to

  /// Priority used for conflict resolution (higher value means higher priority).
  /// Mutable to allow for potential dynamic adjustments (e.g., normalization).
  int priority;

  /// Set of slot names this rule is expected to read from. Aids understanding and validation.
  final Set<SlotName> reads;

  /// Set of slot names this rule might write to. Aids understanding and validation.
  final Set<SlotName> writes;

  /// Tags for categorization, filtering, or explanation purposes.
  final List<String> tags;

  /// The IF part of the rule.
  final Condition condition;

  /// The THEN part of the rule.
  final Action action;

  /// Internal state for the inference engine: has this rule fired in the current cycle for its phase?
  bool fired = false;

  /// Optional metadata for extensions or debugging.
  Map<String, dynamic>? metadata;

  Rule({
    required this.name,
    required this.description,
    required this.phase,
    this.priority = 1, // Default priority
    this.reads = const <SlotName>{},
    this.writes = const <SlotName>{},
    this.tags = const <String>[],
    required this.condition,
    required this.action,
    this.metadata,
  });

  @override
  String toString() => 'Rule($name, phase: $phase, priority: $priority)';
}

/// Abstract interface for Conflict Resolution strategies.
/// Determines which rule to fire when multiple rules are applicable.
abstract class ConflictResolver {
  /// Selects the single best rule to fire from a list of applicable candidates.
  Rule selectRule(List<Rule> candidates, Frame wm);
}

/// A common conflict resolution strategy:
/// 1. Highest priority wins.
/// 2. If priorities are equal, rule writing to more slots wins (potentially more specific).
/// 3. If still tied, the first one encountered (based on initial list order) wins.
class DefaultConflictResolver implements ConflictResolver {
  @override
  Rule selectRule(List<Rule> candidates, Frame wm) {
    if (candidates.isEmpty) {
      throw ArgumentError('Cannot select rule from empty candidate list.');
    }
    if (candidates.length == 1) {
      return candidates.first;
    }

    candidates.sort((a, b) {
      // Primary sort: Higher priority first
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      // Secondary sort: More writes first (rule specificity heuristic)
      final writesCompare = b.writes.length.compareTo(a.writes.length);
      if (writesCompare != 0) {
        return writesCompare;
      }
      // Tertiary sort: Rule name (for deterministic tie-breaking)
      return a.name.compareTo(b.name);
    });

    return candidates.first;
  }
}
