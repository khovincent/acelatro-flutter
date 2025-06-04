// lib/core/kbs/rules/rule_registry.dart
import 'rule_base.dart'; // Assuming adjusted name
import '../../kbs/frames/game_state_frame.dart';
import '../../../features/combo_detection/kbs/combo_rules.dart';
import '../../../features/strategy/kbs/strategy_rules.dart';
import '../../../features/decision/kbs/decision_rules.dart';
import '../../../features/selection/kbs/selection_rules.dart';

/// A central, singleton registry for all rules in the KBS.
class RuleRegistry {
  // Singleton pattern setup
  RuleRegistry._internal();
  static final RuleRegistry _instance = RuleRegistry._internal();
  static RuleRegistry get instance => _instance;

  // Store rules, categorized by their inference phase for efficient retrieval.
  final Map<InferencePhase, List<Rule>> _rulesByPhase = {};

  /// Registers a single rule.
  void registerRule(Rule rule) {
    _rulesByPhase.putIfAbsent(rule.phase, () => []).add(rule);
    // Keep the list sorted by priority immediately upon insertion
    // This pre-sorting can simplify the inference engine slightly.
    _rulesByPhase[rule.phase]!.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Registers multiple rules.
  void registerRules(List<Rule> rules) {
    for (final rule in rules) {
      registerRule(rule);
    }
  }

  /// Retrieves all rules registered for a specific phase, usually sorted by priority.
  List<Rule> getRulesForPhase(InferencePhase phase) {
    // Return a copy to prevent external modification of the registry's list
    return List.from(_rulesByPhase[phase] ?? []);
  }

  /// Retrieves all registered rules across all phases.
  List<Rule> getAllRules() {
    // Flatten the map values into a single list
    return _rulesByPhase.values.expand((ruleList) => ruleList).toList();
  }

  /// Clears all registered rules. Useful for re-initialization or testing.
  void clearAllRules() {
    _rulesByPhase.clear();
  }

  /// Initializes the registry with all the application's rules.
  /// This is where rules from different features will be added.
  /// (We will populate this method later when we define the actual rules).
  void initialize() {
    clearAllRules();
    print("RuleRegistry: Initializing...");

    // --- Rule Registration Sections ---

    // Register Combo Detection Rules (Phase: detection)
    final comboRules = ComboDetectionRules.getRules();
    registerRules(comboRules);
    print(
      "RuleRegistry: Registered ${comboRules.length} combo detection rules.",
    );

    // Register Strategy Rules (Phase: strategy)
    final strategyRules = StrategyRules.getRules();
    registerRules(strategyRules);
    print("RuleRegistry: Registered ${strategyRules.length} strategy rules.");

    // Register Decision Rules (Phase: decision)
    final decisionRules = DecisionRules.getRules();
    registerRules(decisionRules);
    print("RuleRegistry: Registered ${decisionRules.length} decision rules.");

    // Register Selection Rules (Phase: selection)
    final selectionRules = CardSelectionRules.getRules();
    registerRules(selectionRules);
    print("RuleRegistry: Registered ${selectionRules.length} selection rules.");

    print(
      "RuleRegistry: Initialization complete. Total rules: ${getAllRules().length}",
    );
    _printRuleSummary(); // Optional: Print summary after init
    // Perform validation after all rules are registered
    validateDependencies();
  }

  /// Optional: Normalizes priorities globally or within phases if needed.
  /// (Implementation can be added if complex priority management is required)
  void normalizePriorities() {
    // Example: Could scale priorities within each phase to a specific range
    print(
      "RuleRegistry: Normalizing priorities (Placeholder - Not implemented)",
    );
  }

  /// Optional: Validates rule dependencies (e.g., reads match writes).
  /// Returns a list of error messages.
  List<String> validateDependencies() {
    print("RuleRegistry: Validating dependencies (Placeholder - Basic check)");
    final errors = <String>[];
    final allWrittenOrInitializedSlots = <SlotName>{};
    final allRules = getAllRules();

    // Pass 1: Collect all slots written by any rule
    for (final rule in allRules) {
      allWrittenOrInitializedSlots.addAll(rule.writes);
    }

    // Pass 2: Add ALL slots initialized directly in GameStateFrame constructor
    // Using the constants defined in GameStateFrame for accuracy
    allWrittenOrInitializedSlots.addAll([
      GameStateFrame.roundNumber,
      GameStateFrame.currentPoints,
      GameStateFrame.requiredPoints,
      GameStateFrame.pointsGap,
      GameStateFrame.remainingHands,
      GameStateFrame.remainingDiscards,
      GameStateFrame.initialHands,
      GameStateFrame.initialDiscards,
      GameStateFrame.maxHandSize,
      GameStateFrame.deckSize,
      GameStateFrame.handSize,
      GameStateFrame.playedCount,
      GameStateFrame.discardedCount,
      GameStateFrame.movesLeft,
      GameStateFrame.handCards,
      GameStateFrame.deckCards,
      GameStateFrame.notification,
      GameStateFrame.detectedCombos,
      GameStateFrame.potentialCombos,
      GameStateFrame.strategicAdvice,
      GameStateFrame.currentDecision,
      GameStateFrame.recommendedIndices,
      GameStateFrame.discardCandidatesEval,
    ]);

    // Pass 3: Check reads against the combined set
    for (final rule in allRules) {
      for (final slotName in rule.reads) {
        if (!allWrittenOrInitializedSlots.contains(slotName)) {
          errors.add(
            'Rule "${rule.name}" (Phase: ${rule.phase}) reads from slot "$slotName", which is not found in any rule\'s `writes` set or initial GameStateFrame slots.',
          );
        }
      }
    }
    if (errors.isEmpty) {
      print("RuleRegistry: Dependency validation passed.");
    } else {
      print(
        "RuleRegistry: Dependency validation found ${errors.length} potential issues:",
      );
      errors.forEach(print);
    }
    return errors;
  }

  Rule? findRuleByName(String name) {
    try {
      // firstWhere throws StateError if no element is found without orElse
      return getAllRules().firstWhere((rule) => rule.name == name);
    } on StateError {
      // Catch the error when no rule is found and return null explicitly
      return null;
    }

    /* // Alternative using orElse with explicit typing (should also work)
    return getAllRules().firstWhere(
      (rule) => rule.name == name,
      orElse: () => null as Rule?, // Explicitly cast null to Rule?
    );
    */
  }

  // --- Helper for Debugging ---
  void _printRuleSummary() {
    print("--- Rule Registry Summary ---");
    if (_rulesByPhase.isEmpty) {
      print("  No rules registered.");
      return;
    }
    _rulesByPhase.forEach((phase, rules) {
      print("  Phase: $phase (${rules.length} rules)");
      // rules.sort((a,b) => b.priority.compareTo(a.priority)); // Ensure sorted for print
      // for(final rule in rules) {
      //   print("    - ${rule.name} (Prio: ${rule.priority})");
      // }
    });
    print("---------------------------");
  }
}
