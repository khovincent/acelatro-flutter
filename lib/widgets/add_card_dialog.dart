import 'package:flutter/material.dart';
import '../models/card_model.dart';

class AddCardDialog extends StatefulWidget {
  final void Function(CardModel) onCardAdded;
  const AddCardDialog({super.key, required this.onCardAdded});

  @override
  State<AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<AddCardDialog> {
  String selectedSuit = 'Hearts';
  int selectedValue = 2;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Card to Hand'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: selectedSuit,
            items: CardModel.suitSymbols.keys.map((suit) {
              return DropdownMenuItem(value: suit, child: Text(suit));
            }).toList(),
            onChanged: (val) => setState(() => selectedSuit = val!),
            decoration: const InputDecoration(labelText: 'Suit'),
          ),
          DropdownButtonFormField<int>(
            value: selectedValue,
            items: CardModel.values.keys.map((v) {
              return DropdownMenuItem(
                  value: v, child: Text(CardModel.values[v]!));
            }).toList(),
            onChanged: (val) => setState(() => selectedValue = val!),
            decoration: const InputDecoration(labelText: 'Value'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onCardAdded(CardModel(selectedSuit, selectedValue));
            Navigator.pop(context);
          },
          child: const Text('Add Card'),
        ),
      ],
    );
  }
}
