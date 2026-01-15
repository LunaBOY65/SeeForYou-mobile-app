import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ExpiryScannerService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  // ฟังก์ชันหลักที่หน้า Camera จะเรียกใช้
  // Return: วันที่ที่เจอ (String) หรือ null ถ้าไม่เจอ
  Future<String?> processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      // 1. คำนวณ ROI (พื้นที่ตรงกลาง)
      final data = await File(imagePath).readAsBytes();
      final ui.Image image = await decodeImageFromList(data);

      final Rect roi = Rect.fromCenter(
        center: Offset(image.width.toDouble() / 2, image.height.toDouble() / 2),
        width: image.width.toDouble() * 0.8,
        height: image.height.toDouble() * 0.4,
      );

      // 2. กรอง TextBlock
      StringBuffer buffer = StringBuffer();
      for (TextBlock block in recognizedText.blocks) {
        if (roi.overlaps(block.boundingBox)) {
          buffer.write(block.text);
          buffer.write(" ");
        }
      }

      String filteredText = buffer.toString();
      if (filteredText.trim().isEmpty) return null;

      // 3. เรียก Logic การแกะวันที่
      return _extractDateFromText(filteredText);
    } catch (e) {
      debugPrint("Scanner Service Error: $e");
      return null;
    }
  }

  // แยก Logic ออกมาเป็น Private Function เพื่อความเป็นระเบียบ
  String? _extractDateFromText(String text) {
    // CLEANING
    String correctedText = text
        .toUpperCase()
        .replaceAll('O', '0')
        .replaceAll('Q', '0')
        .replaceAll('D', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('B', '8')
        .replaceAll('S', '5')
        .replaceAll('Z', '2')
        .replaceAll('G', '6');

    String spacedText = correctedText.replaceAll(RegExp(r'[.:/\-]'), ' ');
    String digitsOnly = correctedText.replaceAll(RegExp(r'[^0-9]'), '');

    // CHECK VALIDITY
    bool isValidDate(int d, int m, int y) {
      if (d < 1 || d > 31) return false;
      if (m < 1 || m > 12) return false;
      int fullYear = y;
      if (y >= 20 && y <= 99) fullYear = 2000 + y;
      if (y >= 2500) fullYear = y - 543;
      if (y >= 60 && y <= 99) fullYear = 1900 + y;
      return fullYear >= 2023 && fullYear <= 2030;
    }

    // --- ANCHOR PATTERN (Has Keywords) ---
    final keywords = [
      'EXP',
      'MFG',
      'BBE',
      'BBF',
      'BEST',
      'BEFORE',
      'DATE',
      'ผลิต',
      'หมดอายุ',
      'บริโภค',
      'ควรบริโภค',
      'Mfg',
      'NFG',
      'HFG',
      'M F G',
      'FXP',
      'E XP',
      'E X P',
      '88E',
      'B8E',
      'B B E',
      '0ATE',
      'D A T E',
    ];
    final keywordStr = keywords.join('|');
    final anchorPattern = RegExp(
      r'(' +
          keywordStr +
          r')\W{0,5}(\d{1,2}[\.\/\-\s]\d{1,2}[\.\/\-\s]\d{2,4})',
    );

    final matchesAnchor = anchorPattern.allMatches(correctedText);
    for (final match in matchesAnchor) {
      String dateRaw = match.group(2)!;
      final subParts = dateRaw.split(RegExp(r'[\.\/\-\s]'));
      if (subParts.length >= 3) {
        int d = int.tryParse(subParts[0]) ?? 0;
        int m = int.tryParse(subParts[1]) ?? 0;
        int y = int.tryParse(subParts[2]) ?? 0;
        if (isValidDate(d, m, y)) return "$d/$m/$y";
      }
    }

    // --- FALLBACK (Pure Digits) ---
    // วิธีที่ 1: กลุ่มตัวเลขติดกัน
    final digitGroups = RegExp(r'(\d{6,8})').allMatches(digitsOnly);
    for (final match in digitGroups) {
      String raw = match.group(0)!;
      List<List<int>> candidates = [];
      if (raw.length == 6) {
        int v1 = int.parse(raw.substring(0, 2));
        int v2 = int.parse(raw.substring(2, 4));
        int v3 = int.parse(raw.substring(4, 6));
        candidates.add([v1, v2, v3]);
        candidates.add([v3, v2, v1]);
      } else if (raw.length == 8) {
        int d = int.parse(raw.substring(0, 2));
        int m = int.parse(raw.substring(2, 4));
        int y = int.parse(raw.substring(4, 8));
        int yRev = int.parse(raw.substring(0, 4));
        int mRev = int.parse(raw.substring(4, 6));
        int dRev = int.parse(raw.substring(6, 8));
        candidates.add([d, m, y]);
        candidates.add([dRev, mRev, yRev]);
      }
      for (var c in candidates) {
        if (isValidDate(c[0], c[1], c[2])) return "${c[0]}/${c[1]}/${c[2]}";
      }
    }

    // วิธีที่ 2: กลุ่มตัวเลขมีวรรค
    final spacedPattern = RegExp(r'\b(\d{1,2})\s+(\d{1,2})\s+(\d{2,4})\b');
    final matchesSpaced = spacedPattern.allMatches(spacedText);
    for (final match in matchesSpaced) {
      int p1 = int.parse(match.group(1)!);
      int p2 = int.parse(match.group(2)!);
      int p3 = int.parse(match.group(3)!);
      if (isValidDate(p1, p2, p3)) return "$p1/$p2/$p3";
      if (isValidDate(p3, p2, p1)) return "$p3/$p2/$p1";
    }

    return null; // หาไม่เจอเลย
  }

  void dispose() {
    _textRecognizer.close();
  }
}
