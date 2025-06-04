### IMPROVEMENT TO_DO LIST

**1. KBS Knowledge & Logic Enhancements (Making it More "Balatro"):**

- **Balatro Mechanics:**
  - **Jokers:** Model their diverse effects (multipliers, triggers, card changes). This is likely the _most impactful_ improvement for Balatro accuracy.
  - **Card Enhancements:** Handle Seals, Editions (Foil, etc.), Enhancements (Bonus, Mult, etc.) in `CardModel` and scoring.
  - **Blinds:** Incorporate Boss Blind effects/debuffs into rules (e.g., "Cannot play Pairs", "Suits debuffed").
  - **Tarot/Planet/Spectral Cards:** Add rules suggesting _when_ to use consumables based on game state or hand potential.
  - _(Vouchers/Boosters might be less relevant for immediate play advice)._
- **Strategy & Decision Logic:**
  - **Advanced Discard:** Consider draw odds for specific combos (straights, flushes), holding pairs vs. kickers, long-term setup vs. immediate score.
  - **Advanced Play:** Evaluate if playing the _best_ immediate combo breaks a _potentially much better_ future hand.
  - **Risk/Goal Tuning:** Factor in specific Blind requirements, Antes, or distance-to-target more precisely.
  - **Utilize `StrategyFrame`:** Make strategic context (e.g., "Aggressive Push", "Conservative Build") an explicit part of the Working Memory for rules to react to.
- **Rule Tuning:** Adjust priorities and numerical thresholds (scores, moves left) in existing rules based on testing and desired play style.
- **Enhanced Explainability:** Provide more detail in the reasoning log (e.g., _why_ discard Card A over Card B, showing comparative scores/probabilities).

**2. UI/UX Improvements (User Experience):**

- **Live Mode Deck Sync:** Offer optional ways for the user to update the app's internal deck state (e.g., marking seen discards) for better probability accuracy, or at least clearly state the reliance on the internal model.
- **Visual Feedback:**
  - Highlight recommended cards directly on the hand display.
  - Consider simple animations for card actions.
  - Use tooltips or clearer messages explaining _why_ buttons are disabled.
- **Input Dialogs:** Improve usability of the `LiveHandInput` and `DrawInputDialog`.
- **Layout & Responsiveness:** Adapt UI for different screen sizes.
- **Error Display:** Show errors more clearly within the UI.
- **Configuration:** Allow user settings (starting hands/discards, maybe simple Joker input).

**3. Code Quality & Maintainability (Developer Experience):**

- **Refactoring:**
  - Extract UI components (card widget, tabs) from `main.dart` into separate files.
  - Organize utility functions (`_createStandardDeck`, etc.) into dedicated util classes/files.
- **Testing:** Implement Unit Tests (Models, GameState logic, Rules, Estimators) and Widget Tests (UI components).
- **Constants:** Replace magic numbers in rules/logic with named constants.
- **Documentation:** Add more code comments, especially for complex rules or calculations.

**4. Performance:**

- **Profiling:** Identify bottlenecks in KBS execution if the app becomes slow.
- **Caching:** Cache results of expensive calculations (`analyzeHand`) if called repeatedly without state changes.
- **Optimize Builds:** Minimize unnecessary UI rebuilds.
