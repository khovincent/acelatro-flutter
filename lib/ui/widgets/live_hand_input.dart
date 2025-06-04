import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/card_model.dart';
import '../../core/models/game_state.dart';
import './common/mini_card_display.dart'; // Updated import

// Remove the old _buildMiniCard function from here

class LiveHandInput extends StatefulWidget {
  final Function(List<CardModel> hand) onSubmit;

  const LiveHandInput({super.key, required this.onSubmit});

  @override
  State<LiveHandInput> createState() => _LiveHandInputState();
}

class _LiveHandInputState extends State<LiveHandInput> {
  final List<CardModel> _fullDeck = _createFullDeck();
  final List<CardModel> _selectedHand = [];
  final Set<CardModel> _selectedFromDeck = {};

  static List<CardModel> _createFullDeck() {
    final List<CardModel> deck = [];
    const suitOrder = ['Spades', 'Hearts', 'Clubs', 'Diamonds'];
    for (final suit in suitOrder) {
      for (final value in CardModel.valueNames.keys) {
        deck.add(CardModel(suit: suit, value: value));
      }
    }
    deck.sort((a, b) {
      final suitCompare = suitOrder
          .indexOf(a.suit)
          .compareTo(suitOrder.indexOf(b.suit));
      if (suitCompare != 0) return suitCompare;
      return b.value.compareTo(a.value);
    });
    return deck;
  }

  void _toggleCardSelection(CardModel card, int maxHandSize) {
    setState(() {
      if (_selectedHand.contains(card)) {
        _selectedHand.remove(card);
        _selectedFromDeck.remove(card);
      } else {
        if (_selectedHand.length < maxHandSize) {
          _selectedHand.add(card);
          _selectedFromDeck.add(card);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot select more than $maxHandSize cards.'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedHand.clear();
      _selectedFromDeck.clear();
    });
  }

  void _submitHand() {
    if (_selectedHand.isNotEmpty) {
      widget.onSubmit(List.from(_selectedHand));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live hand submitted!'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select cards for your hand.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final maxHandSize = gameState.maxHandSize;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your Hand (${_selectedHand.length} / $maxHandSize):',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8.0),
            constraints: const BoxConstraints(minHeight: 50),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _selectedHand.isEmpty
                ? const Center(
                    child: Text(
                      'Tap cards from the deck below',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: _selectedHand
                        .map(
                          (card) => ConstrainedBox( // Ensure consistent sizing for cards in hand display
                            constraints: const BoxConstraints(
                              minWidth: 50, // Adjust as needed
                              minHeight: 70, // Adjust as needed - 50 / 0.7 ratio
                              maxWidth: 50,
                              maxHeight: 70,
                            ),
                            // Use the common widget
                            child: buildMiniCard(
                              card: card,
                              isSelected: true, // Always selected in this view
                              isFaded: false,   // Never faded in this view
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Submit Hand'),
                onPressed: _submitHand,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear'),
                onPressed: _clearSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade100,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Text(
            'Available Deck:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 65,
                childAspectRatio: 0.7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _fullDeck.length,
              itemBuilder: (context, index) {
                final card = _fullDeck[index];
                final bool isSelectedInDeck = _selectedFromDeck.contains(card);
                return GestureDetector(
                  onTap: () => _toggleCardSelection(card, maxHandSize),
                  // Use the common widget
                  child: buildMiniCard(
                    card: card,
                    isSelected: isSelectedInDeck, // For border
                    isFaded: isSelectedInDeck,    // For opacity, as selecting from deck dims it
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}