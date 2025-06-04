// lib/core/kbs/inference_engine.dart
// ignore: unused_import
import 'dart:collection'; // For Queue

import '../kbs/frames/frame.dart'; // Assuming adjusted name
import '../kbs/rules/rule_base.dart'; // Assuming adjusted name
import '../kbs/rules/rule_registry.dart'; // Assuming adjusted name

/// Performs forward-chaining inference using a RuleRegistry and a Working Memory Frame.
class InferenceEngine {
  final RuleRegistry ruleRegistry;
  final Frame workingMemory; // The main WM frame (e.g., GameStateFrame)
  final ConflictResolver conflictResolver;
  final List<String> _activationHistory = []; // Log of fired rules
  final Set<Rule> _firedRulesThisCycle =
      {}; // Track rules fired across all phases in one run

  InferenceEngine({
    required this.ruleRegistry,
    required this.workingMemory,
    ConflictResolver? resolver, // Allow injecting a custom resolver
  }) : conflictResolver = resolver ?? DefaultConflictResolver();

  /// Runs the inference process through all defined phases sequentially.
  void run() {
    _activationHistory.clear();
    _firedRulesThisCycle.clear();
    print("InferenceEngine: Starting run...");

    // Iterate through phases in their defined order
    for (final phase in InferencePhase.values) {
      _forwardChainPhase(phase);
    }

    print(
      "InferenceEngine: Run complete. Fired rules: ${_firedRulesThisCycle.length}",
    );
  }

  /// Executes the forward-chaining cycle for a single inference phase.
  void _forwardChainPhase(InferencePhase phase) {
    print("InferenceEngine: Entering phase $phase");
    final rulesForPhase = ruleRegistry.getRulesForPhase(phase);
    if (rulesForPhase.isEmpty) {
      print("InferenceEngine: No rules registered for phase $phase.");
      return;
    }

    // Reset 'fired' status for rules *within this phase* for this specific phase execution.
    // Note: _firedRulesThisCycle tracks across the entire run()
    for (final rule in rulesForPhase) {
      rule.fired = false;
    }

    bool ruleFiredInIteration;
    do {
      ruleFiredInIteration = false;
      // 1. Match: Find all applicable rules in this phase that haven't fired yet
      final applicableRules =
          rulesForPhase.where((rule) {
            // Check if already fired in the *entire* cycle OR specifically in this phase iteration
            // AND check the condition against the current WM state
            if (_firedRulesThisCycle.contains(rule) || rule.fired) {
              return false;
            }
            try {
              return rule.condition(workingMemory);
            } catch (e, stackTrace) {
              print("ERROR evaluating condition for rule '${rule.name}': $e");
              print(stackTrace);
              return false; // Treat as not applicable if condition fails
            }
          }).toList();

      if (applicableRules.isNotEmpty) {
        // 2. Conflict Resolution: Select the best rule to fire
        final ruleToFire = conflictResolver.selectRule(
          applicableRules,
          workingMemory,
        );

        // 3. Act: Execute the rule's action
        try {
          print(
            "InferenceEngine: Firing rule [${phase.name}] '${ruleToFire.name}' (Prio: ${ruleToFire.priority})",
          );
          ruleToFire.action(workingMemory);
          ruleToFire.fired = true; // Mark as fired for this phase's loop
          _firedRulesThisCycle.add(
            ruleToFire,
          ); // Mark as fired for the entire run() cycle
          _activationHistory.add("[${phase.name}] Fired: ${ruleToFire.name}");
          ruleFiredInIteration =
              true; // Indicate that the WM changed, loop again
        } catch (e, stackTrace) {
          print("ERROR executing action for rule '${ruleToFire.name}': $e");
          print(stackTrace);
          // Decide how to handle action errors: stop phase, stop engine, or just log?
          // For now, just log and prevent it from being marked fired to avoid infinite loops if action fails before state change
          ruleToFire.fired =
              true; // Mark fired even on error to avoid re-selection if condition still true
          _firedRulesThisCycle.add(
            ruleToFire,
          ); // Ensure it's not picked again in this run
        }
      }
    } while (ruleFiredInIteration); // Loop as long as rules are firing in this phase

    print("InferenceEngine: Exiting phase $phase");
  }

  /// Returns the history of rule activations for the last run.
  List<String> get activationHistory => List.unmodifiable(_activationHistory);
}
