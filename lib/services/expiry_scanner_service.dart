import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// โมเดลสำหรับส่งผลลัพธ์การสแกนกลับไปยัง UI
/// ประกอบด้วยข้อมูลวันที่ที่พบ สถานะการตรวจจับข้อความ และข้อมูลตำแหน่ง/องศา
class ScanResult {
  /// วันที่วันหมดอายุที่แกะได้ (Format หรือ String ที่ต้องการ) หรือ null หากไม่พบ
  final String? expiryDate;

  /// พบข้อความในภาพหรือไม่ (ใช้สำหรับตรวจสอบเบื้องต้น หรือทำ Haptic Feedback)
  final bool hasText;

  /// ตรวจพบว่ามุมกล้องเอียงหรือเป็นแนวตั้งเกินไปหรือไม่
  final bool isWrongAngle;

  /// กรอบสี่เหลี่ยมระบุตำแหน่งของข้อความที่พบ (x, y, width, height)
  final Rect? boundingBox;

  /// องศาความเอียงของข้อความที่วัดได้จริง
  final double? angle;

  ScanResult({
    this.expiryDate,
    this.hasText = false,
    this.isWrongAngle = false,
    this.boundingBox,
    this.angle,
  });
}

/// Service สำหรับจัดการการสแกนวันหมดอายุด้วย ML Kit
class ExpiryScannerService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// ประมวลผลภาพเพื่อค้นหาวันหมดอายุและตรวจสอบความเอียงของภาพ
  /// [imagePath] - ที่อยู่ไฟล์รูปภาพ
  /// Return [ScanResult] ที่ประกอบด้วยวันที่ (ถ้ามี) และสถานะต่างๆ
  Future<ScanResult> processImageSmart(String imagePath) async {
    // เริ่มจับเวลาประมวลผล (เหมาะสำหรับใส่กราฟ Performance ในเล่มโปรเจค)
    final stopwatch = Stopwatch()..start();
    debugPrint("\n=======================================================");
    debugPrint("[OCR_PIPELINE] START -> Processing Image...");
    debugPrint("[OCR_PIPELINE] File Path: $imagePath");
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      debugPrint(
        "[OCR_PIPELINE] Text Blocks Detected: ${recognizedText.blocks.length}",
      );

      // ============================================================
      // Step 1 : วนลูปตรวจสอบทีละบรรทัด (หาทั้งวันที่ และเช็คมุมไปพร้อมกัน)
      // ============================================================
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          // คำนวณมุมของบรรทัดนี้
          double currentAngle = _calculateAngle(line.cornerPoints);
          bool lineIsAngled = currentAngle.abs() > 20;

          // ส่งข้อความในบรรทัดนั้นไปตรวจสอบหารูปแบบวันที่
          String? dateInLine = _extractDateFromText(line.text);

          if (dateInLine != null) {
            stopwatch.stop();
            debugPrint(
              "[RESULT] SUCCESS (Line-by-Line) -> Extracted Date: $dateInLine",
            );
            debugPrint(
              "[OCR_PIPELINE] END -> Processing Time: ${stopwatch.elapsedMilliseconds} ms",
            );
            debugPrint(
              "=======================================================\n",
            );
            // หากเจอวันที่ คืนค่าทันที
            return ScanResult(
              expiryDate: dateInLine,
              hasText: true,
              isWrongAngle: lineIsAngled,
              boundingBox: line.boundingBox,
              angle: currentAngle,
            );
          }
        }
      }

      // ============================================================
      // Step 2 : Fallback รวมข้อความทั้งภาพ
      // ถ้าหาทีละบรรทัดไม่เจอ ให้นำทุก Block มาต่อกันแล้วค้นหาอีกครั้ง
      // ============================================================
      debugPrint(
        "[OCR_PIPELINE] Line-by-Line failed. Switching to Global Fallback strategy.",
      );
      StringBuffer buffer = StringBuffer();
      for (TextBlock block in recognizedText.blocks) {
        buffer.write(block.text);
        buffer.write(" ");
      }

      String filteredText = buffer.toString();

      if (filteredText.trim().isEmpty) {
        stopwatch.stop();
        debugPrint("[OCR_PIPELINE] No valid text found in image.");
        return ScanResult(hasText: false);
      }

      String? date = _extractDateFromText(filteredText);

      stopwatch.stop();
      if (date != null) {
        debugPrint(
          "[RESULT] SUCCESS (Global Fallback) -> Extracted Date: $date",
        );
      } else {
        debugPrint("[RESULT] FAILED -> No valid expiry date format found.");
      }
      debugPrint(
        "[OCR_PIPELINE] END -> Processing Time: ${stopwatch.elapsedMilliseconds} ms",
      );
      debugPrint("=======================================================\n");

      return ScanResult(expiryDate: date, hasText: true, isWrongAngle: false);
    } catch (e) {
      debugPrint("[ERROR] Scanner Service Exception: $e");
      return ScanResult(hasText: false);
    }
  }

  /// Helper: คำนวณองศาจากจุดมุม
  double _calculateAngle(List<Point<int>> corners) {
    if (corners.length < 2) return 0;
    final p1 = corners[0]; // Top-Left
    final p2 = corners[1]; // Top-Right
    return atan2(p2.y - p1.y, p2.x - p1.x) * 180 / pi;
  }

  /// คำนวณ โดยตรวจสอบว่าพิกัดมุมข้อความเอียงเกินเกณฑ์ที่กำหนด 20 องศา ไหม
  bool _isAngled(List<Point<int>> corners) {
    return _calculateAngle(corners).abs() > 20;
  }

  /// แกะ และตรวจสอบความถูกต้องของวันที่จากข้อความ Raw Text
  String? _extractDateFromText(String text) {
    // -----------------------------------------
    // Part 1: DATA CLEANING (เตรียมข้อมูลให้พร้อม)
    // -----------------------------------------
    // OCR มักอ่านตัวเลขผิดเป็นตัวอักษรเมื่อ font ไม่ชัด หรือพื้นหลังลาย
    // แนวคิดคือ แปลงตัวอักษรที่หน้าตาคล้ายตัวเลขกลับมาเป็นตัวเลข เพื่อให้ Regex จับ pattern ได้ดีขึ้น

    // ลบขึ้นบรรทัดใหม่เพื่อให้แสดงผลใน Console บรรทัดเดียวอ่านง่ายๆ
    String consoleRawText = text.replaceAll('\n', ' ').trim();
    if (consoleRawText.length > 50) {
      consoleRawText = "${consoleRawText.substring(0, 50)}...";
    }
    debugPrint("[DATA_CLEANING] Input Text: '$consoleRawText'");
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

    // -----------------------------------------
    // Part 2: STRATEGY 1 - Loose Pattern หาตามโครงสร้างทั่วไป
    // -----------------------------------------
    // หาวันที่ที่มีรูปแบบชัดเจน (มีตัวคั่น) โดยไม่ง้อ Keyword
    // รูปแบบ [เลข 1-2 หลัก] + [ตัวคั่น] + [เลข 1-2 หลัก] + [ตัวคั่น] + [ปี]
    // รองรับ dd/mm/yy, dd.mm.yy, dd mm yy
    final loosePattern = RegExp(
      r'\b(\d{1,2})[\.\/\-\s]?(\d{1,2})[\.\/\-\s]?(\d{2,4})\b',
    );
    final matchesLoose = loosePattern.allMatches(correctedText);

    if (matchesLoose.isNotEmpty) {
      debugPrint(
        "[STRATEGY_1] Found ${matchesLoose.length} matches using Loose Pattern.",
      );
    }

    for (final match in matchesLoose) {
      // ไม่รู้ Format DD/MM หรือ MM/DD จึงแปลงและตรวจสอบความถูกต้อง
      // โดยลองสลับตำแหน่งดู ว่าแบบไหนสลับแล้วเป็นดูเป็น วันที่ที่ถูกต้อง ก็เอาอันนั้น

      int? v1 = int.tryParse(match.group(1)!);
      int? v2 = int.tryParse(match.group(2)!);
      int? v3 = int.tryParse(match.group(3)!);

      // ใช้ Helper ตรวจสอบสลับตำแหน่งให้อัตโนมัติ
      String? result = _checkPermutations(v1, v2, v3);
      if (result != null) {
        debugPrint("[STRATEGY_1] Match Validated: $result");
        return result;
      }
    }

    // --- PART 3: STRATEGY 2 - Anchor Pattern (Keyword Based) ---
    // ค้นหาโดยอ้างอิงจาก Keyword เช่น EXP, MFG, BBE

    // -----------------------------------------
    // Part 3: STRATEGY 2 - Anchor Pattern หาจากคำนำหน้า
    // -----------------------------------------
    // เพิ่มความแม่นยำขึ้้นโดยหา EXP, MFG, BBE ก่อน
    // ถ้าเจอคำพวกนี้ ตัวเลขวันที่จะตามหลังมาแน่
    final keywords = [
      'EXP',
      'MFG',
      'BBE',
      'BBF',
      'BEST',
      'BEFORE',
      'DATE',
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
      'D A T E',
    ];
    final keywordStr = keywords.join('|');

    // Regex
    // [Keyword] + [เว้นว่าง 0-5 ตัว] + [Date Pattern]
    // \W{0,5} เอาไว้กันกรณีมีจุด หรือขีด คั่นกลางระหว่าง EXP กับวันที่
    final anchorPattern = RegExp(
      r'(' +
          keywordStr +
          r')\W{0,5}(\d{1,2}[\.\/\-\s]\d{1,2}[\.\/\-\s]\d{2,4})',
    );

    final matchesAnchor = anchorPattern.allMatches(correctedText);
    if (matchesAnchor.isNotEmpty) {
      debugPrint(
        "[STRATEGY_2] Found ${matchesAnchor.length} matches using Keyword Anchor Pattern.",
      );
    }

    for (final match in matchesAnchor) {
      String dateRaw = match.group(2)!;
      final subParts = dateRaw.split(RegExp(r'[\.\/\-\s]'));
      if (subParts.length >= 3) {
        // ใช้ Helper ตัวเดิมช่วยเช็ค
        int? v1 = int.tryParse(subParts[0]);
        int? v2 = int.tryParse(subParts[1]);
        int? v3 = int.tryParse(subParts[2]);

        if (_isValidDate(v1 ?? 0, v2 ?? 0, v3 ?? 0)) {
          String result = "$v1/$v2/$v3";
          debugPrint("[STRATEGY_2] Match Validated: $result");
          return result;
        }
      }
    }

    // -----------------------------------------
    // Part 4: STRATEGY 3 - Fallback กรณีตัวเลขล้วน
    // -----------------------------------------
    // กันสำหรับ format ที่ไม่มีตัวคั่น เช่นพิมพ์แบบ dot matrix จางๆ
    //  231025 (23 ต.ค. 25) หรือ 20231023

    // 4.1 กลุ่มตัวเลขติดๆกัน เช่น 201225 (6 หรือ 8 หลัก)
    final digitGroups = RegExp(r'(\d{6,8})').allMatches(digitsOnly);
    if (digitGroups.isNotEmpty) {
      debugPrint(
        "[STRATEGY_3] Testing ${digitGroups.length} digit-only groups (Fallback).",
      );
    }

    for (final match in digitGroups) {
      String raw = match.group(0)!;

      if (raw.length == 6) {
        // ตัดแบ่ง 2-2-2 (dd mm yy หรือ yy mm dd)
        int v1 = int.parse(raw.substring(0, 2));
        int v2 = int.parse(raw.substring(2, 4));
        int v3 = int.parse(raw.substring(4, 6));
        if (_isValidDate(v1, v2, v3)) {
          debugPrint("[STRATEGY_3] Match Validated (6-digits): $v1/$v2/$v3");
          return "$v1/$v2/$v3";
        }
        if (_isValidDate(v3, v2, v1)) {
          debugPrint(
            "[STRATEGY_3] Match Validated (6-digits reversed): $v3/$v2/$v1",
          );
          return "$v3/$v2/$v1";
        }
      } else if (raw.length == 8) {
        // ตัดแบ่ง 2-2-4 หรือ 4-2-2 (ddmmyyyy หรือ yyyymmdd)
        int d = int.parse(raw.substring(0, 2));
        int m = int.parse(raw.substring(2, 4));
        int y = int.parse(raw.substring(4, 8));

        if (_isValidDate(d, m, y)) {
          debugPrint("[STRATEGY_3] Match Validated (8-digits): $d/$m/$y");
          return "$d/$m/$y";
        }

        // yyyymmdd
        int yRev = int.parse(raw.substring(0, 4));
        int mRev = int.parse(raw.substring(4, 6));
        int dRev = int.parse(raw.substring(6, 8));
        if (_isValidDate(dRev, mRev, yRev)) {
          debugPrint(
            "[STRATEGY_3] Match Validated (8-digits reversed): $dRev/$mRev/$yRev",
          );
          return "$dRev/$mRev/$yRev";
        }
      }
    }

    // 4.2 กรณีมีเว้นวรรค แต่ไม่มีเครื่องหมายอื่น (23 10 2023)
    final spacedPattern = RegExp(r'\b(\d{1,2})\s+(\d{1,2})\s+(\d{2,4})\b');
    final matchesSpaced = spacedPattern.allMatches(spacedText);
    for (final match in matchesSpaced) {
      int p1 = int.parse(match.group(1)!);
      int p2 = int.parse(match.group(2)!);
      int p3 = int.parse(match.group(3)!);

      String? result = _checkPermutations(p1, p2, p3);
      if (result != null) {
        debugPrint("[STRATEGY_3] Spaced format Validated: $result");
        return result;
      }
    }

    // ถ้าลองทุกอันแล้วยังไม่เจอ ยอมแพ้ return null
    return null;
  }

  /// Helper: ลองสลับตำแหน่งตัวเลขเพื่อหา Format ที่ถูกต้อง (d/m/y หรือ m/d/y หรือ y/m/d)
  String? _checkPermutations(int? v1, int? v2, int? v3) {
    if (v1 == null || v2 == null || v3 == null) return null;
    if (_isValidDate(v1, v2, v3)) return "$v1/$v2/$v3"; // d m y
    if (_isValidDate(v2, v1, v3)) return "$v2/$v1/$v3"; // m d y
    if (_isValidDate(v3, v2, v1)) return "$v3/$v2/$v1"; // y m d
    return null;
  }

  /// Logic ตรวจสอบว่าตัวเลขชุดนั้น เป็นวันที่มีอยู่จริงไหม
  bool _isValidDate(int d, int m, int y) {
    if (d < 1 || d > 31) return false;
    if (m < 1 || m > 12) return false;

    int fullYear = y;
    if (y >= 20 && y <= 99) fullYear = 2000 + y;
    if (y >= 2500) fullYear = y - 543;
    if (y >= 60 && y <= 99) fullYear = 1900 + y;

    return fullYear >= 2018 && fullYear <= 2032;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
