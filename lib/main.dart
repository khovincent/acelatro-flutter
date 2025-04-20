import 'package:flutter/material.dart';
import 'models/game_state.dart';
import 'models/combo_definitions.dart';
import 'widgets/add_card_dialog.dart';
import 'widgets/live_input_tab.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Balatro KBS',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late GameState gameState;
  final Set<int> selectedIndices = {};

  @override
  void initState() {
    super.initState();
    gameState = GameState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: gameState.mode == GameMode.live ? 5 : 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Balatro Poker Assistant'),
          bottom: TabBar(
            tabs: [
              if (gameState.mode == GameMode.live)
                const Tab(text: 'Live Input'),
              const Tab(text: 'Analyze Hand'),
              const Tab(text: 'Played Cards'),
              const Tab(text: 'Discarded Cards'),
              const Tab(text: 'Combo Scores'),
            ],
          ),
        ),
        body: Column(
          children: [
            // — Status Bar —
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Round: ${gameState.roundNumber}'),
                  Text(
                      'Points: ${gameState.currentPoints}/${gameState.requiredPoints}'),
                  Text('Deck: ${gameState.deck.length}'),
                ],
              ),
            ),

            // — Notification —
            // — Notification —
            if (gameState.notification.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: gameState.notification.contains('earned')
                        ? Colors.green
                        : (gameState.notification.contains('⚠️')
                            ? Colors.red.shade300
                            : Colors.grey.shade300),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: gameState.notification.split('\n').map((line) {
                    Color textColor = Colors.black;
                    if (line.contains('earned')) textColor = Colors.green;
                    if (line.contains('⚠️')) textColor = Colors.red;
                    if (line.contains('🤖')) textColor = Colors.blue;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        line,
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // — Controls —
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() {
                      gameState.mode = gameState.mode == GameMode.demo
                          ? GameMode.live
                          : GameMode.demo;
                      gameState.startRound();
                      gameState.notification = gameState.mode == GameMode.live
                          ? '🟢 Live Mode: Manual card input'
                          : '🔵 Demo Mode: Random deck';
                    }),
                    child: Text(gameState.mode == GameMode.live
                        ? 'Switch to Demo Mode'
                        : 'Switch to Live Mode'),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      gameState.startRound();
                      selectedIndices.clear();
                    }),
                    child: const Text('Reset Round'),
                  ),
                  ElevatedButton(
                    onPressed: selectedIndices.isEmpty
                        ? null
                        : () => setState(() {
                              gameState.playCombo(selectedIndices.toList());
                              selectedIndices.clear();
                            }),
                    child: const Text('Play Combo'),
                  ),
                  ElevatedButton(
                    onPressed: selectedIndices.isEmpty
                        ? null
                        : () => setState(() {
                              gameState.discard(selectedIndices.toList());
                              selectedIndices.clear();
                            }),
                    child: const Text('Discard'),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => gameState.sortHandByRank()),
                    child: const Text('Sort by Rank'),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => gameState.sortHandBySuit()),
                    child: const Text('Sort by Suit'),
                  ),
                ],
              ),
            ),

            // — Hand Display —
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: gameState.hand.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final card = entry.value;
                  final isSelected = selectedIndices.contains(idx);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        selectedIndices.remove(idx);
                      } else if (selectedIndices.length < 5) {
                        selectedIndices.add(idx);
                      } else {
                        gameState.notification =
                            '⚠️ You can only select up to 5 cards.';
                      }
                    }),
                    child: Container(
                      width: 100,
                      height: 140,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Colors.blue
                              : (card.color == 'red'
                                  ? Colors.red
                                  : Colors.black),
                          width: isSelected ? 3 : 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(card.shortName,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(card.value.toString(),
                              style: const TextStyle(fontSize: 14)),
                          Text('of ${card.suit}',
                              style: const TextStyle(fontSize: 12)),
                          Text('Chip: ${card.chipValue}',
                              style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Show Add Card button only if in Live Mode
            if (gameState.mode == GameMode.live)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Card Manually'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AddCardDialog(
                      onCardAdded: (card) {
                        setState(() => gameState.addCardToHand(card));
                      },
                    ),
                  ),
                ),
              ),

            // — Tab Content —
            Expanded(
              child: TabBarView(
                children: [
                  if (gameState.mode == GameMode.live)
                    LiveInputTab(
                      fullDeck: gameState.getFullDeck(),
                      maxCards: gameState.maxHandSize,
                      onSubmit: (cards) => setState(() {
                        gameState.hand = cards;
                        gameState.notification = '🟢 Hand updated manually.';
                      }),
                    ),
                  // 1) Analyze Hand
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: gameState.analyzeHand().take(5).map((combo) {
                        // find indices of those cards in current hand
                        final indices = combo.cards
                            .map((c) => gameState.hand.indexOf(c))
                            .where((i) => i >= 0)
                            .toList();
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(combo.name),
                            subtitle: Text(
                                'Score: ${combo.score}\nCards: ${combo.cards.map((c) => c.shortName).join(' ')}'),
                            trailing: ElevatedButton(
                              onPressed: () => setState(() {
                                selectedIndices
                                  ..clear()
                                  ..addAll(indices);
                              }),
                              child: const Text('Select'),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // 2) Played Cards
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: gameState.playedCards.map((card) {
                        return Chip(
                          label: Text(card.shortName),
                          backgroundColor: card.color == 'red'
                              ? Colors.red.shade200
                              : Colors.grey.shade300,
                        );
                      }).toList(),
                    ),
                  ),

                  // 3) Discarded Cards
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: gameState.discardedCards.map((card) {
                        return Chip(
                          label: Text(card.shortName),
                          backgroundColor: card.color == 'red'
                              ? Colors.red.shade200
                              : Colors.grey.shade300,
                        );
                      }).toList(),
                    ),
                  ),

                  // 4) Combo Scores
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Combo')),
                        DataColumn(label: Text('Base')),
                        DataColumn(label: Text('Multiplier')),
                      ],
                      rows: comboDefinitions.map((def) {
                        return DataRow(cells: [
                          DataCell(Text(def.name)),
                          DataCell(Text(def.base.toString())),
                          DataCell(Text(def.multiplier.toString())),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
