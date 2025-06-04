import 'package:flutter/material.dart';
import '../../core/models/card_model.dart';
import './common/mini_card_display.dart'; // Updated import

// Remove the old _buildMiniCard function from here

class DrawInputDialog extends StatefulWidget {
  final int cardsNeeded;
  final Set<CardModel> unavailableCards;

  const DrawInputDialog({
    super.key,
    required this.cardsNeeded,
    required this.unavailableCards,
  });

  @override
  State<DrawInputDialog> createState() => _DrawInputDialogState();
}

class _DrawInputDialogState extends State<DrawInputDialog> {
  final List<CardModel> _fullDeck = _createFullDeck();
  final List<CardModel> _selectedDrawnCards = [];
  final Set<CardModel> _selectedFromDeckView = {};

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

  void _toggleCardSelection(CardModel card) {
    if (widget.unavailableCards.contains(card)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${card.shortName} is already in hand/played/discarded.',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedFromDeckView.contains(card)) {
        _selectedDrawnCards.remove(card);
        _selectedFromDeckView.remove(card);
      } else {
        if (_selectedDrawnCards.length < widget.cardsNeeded) {
          _selectedDrawnCards.add(card);
          _selectedFromDeckView.add(card);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You only need to select ${widget.cardsNeeded} card(s).',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  void _submitDrawnCards() {
    if (_selectedDrawnCards.length == widget.cardsNeeded) {
      Navigator.of(context).pop(List<CardModel>.from(_selectedDrawnCards));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select exactly ${widget.cardsNeeded} card(s).'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Input ${widget.cardsNeeded} Drawn Card(s)'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Selected (${_selectedDrawnCards.length} / ${widget.cardsNeeded}):',
            ),
            Container(
              padding: const EdgeInsets.all(4.0),
              constraints: const BoxConstraints(minHeight: 40),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: _selectedDrawnCards.isEmpty
                  ? const Center(child: Text('Tap cards below'))
                  : Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: _selectedDrawnCards
                          .map(
                            (card) => SizedBox(
                              width: 45, // Specific size for selected items display
                              height: 63,
                              // Use the common widget
                              child: buildMiniCard(
                                card: card,
                                isSelected: true, // Always selected in this view
                                isFaded: false,    // Never faded in this view
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const Divider(),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 55,
                  childAspectRatio: 0.7, // (width / height), so height is approx 55 / 0.7 = 78. For 55x~63, ratio should be 55/63 ~ 0.87
                                          // The original _buildMiniCard was 45w x 63h = 0.71 aspect ratio.
                                          // For maxCrossAxisExtent 55, height will be 55 / 0.7 = ~78. Let's keep 0.7 for now.
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                ),
                itemCount: _fullDeck.length,
                itemBuilder: (context, index) {
                  final card = _fullDeck[index];
                  final bool isSelectedInDialog = _selectedFromDeckView.contains(card);
                  final bool isUnavailable = widget.unavailableCards.contains(card);
                  return GestureDetector(
                    onTap: isUnavailable ? null : () => _toggleCardSelection(card),
                    // Use the common widget
                    child: buildMiniCard(
                      card: card,
                      isSelected: isSelectedInDialog,
                      isFaded: isUnavailable,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitDrawnCards,
          child: const Text('Confirm Drawn Cards'),
        ),
      ],
    );
  }
}