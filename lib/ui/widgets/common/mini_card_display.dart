import 'package:flutter/material.dart';
import '../../../core/models/card_model.dart'; // Adjust path if your project structure differs

// Helper to build individual pips (suit symbols)
Widget _buildPip(CardModel card, bool isFaded, double size) {
  return Text(
    card.suitSymbolCharacter,
    style: TextStyle(
      color: card.displayColor.withOpacity(isFaded ? 0.4 : 0.8), // Adjusted opacity
      fontSize: size,
      height: 1.0,
    ),
  );
}

// Helper to build a column of pips
Widget _buildPipColumn(List<Widget> pips) {
  if (pips.isEmpty) return const SizedBox.shrink();
  return Column(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: pips,
  );
}


// Logic for arranging pips in the center
Widget _buildCentralSymbolArea(CardModel card, bool isFaded) {
  final count = card.centralDisplaySymbolCount;
  const double smallPipSize = 7.5; // You might need to adjust this based on card size
  const double largePipSize = 18.0;

  if (count == 1) { // Ace, J, Q, K
    return Center(child: _buildPip(card, isFaded, largePipSize));
  }

  List<Widget> allPips = List.generate(count, (_) => _buildPip(card, isFaded, smallPipSize));

  // Specific layouts for number cards
  switch (count) {
    case 2:
    case 3:
      // Vertical stack for 2 and 3
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: _buildPipColumn(allPips),
        ),
      );
    case 4:
      // Two columns of 2
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPipColumn(allPips.sublist(0, 2)),
          _buildPipColumn(allPips.sublist(2, 4)),
        ],
      );
    case 5:
      // Two columns (2), center pip, Two columns (2) - or simpler 2-1-2
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPipColumn(allPips.sublist(0, 2)),
          _buildPipColumn([allPips[2]]), // Center pip
          _buildPipColumn(allPips.sublist(3, 5)),
        ],
      );
    case 6:
      // Two columns of 3
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPipColumn(allPips.sublist(0, 3)),
          _buildPipColumn(allPips.sublist(3, 6)),
        ],
      );
    case 7:
      // Pattern: 2 top, 1 middle-top, 2 middle, 2 bottom (or simpler 3-1-3)
      // Simpler: Two columns of 3, with one offset pip
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0), // Allow slight horizontal spread
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [allPips[0], allPips[1]],
            ),
            allPips[2], // Center-ish pip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [allPips[3], allPips[4]],
            ),
             Row( // For the last two, to make it more 7-like
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [allPips[5], allPips[6]],
            ),
          ],
        ),
      );

    case 8:
      // Pattern: 3 top, 2 middle, 3 bottom (or simpler 3-2-3)
       return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row( // Top 3
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [allPips[0], allPips[1], allPips[2]],
            ),
            Row( // Middle 2
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [allPips[3], allPips[4]],
            ),
            Row( // Bottom 3
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [allPips[5], allPips[6], allPips[7]],
            ),
          ],
        ),
      );

    case 9:
      // Pattern: 4 top, 1 middle, 4 bottom (often 2x2 top, 1 center, 2x2 bottom)
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row( // Top 4 (as two pairs)
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPipColumn([allPips[0], allPips[1]]),
                _buildPipColumn([allPips[2], allPips[3]]),
              ],
            ),
            _buildPipColumn([allPips[4]]), // Middle pip
            Row( // Bottom 4 (as two pairs)
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPipColumn([allPips[5], allPips[6]]),
                _buildPipColumn([allPips[7], allPips[8]]),
              ],
            ),
          ],
        ),
      );

    case 10:
      // Pattern: 4 top, 2 middle, 4 bottom (often 2x2 top, 2 center, 2x2 bottom)
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row( // Top 4 (as two pairs)
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPipColumn([allPips[0], allPips[1]]),
                _buildPipColumn([allPips[2], allPips[3]]),
              ],
            ),
            Row( // Middle 2
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                    _buildPipColumn([allPips[4]]),
                    _buildPipColumn([allPips[5]]),
                 ]
            ),
            Row( // Bottom 4 (as two pairs)
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPipColumn([allPips[6], allPips[7]]),
                _buildPipColumn([allPips[8], allPips[9]]),
              ],
            ),
          ],
        ),
      );
    default:
      // Fallback to Wrap for any other count (should not happen with standard deck)
      return Padding(
        padding: const EdgeInsets.all(2.0),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 1.0,
            runSpacing: 1.0,
            children: allPips,
          ),
        ),
      );
  }
}

/// Builds a mini card display.
/// ... (rest of buildMiniCard function remains the same) ...
Widget buildMiniCard({
  required CardModel card,
  required bool isSelected,
  required bool isFaded,
  double? width,
  double? height,
}) {
  const double rankFontSize = 9.0;

  return Opacity(
    opacity: isFaded ? 0.4 : 1.0,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isSelected ? Colors.blueAccent : Colors.grey.shade400,
          width: isSelected ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Stack(
        children: [
          _buildCentralSymbolArea(card, isFaded),
          Positioned(
            top: 1,
            left: 2,
            child: Text(
              card.cornerRankDisplay,
              style: TextStyle(
                color: card.displayColor.withOpacity(isFaded ? 0.7 : 1.0),
                fontWeight: FontWeight.bold,
                fontSize: rankFontSize,
              ),
            ),
          ),
          Positioned(
            bottom: 1,
            right: 2,
            child: Transform.rotate(
              angle: 3.14159, // 180 degrees
              child: Text(
                card.cornerRankDisplay,
                style: TextStyle(
                  color: card.displayColor.withOpacity(isFaded ? 0.7 : 1.0),
                  fontWeight: FontWeight.bold,
                  fontSize: rankFontSize,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}