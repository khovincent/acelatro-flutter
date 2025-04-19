import 'package:flutter/material.dart';
import '../models/card_model.dart';

class LiveInputTab extends StatefulWidget {
  final List<CardModel> fullDeck;
  final int maxCards;
  final void Function(List<CardModel>) onSubmit;

  const LiveInputTab({
    super.key,
    required this.fullDeck,
    required this.maxCards,
    required this.onSubmit,
  });

  @override
  State<LiveInputTab> createState() => _LiveInputTabState();
}

class _LiveInputTabState extends State<LiveInputTab> {
  final Set<int> selectedIndices = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Select up to 8 cards to use as your hand:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.fullDeck.asMap().entries.map((entry) {
                final idx = entry.key;
                final card = entry.value;
                final isSelected = selectedIndices.contains(idx);

                return ChoiceChip(
                  selected: isSelected,
                  label: Text(card.shortName),
                  backgroundColor: card.color == 'red'
                      ? Colors.red.shade100
                      : Colors.grey.shade300,
                  selectedColor: Colors.blueAccent,
                  onSelected: (_) {
                    setState(() {
                      if (isSelected) {
                        selectedIndices.remove(idx);
                      } else if (selectedIndices.length < widget.maxCards) {
                        selectedIndices.add(idx);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Submit Hand'),
            onPressed: selectedIndices.length <= widget.maxCards
                ? () {
                    final selectedCards =
                        selectedIndices.map((i) => widget.fullDeck[i]).toList();
                    widget.onSubmit(selectedCards);
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
