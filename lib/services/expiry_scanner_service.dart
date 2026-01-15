import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Class นี้เพื่อส่งสถานะกลับไปบอก UI
class ScanResult {
  final String? expiryDate; // วันที่ (ถ้าเจอ)
  final bool hasText; // มีตัวหนังสือในภาพไหม (ใช้ทำเสียงติ๊กๆ)
  final bool isWrongAngle;
  final Rect?
  boundingBox; // เก็บตำแหน่งกรอบสี่เหลี่ยม (x, y, width, height)
  final double? angle; // [เพิ่ม] เก็บองศาที่วัดได้จริง

  ScanResult({
    this.expiryDate,
    this.hasText = false,
    this.isWrongAngle = false,
    this.boundingBox,
    this.angle,
  });
}

class ExpiryScannerService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  // ฟังก์ชันหลักที่หน้า Camera จะเรียกใช้
  // Return: วันที่ที่เจอ (String) หรือ null ถ้าไม่เจอ
  Future<ScanResult> processImageSmart(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      //เช็คว่าภาพนี้มีตัวหนังสือบ้างไหม
      bool foundAnyText = recognizedText.blocks.isNotEmpty;

      // [เพิ่ม] Logic เช็คทิศทาง (9-3 นาฬิกา)
      // ถ้ามีข้อความ แต่ข้อความส่วนใหญ่ "เอียง" หรือ "เป็นแนวตั้ง" ให้แจ้งเตือน User ก่อน
      bool globalWrongAngle = false;

      if (foundAnyText) {
        int badAngleCount = 0;
        int totalBlocks = 0;

        for (TextBlock block in recognizedText.blocks) {
          // ข้าม block เล็กๆ น้อยๆ ที่อาจเป็น noise
          if (block.text.length < 3) continue;

          totalBlocks++;
          // คำนวณองศาจากจุดมุมซ้ายบน (0) และขวาบน (1)
          final corners = block.cornerPoints;
          // จุด 0 คือ Top-Left, จุด 1 คือ Top-Right
          final p1 = corners[0];
          final p2 = corners[1];

          // หาองศา
          // atan2(deltaY, deltaX) * 180 / PI
          double angle = atan2(p2.y - p1.y, p2.x - p1.x) * 180 / pi;

          // ถ้ามุมมากกว่า 20 หรือน้อยกว่า -20 แปลว่า "เอียง" หรือ "แนวตั้ง"
          if (angle.abs() > 20) {
            badAngleCount++;
          }
        }

        // ถ้าข้อความส่วนใหญ่ (เกิน 50%) เอียงผิดมุม ให้ตีว่าเป็น Wrong Angle ทันที
        if (totalBlocks > 0 && (badAngleCount / totalBlocks) > 0.5) {
          // แค่จำไว้ว่าภาพรวมมันเอียงนะ
          globalWrongAngle = true;
        }
      }

      // 1. ลองเช็ค "ทีละบรรทัด" ก่อน (Line-by-Line Strategy)
      // เพราะ OCR มักจะแยกบรรทัดวันที่ออกมาเดี่ยวๆ การเอาไปรวมกันอาจทำให้อ่านผิด
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          bool lineIsAngled = _isAngled(line.cornerPoints);

          double currentAngle = 0;
          if (line.cornerPoints.length >= 2) {
            final p1 = line.cornerPoints[0];
            final p2 = line.cornerPoints[1];
            currentAngle = atan2(p2.y - p1.y, p2.x - p1.x) * 180 / pi;
          }

          // ส่งเฉพาะบรรทัดนี้ไปตรวจ
          String? dateInLine = _extractDateFromText(line.text);
          if (dateInLine != null) {
            return ScanResult(
              expiryDate: dateInLine,
              hasText: true,
              isWrongAngle: lineIsAngled,
              boundingBox: line.boundingBox, // [เพิ่ม] ส่งกรอบสี่เหลี่ยมกลับไป
              angle: currentAngle, // [เพิ่ม] ส่งองศากลับไป
            );
          }
        }
      }

      if (globalWrongAngle) {
        return ScanResult(hasText: true, isWrongAngle: true);
      }

      // 2. ถ้าหาทีละบรรทัดไม่เจอ ค่อยเอามาต่อกันแบบเดิม
      StringBuffer buffer = StringBuffer();
      for (TextBlock block in recognizedText.blocks) {
        // เอาเงื่อนไข ROI ออก เพื่อให้อ่านทั้งภาพ
        buffer.write(block.text);
        buffer.write(" ");
      }

      String filteredText = buffer.toString();

      // [เพิ่ม] Logic การ return แบบใหม่
      if (filteredText.trim().isEmpty) {
        return ScanResult(hasText: false);
      }

      String? date = _extractDateFromText(filteredText);
      return ScanResult(
        expiryDate: date,
        hasText: foundAnyText,
        isWrongAngle: globalWrongAngle, // ใช้ค่าที่คำนวณไว้ตอนต้น
      );
    } catch (e) {
      debugPrint("Scanner Service Error: $e");
      return ScanResult(hasText: false);
    }
  }

  // ฟังก์ชันช่วยคำนวณองศา
  bool _isAngled(List<Point<int>> corners) {
    if (corners.length < 2) return false;
    final p1 = corners[0]; // Top-Left
    final p2 = corners[1]; // Top-Right

    // สูตรหาองศา
    double angle = atan2(p2.y - p1.y, p2.x - p1.x) * 180 / pi;

    // ถ้าเอียงเกิน 20 องศา (ทั้งบวกและลบ) ถือว่าผิดมุม
    return angle.abs() > 20;
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
      return fullYear >= 2018 && fullYear <= 2032;
    }

    // Pattern: เลข 1-2 หลัก + (ตัวคั่น) + เลข 1-2 หลัก + (ตัวคั่น) + เลข 2-4 หลัก
    // รองรับ dd/mm/yy, dd.mm.yy, dd mm yy
    final loosePattern = RegExp(
      r'\b(\d{1,2})[\.\/\-\s]?(\d{1,2})[\.\/\-\s]?(\d{2,4})\b',
    );
    final matchesLoose = loosePattern.allMatches(correctedText);

    for (final match in matchesLoose) {
      String p1 = match.group(1)!;
      String p2 = match.group(2)!;
      String p3 = match.group(3)!;

      int? v1 = int.tryParse(p1);
      int? v2 = int.tryParse(p2);
      int? v3 = int.tryParse(p3);

      if (v1 != null && v2 != null && v3 != null) {
        // ลองสลับตำแหน่ง (วัน/เดือน/ปี)
        if (isValidDate(v1, v2, v3)) return "$v1/$v2/$v3"; // d m y
        if (isValidDate(v2, v1, v3)) return "$v2/$v1/$v3"; // m d y
        if (isValidDate(v3, v2, v1)) return "$v3/$v2/$v1"; // y m d
      }
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
    // กรณี 1: กลุ่มตัวเลขติดกัน
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
