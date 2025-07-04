# Balatro KBS Assistant

A Flutter application demonstrating a Knowledge-Based System (KBS) approach to providing strategic recommendations (Play/Discard) for a Balatro-style poker game.

**Version:** 1.0.0  
**Developer:** [Your Name/Team]  
**Last Updated:** [Date]

## Table of Contents

1. [Project Description & Goals](#project-description--goals)
2. [Key Features](#key-features)
3. [Technologies Used](#technologies-used)
4. [Core Architecture](#core-architecture)
5. [Key Components & Concepts](#key-components--concepts)
   - [Knowledge Representation](#knowledge-representation)
   - [Inference Engine](#inference-engine)
   - [Game State Model](#game-state-model)
   - [User Interface](#user-interface)
6. [Technical Implementation Details](#technical-implementation-details)
   - [Project Directory Structure](#project-directory-structure)
   - [Detailed Execution Flow](#detailed-execution-flow)
   - [Probability Estimator Logic](#probability-estimator-logic)
7. [How to Run and Use the Application](#how-to-run-and-use-the-application)
8. [Project Limitations](#project-limitations)
9. [Future Development Potential](#future-development-potential)
10. [Project Conclusion](#project-conclusion)

---

## Project Description & Goals

**Short Description:**
Balatro KBS Assistant is a Flutter application designed as a strategic aid for the _roguelike deck-builder_ card game Balatro. The application leverages Knowledge-Based System (KBS) paradigms to analyze a player's game state (especially cards in hand) and provide action recommendations (Play or Discard) along with suggested specific cards.

**Project Goals:**

- **KBS Exploration:** Explore the application of KBS concepts (Frames, Production Rules, Forward-Chaining Inference Engine) in a dynamic and probabilistic card game domain.
- **Strategic Assistance:** Provide recommendations that can help players make more informed decisions in Balatro, particularly regarding card selection for playing or discarding.
- **Learning & Prototyping:** Serve as a study project to understand the design and implementation of simple intelligent systems and build a functional prototype.
- **Mode Flexibility:** Support two operation modes: "Demo Mode" for simulation and internal testing, and "Live Mode" designed for interactive use alongside actual Balatro game sessions.

## Key Features

- **Automatic Hand Analysis:** Detects all possible standard poker combinations (Pair, Two Pair, Three of a Kind, Straight, Flush, Full House, Four of a Kind, Straight Flush) from cards in hand.
- **Play/Discard Recommendations:** Provides main action advice (Play or Discard) based on comprehensive analysis.
- **Recommended Card Selection:** Shows specific cards recommended for playing or discarding.
- **Decision Explanation:** Provides fired rules logs to give insights into the KBS decision-making process.
- **Discard Candidate Analysis:** In "Discard" recommendation cases, displays basic probability analysis explaining why certain cards are considered good candidates for discarding (based on "keep score" and hand improvement potential).
- **Demo Mode:**
  - Game simulation with automatic card dealing from internal deck.
  - In-app Play/Discard actions automatically draw new cards.
- **Live Mode (Interactive):**
  - Users input their initial hand cards from actual Balatro game.
  - Application analyzes the input hand.
  - After player performs actions (Play/Discard) in their Balatro game, application **requests input** for newly drawn cards.
  - Ensures hand state synchronization between application and player's game for continuous recommendations.
- **Informative User Interface (UI):**
  - Interactive hand card display with selection capabilities.
  - Organized tabbed information for Recommendations, Hand Analysis, Action History, and Combo Score Definitions.
  - Visual status indicators for KBS processes (e.g., "Analyzing...").
- **Basic Card Display Customization:** Users can view visual representations of cards.

## Technologies Used

- **Programming Language:** Dart
- **Application Framework:** Flutter (for cross-platform UI and application structure)
- **State Management:** Provider (ChangeNotifier)
- **AI Paradigm:** Knowledge-Based System (KBS)
  - **Inference Engine:** Forward-Chaining
  - **Knowledge Representation:** Frames and Production Rules (IF-THEN)

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

### Knowledge Representation

#### Frames (`lib/core/kbs/frames/`)

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

#### Rule Base (`lib/core/kbs/rules/`)

- **Concept:** The collection of IF-THEN rules that encapsulate the game logic, strategies, and heuristics. As of the current implementation, the system contains **28 rules**.
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
  - **`initialize()`:** Called once (usually at app start via `GameState`) to load all rule definitions from different feature files.
  - **`getRulesForPhase()`:** Retrieves rules relevant to a specific phase for the `InferenceEngine`.
  - **`validateDependencies()`:** Performs a basic check to see if slots mentioned in rule `reads` are either initialized in `GameStateFrame` or written to by _some_ rule.

##### Complete Rule List (Total: 28 Rules)

**Phase: `detection` (9 Rules)**

- `Detect Straight Flush`: Detects Straight Flush combinations.
- `Detect Four of a Kind`: Detects Four of a Kind combinations.
- `Detect Full House`: Detects Full House combinations.
- `Detect Flush`: Detects Flush combinations.
- `Detect Straight`: Detects Straight combinations.
- `Detect Three of a Kind`: Detects Three of a Kind combinations.
- `Detect Two Pair`: Detects Two Pair combinations.
- `Detect Pair`: Detects Pair combinations.
- `Sort Detected Combos`: Sorts the list of detected combos by score.

**Phase: `strategy` (8 Rules)**

- `Identify Early Game`: Identifies the early stage of the round.
- `Identify Mid Game`: Identifies the middle stage of the round.
- `Identify Late Game`: Identifies the late stage of the round.
- `Assess High Risk Needed`: Flags when high scores are needed urgently.
- `Assess Conservative Play Possible`: Flags when ahead of the required score curve.
- `Target Already Reached`: Flags when the required score is met or exceeded.
- `Assess Strong Hand Potential`: Flags if detected combos include a very high-scoring one.
- `Assess Weak Hand Potential`: Flags if the best detected combo is very weak.

**Phase: `decision` (9 Rules)**

- `Play If Target Reached By Top Combo`: Decides to PLAY if the best combo meets the target.
- `Play If High Score Needed Urgently`: Decides to PLAY a decent combo if high scores are urgent.
- `Play Strong Combo If Safe`: Decides to PLAY a strong combo if not under pressure.
- `Play Decent Combo In Late Game`: Decides to PLAY a decent combo if few moves remain.
- `Discard Weak Hand If Discards Available`: Decides to DISCARD if hand is weak and discards remain.
- `Discard If Conservative Play Advised And No Strong Play`: Decides to DISCARD if conservative play is okay and no strong play exists.
- `Fallback Play If Reasonable Combo Exists`: Defaults to PLAYING a reasonable combo if no other rule fired.
- `Fallback Discard If Possible`: Defaults to DISCARDING if no play rule fired and discards are available.
- `No Action Possible`: Sets decision to none if no plays or discards are left.

**Phase: `selection` (2 Rules)**

- `Select Cards For Best Detected Combo`: Selects indices of cards for the best detected combo if decision is PLAY.
- `Select Weakest Cards For Discard`: Selects card indices with the lowest "keep score" if decision is DISCARD, using probability estimators.

### Inference Engine (`lib/core/kbs/inference_engine.dart`)

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

### Game State Model (`lib/core/models/game_state.dart`)

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

### User Interface (`lib/main.dart`, `lib/ui/widgets/`)

- Uses Flutter and the `provider` package.
- `HomePage` watches `GameState` for changes.
- Displays game info, hand cards, action buttons.
- Conditionally renders UI elements based on `GameState.mode`.
- Uses `LiveHandInput` widget for initial hand input in Live Mode.
- Uses `DrawInputDialog` (triggered by `GameState.needsDrawInput`) to get drawn cards from the user in Live Mode.
- Displays analysis and recommendations from `GameState.latestRecommendation` in various tabs.
- Calls `GameState` methods in response to user actions (button presses, dialog submissions).

## Technical Implementation Details

### Project Directory Structure

The application is organized with the following folder structure for modularity:

- `lib/core/models/`: Contains core data models (e.g., `CardModel`, `GameState`).
- `lib/core/kbs/`: Contains Knowledge-Based System infrastructure.
  - `frames/`: Frame definitions and implementations.
  - `rules/`: Basic `Rule` definitions and `RuleRegistry`.
  - `inference_engine.dart`: Inference engine implementation.
- `lib/core/ui_utils/`: UI-related utilities (e.g., `card_assets.dart` if using sprites).
- `lib/core/utils/`: General utilities (e.g., `combinations_util.dart`).
- `lib/features/`: Contains specific KBS rule implementations, grouped by functionality or phase.
  - `combo_detection/kbs/combo_rules.dart`
  - `strategy/kbs/strategy_rules.dart`
  - `decision/kbs/decision_rules.dart`
  - `selection/kbs/selection_rules.dart` (includes `probability_estimators.dart`)
- `lib/ui/`: Contains User Interface components.
  - `widgets/`: Reusable UI widgets (e.g., `live_hand_input.dart`, `draw_input_dialog.dart`).
- `lib/main.dart`: Application entry point and main UI (`HomePage`).

### Detailed Execution Flow

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

### Probability Estimator Logic

To support smarter "Discard" decisions, the `probability_estimators.dart` module is used. This module **does not perform exact statistical probability calculations**, but rather provides heuristic functions:

- **`estimateKeepScore(CardModel, List<CardModel> currentHand, List<CardModel> remainingDeck)`:** Calculates a numerical score representing how "valuable" a card is to _keep_ in hand. This score is based on the card's potential to contribute to forming various combinations (Pair, Three/Four of a Kind, Flush, Straight) considering other cards in hand and estimated cards remaining in the application's internal deck. Cards with lower "keep scores" are considered better candidates for discarding.
- **`estimateImprovementProbabilities(...)`:** (Used for UI explanations) Provides rough estimates of chances to form certain hands if a card is discarded and one new card is drawn.

Note that the accuracy of these estimators, especially in Live Mode, depends on how accurately the application's internal deck representation reflects the actual deck condition in the Balatro game.

## How to Run and Use the Application

### Requirements

- Flutter SDK (version 3.0 or higher)
- Dart SDK (included with Flutter)
- Compatible IDE (VS Code, Android Studio, or IntelliJ IDEA)
- Device or emulator for testing

### Installation & Running

1. **Clone or download** the project source code.
2. **Navigate** to the project directory in terminal/command prompt.
3. **Install dependencies:**
   ```bash
   flutter pub get
   ```
4. **Run the application:**
   ```bash
   flutter run
   ```
5. **Select target device** (if multiple devices/emulators are available).

### Usage Guide

#### Demo Mode

1. **Launch the application** - it starts in Demo Mode by default.
2. **Click "Start New Round"** to begin a simulated game.
3. **View the dealt hand** and observe the KBS analysis in the tabs below.
4. **Select cards** by tapping them (for Play actions) or follow recommendations.
5. **Click "Play" or "Discard"** buttons based on recommendations or your choice.
6. **Observe** how the hand updates automatically and new recommendations appear.
7. **Continue playing** until the round ends or you choose to start a new round.

#### Live Mode

1. **Switch to Live Mode** using the mode toggle button.
2. **Input your current hand** from your actual Balatro game using the input dialog.
3. **Review the KBS recommendations** for your real hand.
4. **Perform the suggested action** in your Balatro game.
5. **When prompted**, input the newly drawn cards from your game.
6. **Repeat steps 3-5** for continuous assistance throughout your Balatro session.

#### Understanding Recommendations

- **Recommendation Tab:** Shows the main action (Play/Discard) and recommended cards.
- **Hand Analysis Tab:** Displays all detected combinations and their scores.
- **Action History Tab:** Shows the sequence of fired rules explaining the reasoning process.
- **Combo Definitions Tab:** Reference for understanding different poker hand values.

## Project Limitations

- **Limited Balatro Mechanics:** Currently only implements basic poker hand detection. Missing key Balatro features like Jokers, Card Enhancements, Blind effects, and consumable cards.
- **Simplified Scoring:** Uses basic poker scoring rather than Balatro's complex Chips + Mult system.
- **Heuristic Probability:** Probability estimations are rule-of-thumb based, not mathematically precise.
- **Live Mode Accuracy:** Depends on user accurately inputting cards and maintaining synchronization with actual game state.
- **No Real-time Integration:** Cannot automatically sync with actual Balatro game - requires manual input.
- **Limited Strategy Depth:** Current rules implement basic strategic concepts and may not cover all optimal play scenarios.

## Future Development Potential

### Priority Enhancements

- **Core Balatro Mechanics Integration:**
  - **Jokers:** Highest priority. Modeling diverse Joker effects (+Mult, +Chips, XMult, per-suit/rank triggers, card modifications).
  - **Card Enhancements:** Implementing Seals (Gold, Red, Blue, Purple), Editions (Foil, Holographic, Polychrome), and Enhancements (Bonus, Mult, Wild, Glass, Steel).
  - **Blind Effects:** Adding Boss Blind effects that modify strategy or play validity.
  - **Consumable Cards:** Tarot/Planet/Spectral card usage recommendations.

### Advanced KBS Strategy

- **Balatro Economic Optimization:** Rules considering money bonuses from remaining hands.
- **Long-term Risk Analysis:** Considering future Antes and escalating score requirements.
- **Setup Pattern Recognition:** Identifying potential for very strong hands and suggesting risky discards.

### UI/UX Improvements

- **Probability Visualization:** Displaying probability estimates as bars or percentages.
- **Advanced Live Mode Deck Tracking:** Options to mark cards seen in shops or discarded by Blind effects.
- **Recommendation Customization:** Risk level or play style preference settings.

### Code Quality

- **Modular UI:** Breaking down `main.dart` into smaller, manageable widgets.
- **Comprehensive Testing:** Unit tests for models, `GameState` logic, core KBS functions, and widget tests.

## Project Conclusion

The Balatro KBS Assistant successfully demonstrates the application of Knowledge-Based System principles in a card game domain. The project showcases how Frames, Production Rules, and Forward-Chaining Inference can be used to create an intelligent decision-support system.

While currently limited to basic poker hand analysis, the modular architecture provides a solid foundation for incorporating Balatro's more complex mechanics. The dual-mode design (Demo/Live) offers both testing capabilities and practical utility for actual gameplay assistance.

The project serves as an excellent learning example for AI system design and provides a functional prototype that could evolve into a comprehensive Balatro strategy assistant with further development.

---

## KBS Knowledge Representation Examples

### Frame Representation (Working Memory)

#### Example: `GameStateFrame` (Simplified)

**Purpose:** Holds current game facts and derived information for the inference engine.

**Structure:**

- **`frameType`**: `"GameState"`
- **`slots`** (Map of Key -> Value):
  - `roundNumber`: `1`
  - `currentPoints`: `150`
  - `requiredPoints`: `300`
  - `pointsGap`: `150` (Calculated: `requiredPoints` - `currentPoints`)
  - `remainingHands`: `3`
  - `remainingDiscards`: `2`
  - `handCards`: `[ Card(K♠), Card(K♥), Card(7♦), ... ]`
  - `detectedCombos`: `[ ComboResult(Pair, [K♠, K♥], 40), ... ]` (Populated by rules)
  - `currentDecision`: `"play:strong_combo_pair"` (Set by Decision rules)
  - `recommendedIndices`: `[0, 1]` (Set by Selection rules)

### Rule Base Representation Examples

#### Example Rule 1: Combo Detection

- **Name:** `Detect Pair`
- **Phase:** `detection`
- **IF:** `handCards` contains at least 2 cards with the same rank
- **THEN:** Create `ComboResult` for Pair and add to `detectedCombos`

#### Example Rule 2: Strategy Assessment

- **Name:** `Identify Late Game`
- **Phase:** `strategy`
- **IF:** `movesLeft` ≤ 2
- **THEN:** Set `strategicAdvice` to `"push_for_points"`

#### Example Rule 3: Decision Making

- **Name:** `Discard Weak Hand If Discards Available`
- **Phase:** `decision`
- **IF:** `remainingDiscards` > 0 AND best combo score < 30
- **THEN:** Set `currentDecision` to `"discard:improve_weak_hand"`

#### Example Rule 4: Card Selection

- **Name:** `Select Weakest Cards For Discard`
- **Phase:** `selection`
- **IF:** `currentDecision` starts with `"discard"`
- **THEN:** Calculate keep scores and set `recommendedIndices` to lowest scoring cards
