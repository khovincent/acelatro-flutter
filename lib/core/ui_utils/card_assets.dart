// lib/core/ui_utils/card_assets.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui; // Untuk ui.Image
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart'
    show Rect; // Hanya untuk Rect jika diperlukan di sini
import '../models/card_model.dart'; // Kita butuh CardModel untuk key jika mau

// Variabel global untuk menyimpan gambar spritesheet yang sudah di-load
ui.Image? gDeckSpritesheet; // 'g' untuk global (opsional)

// Dimensi spritesheet dan sprite individu (PERKIRAAN AWAL, HARUS DIVERIFIKASI)
const double SHEET_WIDTH = 923.0;
const double SHEET_HEIGHT = 380.0;
const int CARDS_PER_ROW = 13;
const int SUIT_ROWS = 4;

// Perhitungan dimensi sprite individu
const double SINGLE_CARD_SPRITE_WIDTH = SHEET_WIDTH / CARDS_PER_ROW; // ~71.0
const double SINGLE_CARD_SPRITE_HEIGHT = SHEET_HEIGHT / SUIT_ROWS; // ~95.0

// Map untuk menyimpan Rect dari setiap sprite kartu
// Key bisa berupa String unik (misalnya, "H2", "SA") atau CardModel
final Map<String, Rect> gCardSpriteRects = {};

// Daftar suit sesuai urutan baris di spritesheet (atas ke bawah dari gambar Anda)
const List<String> SUIT_ORDER_IN_SHEET = [
  'Hearts',
  'Clubs',
  'Diamonds',
  'Spades',
];
// Daftar nilai sesuai urutan kolom di spritesheet (kiri ke kanan)
const List<int> VALUE_ORDER_IN_SHEET = [
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
]; // J=11, Q=12, K=13, A=14

// Fungsi untuk memuat gambar dari aset
Future<ui.Image> _loadImageFromAssets(String path) async {
  final ByteData data = await rootBundle.load(path);
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromList(Uint8List.view(data.buffer), (ui.Image img) {
    completer.complete(img);
  });
  return completer.future;
}

// Fungsi untuk menginisialisasi semua aset kartu
// Panggil ini sekali saat aplikasi dimulai (misalnya, di initState HomePage)
Future<void> initializeCardAssets() async {
  if (gDeckSpritesheet != null && gCardSpriteRects.isNotEmpty) {
    print("Card assets already initialized.");
    return; // Sudah diinisialisasi
  }

  try {
    print("Initializing card assets...");
    gDeckSpritesheet = await _loadImageFromAssets(
      'assets/images/deck_spritesheet.png',
    );
    print("Deck spritesheet loaded.");

    // Isi map gCardSpriteRects
    for (
      int suitIndex = 0;
      suitIndex < SUIT_ORDER_IN_SHEET.length;
      suitIndex++
    ) {
      String suit = SUIT_ORDER_IN_SHEET[suitIndex];
      double topY = suitIndex * SINGLE_CARD_SPRITE_HEIGHT;

      for (
        int valueIndex = 0;
        valueIndex < VALUE_ORDER_IN_SHEET.length;
        valueIndex++
      ) {
        int value = VALUE_ORDER_IN_SHEET[valueIndex];
        double leftX = valueIndex * SINGLE_CARD_SPRITE_WIDTH;

        // Buat key berdasarkan CardModel.shortName tanpa simbol suit
        // atau gunakan representasi lain yang konsisten.
        // CardModel.shortName sudah termasuk simbol suit, jadi kita buat key manual:
        String valueChar;
        if (value >= 2 && value <= 9)
          valueChar = value.toString();
        else if (value == 10)
          valueChar = 'T';
        else if (value == 11)
          valueChar = 'J';
        else if (value == 12)
          valueChar = 'Q';
        else if (value == 13)
          valueChar = 'K';
        else
          valueChar = 'A'; // value == 14

        String cardKey = "${suit[0]}$valueChar"; // Contoh: H2, CA, DT, SK

        gCardSpriteRects[cardKey] = Rect.fromLTWH(
          leftX,
          topY,
          SINGLE_CARD_SPRITE_WIDTH,
          SINGLE_CARD_SPRITE_HEIGHT,
        );
      }
    }
    print("Card sprite rects initialized. Total: ${gCardSpriteRects.length}");
    // print(gCardSpriteRects); // Untuk debugging
  } catch (e) {
    print("Error initializing card assets: $e");
    // Mungkin lempar ulang error atau tangani dengan cara lain
  }
}

// Helper untuk mendapatkan Rect berdasarkan CardModel
Rect? getSpriteRectForCard(CardModel card) {
  if (gCardSpriteRects.isEmpty) {
    print("Warning: Card sprite rects not initialized before access.");
    return null; // Atau Rect default error
  }
  String valueChar;
  if (card.value >= 2 && card.value <= 9)
    valueChar = card.value.toString();
  else if (card.value == 10)
    valueChar = 'T';
  else if (card.value == 11)
    valueChar = 'J';
  else if (card.value == 12)
    valueChar = 'Q';
  else if (card.value == 13)
    valueChar = 'K';
  else
    valueChar = 'A';

  String cardKey = "${card.suit[0]}$valueChar";
  return gCardSpriteRects[cardKey];
}
