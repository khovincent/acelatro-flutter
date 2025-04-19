import 'frame.dart';

class Rule {
  final String name;
  final bool Function(Frame wm) condition;
  final void Function(Frame wm) action;
  bool fired = false;

  Rule({
    required this.name,
    required this.condition,
    required this.action,
  });
}

class InferenceEngine {
  final List<Rule> rules;
  final Frame wm;

  InferenceEngine(this.rules, this.wm);

  void forwardChain() {
    bool anyFired;
    do {
      anyFired = false;
      for (var rule in rules) {
        if (!rule.fired && rule.condition(wm)) {
          rule.action(wm);
          rule.fired = true;
          anyFired = true;
        }
      }
    } while (anyFired);
  }
}
