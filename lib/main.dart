// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'core/models/card_model.dart';
import 'core/models/combo_definitions.dart';
import 'core/models/game_state.dart';
import 'ui/widgets/live_hand_input.dart';
import 'ui/widgets/draw_input_dialog.dart';
import 'ui/widgets/common/mini_card_display.dart'; // <<<--- ADDED THIS IMPORT

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => GameState(),
      child: const BalatroKbsApp(),
    ),
  );
}

class BalatroKbsApp extends StatelessWidget {
  const BalatroKbsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balatro KBS Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey.shade300,
          labelStyle: const TextStyle(color: Colors.black87),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          side: BorderSide.none,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final Set<int> _selectedIndices = {};
  TabController? _tabController;
  int _currentControllerLength = -1;
  bool _isDrawDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gameState = Provider.of<GameState>(context, listen: false);
        gameState.addListener(_handleGameStateChanges);
        final initialTabCount = gameState.mode == GameMode.live ? 5 : 4;
        _initOrUpdateTabControllerIfNeeded(initialTabCount);
      }
    });
  }

  @override
  void dispose() {
    Provider.of<GameState>(
      context,
      listen: false,
    ).removeListener(_handleGameStateChanges);
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    super.dispose();
  }

  void _handleGameStateChanges() {
    final gameState = Provider.of<GameState>(context, listen: false);
    if (gameState.needsDrawInput && !_isDrawDialogShowing && mounted) {
      _isDrawDialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDrawInputDialog(gameState);
      });
    }
  }

  Future<void> _showDrawInputDialog(GameState gameState) async {
    final Set<CardModel> unavailable = {
      ...gameState.hand,
      ...gameState.playedCards,
      ...gameState.discardedCards,
    };

    final List<CardModel>? drawnCards = await showDialog<List<CardModel>>(
      context: context,
      barrierDismissible: false,
      builder:
          (BuildContext dialogContext) => DrawInputDialog(
            cardsNeeded: gameState.cardsNeeded,
            unavailableCards: unavailable,
          ),
    );

    _isDrawDialogShowing = false;

    if (!mounted) return;

    if (drawnCards != null) {
      gameState.addDrawnCards(drawnCards);
    } else {
      print("Draw input dialog cancelled by user.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw cancelled.'),
          duration: Duration(seconds: 1),
        ),
      );
      gameState.resetDrawInputFlag();
    }
  }

  void _handleTabSelection() {
    /* Optional listener logic */
  }

  void _initOrUpdateTabControllerIfNeeded(int requiredLength) {
    if (_tabController != null && requiredLength == _currentControllerLength) {
      return;
    }

    if (_tabController == null || requiredLength != _currentControllerLength) {
      TabController? oldController = _tabController;
      var newController = TabController(length: requiredLength, vsync: this);
      newController.addListener(_handleTabSelection);

      _tabController = newController;
      _currentControllerLength = requiredLength;

      if (oldController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          oldController.removeListener(_handleTabSelection);
          oldController.dispose();
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  // VVVVV --- MODIFIED THIS WIDGET --- VVVVV
  Widget _buildCardWidget(CardModel card, int index, bool isSelected) {
    final gameState = Provider.of<GameState>(context, listen: false);

    // Define the size for the card in the hand display
    // You might want to adjust these values for your desired look
    const double cardWidth = 70.0; // Adjusted slightly from original 80 to better fit mini_card_display internal proportions
    const double cardHeight = cardWidth / 0.7; // Aspect ratio (width / height)

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedIndices.contains(index)) {
            _selectedIndices.remove(index);
          } else {
            if (_selectedIndices.length < gameState.maxHandSize) {
              _selectedIndices.add(index);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cannot select more than ${gameState.maxHandSize} cards.',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          }
        });
      },
      child: Container( // This container adds the shadow based on selection
        width: cardWidth, // Ensure the container itself has the defined width
        height: cardHeight, // Ensure the container itself has the defined height
        decoration: BoxDecoration(
          // The border and main card content will come from buildMiniCard
          borderRadius: BorderRadius.circular(4.0), // Match buildMiniCard's expected border radius for shadow
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    spreadRadius: 0,
                  ),
                ],
        ),
        child: buildMiniCard(
          card: card,
          isSelected: isSelected, // For the border color inside buildMiniCard
          isFaded: false,          // Cards in hand are not faded
          // width and height props in buildMiniCard are for its internal container,
          // but sizing is primarily controlled by the parent SizedBox or Container.
          // We've set width/height on the parent Container.
        ),
      ),
    );
  }
  // ^^^^^ --- MODIFIED THIS WIDGET --- ^^^^^

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final isLiveMode = gameState.mode == GameMode.live;

    final List<Tab> tabs = [
      if (isLiveMode) const Tab(text: 'Live Input', icon: Icon(Icons.edit)),
      const Tab(text: 'Recommendation', icon: Icon(Icons.lightbulb_outline)),
      const Tab(text: 'Hand Analysis', icon: Icon(Icons.analytics_outlined)),
      const Tab(text: 'History', icon: Icon(Icons.history)),
      const Tab(text: 'Combos', icon: Icon(Icons.view_list)),
    ];
    final int currentTabCount = tabs.length;
    _initOrUpdateTabControllerIfNeeded(currentTabCount);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _tabController != null &&
          _tabController!.length == currentTabCount) {
        final currentControllerIndex = _tabController!.index;
        if (!isLiveMode &&
            currentControllerIndex == 0 &&
            currentTabCount == 4) {
          _tabController!.animateTo(
            1.clamp(0, _tabController!.length - 1),
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Balatro KBS Assistant'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              icon: Icon(
                isLiveMode ? Icons.edit_note : Icons.play_circle_filled,
              ),
              label: Text(isLiveMode ? 'Live' : 'Demo'),
              onPressed: () {
                final game = Provider.of<GameState>(context, listen: false);
                setState(() {
                  _selectedIndices.clear();
                });
                game.toggleMode();
              },
            ),
          ),
        ],
        bottom:
            (_tabController == null)
                ? PreferredSize(
                  preferredSize: const Size.fromHeight(kTextTabBarHeight),
                  child: Container(
                    alignment: Alignment.center,
                    height: kTextTabBarHeight,
                    child: const Text("Loading Tabs..."),
                  ),
                )
                : TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: tabs,
                ),
      ),
      body:
          (_tabController == null)
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Round: ${gameState.roundNumber}'),
                        Text(
                          'Points: ${gameState.currentPoints} / ${gameState.requiredPoints}',
                        ),
                        Text('Deck (Internal): ${gameState.deck.length}'),
                        Text('Hands Left: ${gameState.remainingHands}'),
                        Text('Discards Left: ${gameState.remainingDiscards}'),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Play'),
                          onPressed:
                              _selectedIndices.isEmpty ||
                                      gameState.remainingHands <= 0 ||
                                      gameState.isKbsRunning ||
                                      gameState.needsDrawInput
                                  ? null
                                  : () {
                                    final selected = List<int>.from(
                                      _selectedIndices,
                                    );
                                    setState(() => _selectedIndices.clear());
                                    gameState.playCards(selected);
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade100,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          label: const Text('Discard'),
                          onPressed:
                              _selectedIndices.isEmpty ||
                                      gameState.remainingDiscards <= 0 ||
                                      gameState.isKbsRunning ||
                                      gameState.needsDrawInput
                                  ? null
                                  : () {
                                    final selected = List<int>.from(
                                      _selectedIndices,
                                    );
                                    setState(() => _selectedIndices.clear());
                                    gameState.discardCards(selected);
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade100,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.sort_by_alpha, size: 18),
                          label: const Text('Sort Rank'),
                          onPressed:
                              gameState.isKbsRunning || gameState.needsDrawInput
                                  ? null
                                  : gameState.sortHandByRank,
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.sort, size: 18),
                          label: const Text('Sort Suit'),
                          onPressed:
                              gameState.isKbsRunning || gameState.needsDrawInput
                                  ? null
                                  : gameState.sortHandBySuit,
                        ),
                        if (gameState.mode == GameMode.demo)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('New Round'),
                            onPressed:
                                gameState.isKbsRunning ||
                                        gameState.needsDrawInput
                                    ? null
                                    : () {
                                      setState(() => _selectedIndices.clear());
                                      gameState.startNewRound();
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade100,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding( // --- Hand Display ---
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8.0,
                    ),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.center,
                      children:
                          gameState.hand.asMap().entries.map((entry) {
                            final index = entry.key;
                            final card = entry.value;
                            final isSelected = _selectedIndices.contains(index);
                            return _buildCardWidget(card, index, isSelected); // Calls the modified widget
                          }).toList(),
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 4.0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            gameState.isKbsRunning
                                ? Icons.sync
                                : (gameState.needsDrawInput
                                    ? Icons.input
                                    : Icons.info_outline),
                            size: 18,
                            color:
                                gameState.isKbsRunning
                                    ? Colors.blue
                                    : (gameState.needsDrawInput
                                        ? Colors.orange
                                        : Colors.black54),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              gameState.transientMessage ??
                                  (isLiveMode
                                      ? 'Input hand via Live Input tab or use actions.'
                                      : 'Make your move.'),
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        if (isLiveMode)
                          LiveHandInput(
                            onSubmit: (List<CardModel> hand) {
                              Provider.of<GameState>(
                                context,
                                listen: false,
                              ).setHandManually(hand);
                              Future.delayed(Duration.zero, () {
                                if (mounted && _tabController != null) {
                                  _tabController?.animateTo(
                                    1.clamp(0, _tabController!.length - 1),
                                  );
                                }
                              });
                            },
                          ),
                        _buildRecommendationTab(context, gameState),
                        _buildHandAnalysisTab(context, gameState),
                        _buildHistoryTab(context, gameState),
                        _buildComboDefinitionsTab(context, gameState),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildRecommendationTab(BuildContext context, GameState gameState) {
    final recommendation = gameState.latestRecommendation;
    if (gameState.isKbsRunning) {
      return const Center(child: CircularProgressIndicator());
    }
    if (recommendation == null) {
      return const Center(child: Text('No recommendation available yet.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KBS Recommendation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          Text(
            'Action: ${recommendation.action.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Reason: ${recommendation.reason.replaceAll('_', ' ')}'),
          if (recommendation.recommendedCards.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Cards: ${recommendation.recommendedCards.map((c) => c.shortName).join(', ')}',
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.touch_app, size: 16),
              label: const Text('Select Recommended'),
              onPressed:
                  gameState.needsDrawInput
                      ? null
                      : () => setState(() {
                        _selectedIndices.clear();
                        _selectedIndices.addAll(
                          recommendation.recommendedIndices,
                        );
                      }),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Rule Activation History (${recommendation.firedRules.length}):',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Divider(),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: recommendation.firedRules.length,
              itemBuilder:
                  (context, index) => Text(
                    ' • ${recommendation.firedRules[index]}',
                    style: const TextStyle(fontSize: 12),
                  ),
            ),
          ),
          if (recommendation.discardAnalysis != null &&
              recommendation.discardAnalysis!.isNotEmpty &&
              recommendation.action == 'discard') ...[
            const SizedBox(height: 16),
            Text(
              'Discard Candidate Analysis:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Divider(),
            ...recommendation.discardAnalysis!.map((entry) {
              final data = entry.value;
              final cardName = data['cardName'];
              final keepScore =
                  (data['keepScore'] as double?)?.toStringAsFixed(3) ?? 'N/A';
              final probabilities =
                  data['probabilities'] as Map<String, double>? ?? {};
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Card: $cardName (Index ${entry.key}) - Keep Score: $keepScore',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (probabilities.isNotEmpty) ...[
                        const Text(
                          '  Potential Improvements:',
                          style: TextStyle(fontSize: 12),
                        ),
                        ...probabilities.entries.map(
                          (probEntry) => Text(
                            '    • ${probEntry.key}: ${(probEntry.value * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ] else
                        const Text(
                          '  (No significant improvement probabilities estimated)',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildHandAnalysisTab(BuildContext context, GameState gameState) {
    if (gameState.isKbsRunning && gameState.latestRecommendation == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final detectedCombos =
        gameState.latestRecommendation?.detectedCombosInHand ?? [];
    if (gameState.hand.isEmpty && !gameState.isKbsRunning) {
      return const Center(
        child: Text('No hand cards to analyze (Hand is empty).'),
      );
    }
    if (detectedCombos.isEmpty &&
        gameState.hand.isNotEmpty &&
        !gameState.isKbsRunning) {
      return const Center(child: Text('No combos detected in current hand.'));
    }
    return ListView.builder(
      key: ValueKey(
        'hand-analysis-list-${detectedCombos.length}-${gameState.hand.hashCode}',
      ),
      itemCount: detectedCombos.length,
      itemBuilder: (context, index) {
        final combo = detectedCombos[index];
        return Card(
          child: ListTile(
            leading: Text(
              '#${index + 1}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            title: Text('${combo.name} (${combo.score} pts)'),
            subtitle: Text(combo.cards.map((c) => c.shortName).join(', ')),
            trailing:
                gameState.mode == GameMode.demo
                    ? ElevatedButton(
                      onPressed: () {
                        final currentHand =
                            Provider.of<GameState>(context, listen: false).hand;
                        final indices = <int>[];
                        final availableHandIndices = List.generate(
                          currentHand.length,
                          (i) => i,
                        );
                        bool allFound = true;
                        for (final cardToFind in combo.cards) {
                          int foundIdx = -1;
                          for (final handIdx in availableHandIndices) {
                            if (currentHand[handIdx] == cardToFind) {
                              foundIdx = handIdx;
                              break;
                            }
                          }
                          if (foundIdx != -1) {
                            indices.add(foundIdx);
                            availableHandIndices.remove(foundIdx);
                          } else {
                            allFound = false;
                            break;
                          }
                        }
                        if (allFound) {
                          setState(() {
                            _selectedIndices.clear();
                            _selectedIndices.addAll(indices);
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Error selecting combo cards."),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      child: const Text('Select'),
                    )
                    : null,
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(BuildContext context, GameState gameState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Played Cards (${gameState.playedCards.length}):',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Wrap(
            spacing: 4.0,
            runSpacing: 4.0,
            children:
                gameState.playedCards.isEmpty
                    ? [const Text('None')]
                    : gameState.playedCards
                        .map(
                          (card) => Chip(
                            label: Text(card.shortName),
                            backgroundColor: card.displayColor.withOpacity(0.2),
                          ),
                        )
                        .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Discarded Cards (${gameState.discardedCards.length}):',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Wrap(
            spacing: 4.0,
            runSpacing: 4.0,
            children:
                gameState.discardedCards.isEmpty
                    ? [const Text('None')]
                    : gameState.discardedCards
                        .map(
                          (card) => Chip(
                            label: Text(card.shortName),
                            backgroundColor: card.displayColor.withOpacity(0.2),
                          ),
                        )
                        .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildComboDefinitionsTab(BuildContext context, GameState gameState) {
    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('Combo')),
          DataColumn(label: Text('Base'), numeric: true),
          DataColumn(label: Text('Mult'), numeric: true),
          DataColumn(label: Text('Cards'), numeric: true),
        ],
        rows:
            balatroComboDefinitions
                .map(
                  (def) => DataRow(
                    cells: [
                      DataCell(Text(def.name)),
                      DataCell(Text(def.baseScore.toString())),
                      DataCell(Text(def.multiplier.toString())),
                      DataCell(Text(def.requiredCardCount.toString())),
                    ],
                  ),
                )
                .toList(),
      ),
    );
  }
}