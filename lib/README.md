# Balatro KBS Assistant

A Flutter application demonstrating a Knowledge-Based System (KBS) approach to providing recommendations (Play/Discard) for a Balatro-style poker game.

## Project Goal

To build an assistant that analyzes a player's hand and the game state, leveraging KBS principles (Frames, Rule Base, Inference Engine) to suggest optimal moves. The application supports both a simulated "Demo Mode" and an interactive "Live Mode" designed to sync with an actual Balatro game session.

## Core Architecture

This project follows a classic Knowledge-Based System architecture:

1. **Knowledge Base:** Contains the information the system uses.
   - **Fact Base (Working Memory):** Represents the current state of the world (the game). Implemented using **Frames**. The primary frame is `GameStateFrame`.
   - **Rule Base:** Contains the domain knowledge and heuristics in the form of IF-THEN rules. Implemented using `Rule` objects, organized by phase and managed by the `RuleRegistry`.
2. **Inference Engine:** The "brain" of the system. It applies the rules from the Rule Base to the facts in the Working Memory to deduce new information or decide on actions. This project uses a **Forward-Chaining** engine (`InferenceEngine`).
3. **User Interface (UI):** Provides interaction for the user (inputting hands, viewing recommendations, triggering actions) and displays the game state. Built with Flutter and uses the Provider package for state management.
4. **Domain Models:** Standard Dart classes representing game entities like `CardModel`, `ComboDefinition`, and the overall `GameState`.

```
+-------------------+  +---------------------+  +--------------------+
| User Interface    |<-→| GameState          |<-→| Knowledge-Based   |
| (Flutter)         |  | (Provider Notifier) |  | System (KBS)       |
+-------------------+  +----------+----------+  +---------+----------+
                                  |                       |
                                  |              +-----------------+
                      Creates/Reads|              | Inference Engine|
                                  |              +--------+--------+
                                  v                       | Uses
                    +----------------------+              v
                    | Working Memory      | Uses Rules  +-----------------+
                    | (GameStateFrame)    |<-----------| Rule Base       |
                    +----------------------+   From     | (RuleRegistry) |
                                                        +-----------------+
```

## Key Components & Concepts

### 1. Knowledge Representation

#### a) Frames (`lib/core/kbs/frames/`)

- **Concept:** Frames provide a structured way to represent knowledge chunks in the Working Memory (WM). Each frame has a `frameType` and a `slots` map (`Map<String, dynamic>`).
- **`frame.dart`:** Defines the abstract `Frame` base class.
- **`game_state_frame.dart`:**
  - This is the **primary Working Memory representation**.
  - An instance of `GameStateFrame` is created by the `GameState` before running the KBS.
  - It holds a reference to the `GameState` but crucially maintains its **own mutable `slots` map**.
  - **Initialization:** When created, it copies relevant scalar values (points, counts, etc.) and immutable views of collections (hand, deck) from the current `GameState` into its `slots`. It also initializes slots that rules are expected to populate (e.g., `detectedCombos`, `currentDecision`) to default empty values.
  - **`slots`:** This `Map<String, dynamic>` is where the action happens.
    - Rules **read** current game facts from these slots (e.g., `pointsGap`, `handCards`).
    - Rules **write** deduced information or decisions back into these slots (e.g., adding `ComboResult`s to `detectedCombos`, setting the `currentDecision` string, adding messages to `notification`).
  - **Constants:** Defines static `String` constants for standard slot names (e.g., `GameStateFrame.handCards`, `GameStateFrame.currentDecision`) to improve code readability and prevent typos in rules.

#### b) Rule Base (`lib/core/kbs/rules/`)

- **Concept:** The collection of IF-THEN rules that encapsulate the game logic, strategies, and heuristics.
- **`rule_base.dart`:**
  - **`InferencePhase` (Enum):** Defines distinct stages of reasoning (`detection`, `strategy`, `decision`, `selection`). Rules belong to a specific phase.
  - **`Rule` (Class):** Represents a single production rule. Key attributes:
    - `name`, `description`: For identification and understanding.
    - `phase`: Determines when the rule can fire.
    - `priority`: Integer used by the `ConflictResolver` (higher value = higher priority).
    - `reads` (Set<String>): Declares which WM slots the rule's condition _might_ read. Aids understanding and validation.
    - `writes` (Set<String>): Declares which WM slots the rule's action _might_ modify. Aids understanding and validation.
    - `tags` (List<String>): For categorization (e.g., 'play', 'discard', 'combo').
    - `condition` (Function `bool Function(Frame wm)`): The IF part. Returns `true` if the rule is applicable based on the current WM state.
    - `action` (Function `void Function(Frame wm)`): The THEN part. Executes logic, usually modifying WM slots.
    - `fired` (bool): Internal flag used by the engine to prevent re-firing in the same cycle.
  - **`ConflictResolver` (Abstract Class):** Interface for strategies to select one rule when multiple are applicable.
  - **`DefaultConflictResolver`:** Implements a strategy based on priority, then number of writes (specificity heuristic).
- **`rule_registry.dart`:**

  - **Singleton:** Provides a single, global access point (`RuleRegistry.instance`) to all rules.
  - **Organization:** Stores rules categorized by their `InferencePhase`.
  - **`initialize()`:** Called once (usually at app start via `GameState`) to load all rule definitions from different feature files. Uses `registerRule` or `registerRules`.
  - **`getRulesForPhase()`:** Retrieves rules relevant to a specific phase for the `InferenceEngine`.
  - **`validateDependencies()`:** Performs a basic check to see if slots mentioned in rule `reads` are either initialized in `GameStateFrame` or written to by _some_ rule.

- **Feature Rule Files (`lib/features/.../kbs/`)**
  - Rules are organized into separate files based on their purpose and phase (e.g., `combo_rules.dart`, `strategy_rules.dart`, `decision_rules.dart`, `selection_rules.dart`).
  - Each file typically contains a class with a static `getRules()` method that returns a `List<Rule>`.
  - These lists are registered with the `RuleRegistry` during initialization.

### 2. Inference Engine (`lib/core/kbs/inference_engine.dart`)

- **Concept:** Drives the reasoning process using forward chaining.
- **Forward Chaining:** Starts with known facts (initial WM state) and applies rules iteratively. When a rule's condition is met, its action fires, potentially adding new facts or modifying existing ones in the WM, which might trigger other rules.
- **Phased Execution:**
  - The `run()` method iterates through the `InferencePhase` enum values in order.
  - For each phase, it calls `_forwardChainPhase()`.
- **Recognize-Act Cycle (within `_forwardChainPhase`):**
  1. **Match:** Retrieves rules for the current phase from the `RuleRegistry`. Finds all rules whose `condition` is true based on the current `workingMemory` state and haven't fired yet _in this entire `run()` cycle_.
  2. **Conflict Resolution:** If multiple rules match, uses the `ConflictResolver` (e.g., `DefaultConflictResolver`) to select the single best rule to fire based on priority etc.
  3. **Act:** Executes the `action` of the selected rule, modifying the `workingMemory`. Marks the rule as fired for this cycle. Logs the activation.
  4. **Loop:** Repeats the Match-Resolve-Act cycle within the phase until no more rules are applicable in that phase.
- **State:** Maintains an `_activationHistory` log.

### 3. Game State (`lib/core/models/game_state.dart`)

- **Role:** The central orchestrator and holder of the application's live state. Uses `ChangeNotifier` for UI updates via Provider.
- **Core State:** Manages `_hand`, `_deck`, `_playedCards`, `_discardedCards`, points, remaining actions, current `mode` (Demo/Live).
- **KBS Interaction:**
  - Calls `RuleRegistry.instance.initialize()` upon creation.
  - Calls `runKbsEvaluation()` whenever the game state changes significantly (e.g., after play, discard, manual hand set, round start).
  - **`runKbsEvaluation()`:**
    1. Creates a new `GameStateFrame` instance (snapshot of the current state).
    2. Creates an `InferenceEngine` with the registry and the frame.
    3. Calls `engine.run()` to execute all inference phases.
    4. Calls `_extractKbsResults()` to read the final values from the modified `GameStateFrame`'s slots (`currentDecision`, `recommendedIndices`, `detectedCombos`, `discardCandidatesEval`, `notification`).
    5. Stores the extracted results in `_latestRecommendation` (a `KbsRecommendation` object).
    6. Updates `_transientMessage`.
    7. Calls `notifyListeners()` to update the UI.
- **Live Mode Logic:**
  - `setHandManually()`: Updates `_hand` and initializes the internal `_deck` based on the input. Resets session state (played/discarded/counts).
  - `playCards()` / `discardCards()`: When in Live Mode, they update the hand/counts but set `_needsDrawInput = true` instead of drawing automatically.
  - `addDrawnCards()`: Called by the UI after getting drawn card input. Updates `_hand`, removes drawn cards from internal `_deck`, resets flags, and triggers `runKbsEvaluation`.
  - `resetDrawInputFlag()`: Handles cancellation of the draw input dialog.

### 4. UI (`lib/main.dart`, `lib/ui/widgets/`)

- Uses Flutter and the `provider` package.
- `HomePage` watches `GameState` for changes.
- Displays game info, hand cards, action buttons.
- Conditionally renders UI elements based on `GameState.mode`.
- Uses `LiveHandInput` widget for initial hand input in Live Mode.
- Uses `DrawInputDialog` (triggered by `GameState.needsDrawInput`) to get drawn cards from the user in Live Mode.
- Displays analysis and recommendations from `GameState.latestRecommendation` in various tabs.
- Calls `GameState` methods in response to user actions (button presses, dialog submissions).

## Execution Flow Summary

1. **Initialization:** `main` creates `GameState` via Provider. `GameState` constructor initializes `RuleRegistry`.
2. **Mode Start:**
   - **Demo:** `startNewRound` shuffles deck, deals hand, runs initial KBS.
   - **Live:** `_switchToMode` clears state, waits for `setHandManually`.
3. **User Action (e.g., Click Play in App):**
   - UI calls `gameState.playCards(selectedIndices)`.
4. **GameState Action (`playCards`):**
   - Updates internal state (`_hand`, `_playedCards`, `remainingHands`, etc.).
   - **If Demo Mode:** Calls `_drawCardsFromDeck()`, `notifyListeners()`, then `runKbsEvaluation()`.
   - **If Live Mode:** Sets `_needsDrawInput = true`, `_cardsNeeded`, clears recommendation, `notifyListeners()`.
5. **KBS Run (`runKbsEvaluation`):** (Triggered after action in Demo, or after draw input in Live)
   - Create `GameStateFrame` (Working Memory snapshot).
   - Create `InferenceEngine`.
   - `engine.run()`:
     - Phase `detection`: Rules populate `detectedCombos`.
     - Phase `strategy`: Rules populate `strategicAdvice`, `notification`.
     - Phase `decision`: Rules read previous slots, write `currentDecision`.
     - Phase `selection`: Rules read `currentDecision`, write `recommendedIndices`, `discardCandidatesEval`.
   - `_extractKbsResults`: Read final slots from frame, update `_latestRecommendation`.
   - `notifyListeners()` (at end of `runKbsEvaluation`).
6. **UI Update:** `HomePage` rebuilds via `context.watch`, displaying updated hand, stats, and `_latestRecommendation`.
7. **Live Mode Draw Prompt:**
   - If `gameState.needsDrawInput` is true, `_handleGameStateChanges` listener triggers `_showDrawInputDialog`.
   - User interacts with `DrawInputDialog`.
   - Dialog `onSubmit` calls `gameState.addDrawnCards(drawnCards)`.
8. **GameState Draw Handling (`addDrawnCards`):**
   - Updates `_hand`, internal `_deck`.
   - Resets `_needsDrawInput`.
   - `notifyListeners()`.
   - `runKbsEvaluation()` (triggers step 5 again for the new hand).

This cycle continues based on user interactions and the selected mode.

# KBS Knowledge Representation Examples

This document provides simplified examples of how knowledge (facts and rules) is represented within the Balatro KBS Assistant project.

## 1. Frame Representation (Working Memory)

Frames are used to structure the information held in the system's Working Memory (WM). The primary frame holds the overall game state.

### Example: `GameStateFrame` (Simplified)

This frame represents the current snapshot of the game state that the rules operate on.

**Purpose:** Holds current game facts and derived information for the inference engine.

**Structure:**

- **`frameType`**: `"GameState"`
- **`slots`** (Map of Key -> Value):
  - `roundNumber`: `1` (Example value)
  - `currentPoints`: `150`
  - `requiredPoints`: `300`
  - `pointsGap`: `150` (Calculated: `requiredPoints` - `currentPoints`)
  - `remainingHands`: `3`
  - `remainingDiscards`: `2`
  - `movesLeft`: `5` (Calculated: `initialHands` + `initialDiscards` - actions taken)
  - `handCards`: `[ Card(K♠), Card(K♥), Card(7♦), Card(8♣), Card(2♠), ... ]` (List of Card objects)
  - `deckCards`: `[ Card(A♣), Card(Q♦), ... ]` (List of remaining Card objects)
  - `notification`: `"Round 1 started."` (Accumulated messages)
  - --- _Slots Populated by Rules_ ---
  - `detectedCombos`: `[ ComboResult(Pair, [K♠, K♥], 40), ... ]` (List of detected combos, initially empty)
  - `strategicAdvice`: `"balance_risk_reward"` (String flag set by Strategy rules, initially null)
  - `currentDecision`: `"play:strong_combo_pair"` (String set by Decision rules, initially null)
  - `recommendedIndices`: `[0, 1]` (List of integers set by Selection rules, initially empty)
  - `discardCandidatesEval`: `[ { index: 2, keepScore: 0.15, ... }, ... ]` (Analysis data, initially empty)

_(**Note:** In the actual code, `Card` and `ComboResult` would be full objects, shown simplified here.)_

## 2. Rule Base Representation (IF-THEN Rules)

Rules encode the logic and strategy. They read from and write to the Working Memory (`GameStateFrame` slots).

### Example Rule 1: Combo Detection

- **Rule Name:** `Detect Pair`
- **Metadata:**
  - `Phase`: `detection`
  - `Priority`: 93 (Lower than Flush, Straight, etc.)
  - `Reads`: `handCards`
  - `Writes`: `detectedCombos`
- **IF:**
  - The `handCards` slot contains at least 2 cards.
  - AND There exists a combination of 2 cards within `handCards` that have the same rank (value).
- **THEN:**
  - For each identified Pair combination:
    - Calculate its score.
    - Create a `ComboResult` object for the Pair.
    - Add the `ComboResult` to the `detectedCombos` list in the Working Memory.

### Example Rule 2: Strategy Assessment

- **Rule Name:** `Identify Late Game`
- **Metadata:**
  - `Phase`: `strategy`
  - `Priority`: 90
  - `Reads`: `movesLeft`
  - `Writes`: `strategicAdvice`, `notification`
- **IF:**
  - The `movesLeft` slot in the Working Memory is less than or equal to `2`.
- **THEN:**
  - Set the `strategicAdvice` slot to `"push_for_points"`.
  - Append `"🏁 Late Game: Prioritize scoring points..."` to the `notification` slot.

### Example Rule 3: Decision Making

- **Rule Name:** `Discard Weak Hand If Discards Available`
- **Metadata:**
  - `Phase`: `decision`
  - `Priority`: 70
  - `Reads`: `detectedCombos`, `remainingDiscards`
  - `Writes`: `currentDecision`
- **IF:**
  - The `remainingDiscards` slot is greater than `0`.
  - AND EITHER:
    - The `detectedCombos` list is empty.
    - OR The score of the best combo in `detectedCombos` is less than `30`.
- **THEN:**
  - Set the `currentDecision` slot to `"discard:improve_weak_hand"`.

### Example Rule 4: Card Selection

- **Rule Name:** `Select Weakest Cards For Discard`
- **Metadata:**
  - `Phase`: `selection`
  - `Priority`: 90
  - `Reads`: `currentDecision`, `handCards`, `deckCards`, `remainingDiscards`
  - `Writes`: `recommendedIndices`, `discardCandidatesEval`
- **IF:**
  - The `currentDecision` slot starts with `"discard"`.
  - AND The `handCards` slot is not empty.
  - AND The `remainingDiscards` slot is greater than `0`.
- **THEN:**
  - For each card in `handCards`:
    - Calculate a "keep score" using `ProbabilityEstimators` (considering hand, deck).
  - Sort the hand card indices based on the lowest "keep scores".
  - Take the top N indices, where N is the value in `remainingDiscards`.
  - Set the `recommendedIndices` slot to this list of indices.
  - (Optional) Populate `discardCandidatesEval` slot with detailed analysis for explanation.

These examples illustrate how structured data (Frames) and conditional logic (Rules) work together within the KBS to analyze the game and produce recommendations.
