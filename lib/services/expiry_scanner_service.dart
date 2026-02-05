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
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      // ตรวจสอบเบื้องต้นว่าพบข้อความใดๆ ในภาพหรือไม่
      bool foundAnyText = recognizedText.blocks.isNotEmpty;

      // ============================================================
      // Step 1 : ตรวจสอบความเอียงของภาพรวม (Angle Detection)
      // ============================================================
      bool globalWrongAngle = false;

      if (foundAnyText) {
        int badAngleCount = 0;
        int totalBlocks = 0;

        for (TextBlock block in recognizedText.blocks) {
          // ข้าม Block ขนาดเล็กที่อาจเป็น Noise
          if (block.text.length < 3) continue;

          totalBlocks++;

          // คำนวณองศาจากจุดมุมซ้ายบน (p1) และขวาบน (p2)
          final corners = block.cornerPoints;
          final p1 = corners[0]; // Top-Left
          final p2 = corners[1]; // Top-Right

          // คำนวณมุม: atan2(deltaY, deltaX) * 180 / PI
          double angle = atan2(p2.y - p1.y, p2.x - p1.x) * 180 / pi;

          // หากมุมเอียงเกิน 20 องศา + หรือ - ถือว่าไม่ปกติ
          if (angle.abs() > 20) {
            badAngleCount++;
          }
        }

        // หาก Block เกิน 50% เอียงผิดปกติ ให้ถือว่าภาพรวมเอียง
        if (totalBlocks > 0 && (badAngleCount / totalBlocks) > 0.5) {
          globalWrongAngle = true;
        }
      }

      // ============================================================
      // Step 2 : ตรวจสอบทีละบรรทัด
      // ป้องกัน OCR รวมบรรทัดวันที่กับข้อความอื่น อาจทำให้เพี้ยน
      // ============================================================
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          bool lineIsAngled = _isAngled(line.cornerPoints);

          double currentAngle = 0;
          if (line.cornerPoints.length >= 2) {
            final p1 = line.cornerPoints[0];
            final p2 = line.cornerPoints[1];
            currentAngle = atan2(p2.y - p1.y, p2.x - p1.x) * 180 / pi;
          }

          // ส่งข้อความในบรรทัดนั้นไปตรวจสอบหารูปแบบวันที่
          String? dateInLine = _extractDateFromText(line.text);

          if (dateInLine != null) {
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

      // หากภาพรวมเอียงมาก และยังหาไม่เจอใน Step 2 ให้แจ้งเตือนเรื่องมุมทันที
      if (globalWrongAngle) {
        return ScanResult(hasText: true, isWrongAngle: true);
      }

      // ============================================================
      // Step 3 : รวมข้อความทั้งภาพ
      // ถ้าหาทีละบรรทัดไม่เจอ ให้นำทุก Block มาต่อกันแล้วค้นหาอีกครั้ง
      // ============================================================
      StringBuffer buffer = StringBuffer();
      for (TextBlock block in recognizedText.blocks) {
        buffer.write(block.text);
        buffer.write(" ");
      }

      String filteredText = buffer.toString();

      if (filteredText.trim().isEmpty) {
        return ScanResult(hasText: false);
      }

      String? date = _extractDateFromText(filteredText);

      return ScanResult(
        expiryDate: date,
        hasText: foundAnyText,
        isWrongAngle: globalWrongAngle, // ใช้ค่าที่คำนวณไว้จาก Step 1
      );
    } catch (e) {
      debugPrint("Scanner Service Error: $e");
      return ScanResult(hasText: false);
    }
  }

  /// คำนวณ โดยตรวจสอบว่าพิกัดมุมข้อความเอียงเกินเกณฑ์ที่กำหนด 20 องศา ไหม
  bool _isAngled(List<Point<int>> corners) {
    if (corners.length < 2) return false;
    final p1 = corners[0]; // Top-Left
    final p2 = corners[1]; // Top-Right

    double angle = atan2(p2.y - p1.y, p2.x - p1.x) * 180 / pi;

    return angle.abs() > 20;
  }

  /// แกะ และตรวจสอบความถูกต้องของวันที่จากข้อความ Raw Text
  String? _extractDateFromText(String text) {
    // -----------------------------------------
    // Part 1: DATA CLEANING (เตรียมข้อมูลให้พร้อม)
    // -----------------------------------------
    // OCR มักอ่านตัวเลขผิดเป็นตัวอักษรเมื่อ font ไม่ชัด หรือพื้นหลังลาย
    // แนวคิดคือ แปลงตัวอักษรที่หน้าตาคล้ายตัวเลขกลับมาเป็นตัวเลข เพื่อให้ Regex จับ pattern ได้ดีขึ้น
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

    // สร้าง String 2 แบบไว้ใช้ตรวจสอบ:
    // 1. spacedText: แปลงตัวคั่นทุกชนิด (. / - :) เป็น "เว้นวรรค" เพื่อให้แยก word ง่าย
    String spacedText = correctedText.replaceAll(RegExp(r'[.:/\-]'), ' ');
    // 2. digitsOnly: เก็บเฉพาะตัวเลขล้วน เอาไว้เช็คเคสวันที่ที่พิมพ์ติดกันเป็นพืด
    String digitsOnly = correctedText.replaceAll(RegExp(r'[^0-9]'), '');

    // ตรวจสอบว่าตัวเลขชุดนั้น เป็นวันที่มีอยู่จริงไหม?
    // ต้องอยู่ในช่วงปีที่สมเหตุสมผล เพื่อกันเลขมั่วๆ
    bool isValidDate(int d, int m, int y) {
      if (d < 1 || d > 31) return false;
      if (m < 1 || m > 12) return false;

      int fullYear = y;
      // แปลงปี 2 หลัก (เช่น 23 -> 2023)
      if (y >= 20 && y <= 99) fullYear = 2000 + y;
      // แปลงปี พ.ศ. (เช่น 2566 -> 2023)
      if (y >= 2500) fullYear = y - 543;
      // แปลงปีเก่า (19xx)
      if (y >= 60 && y <= 99) fullYear = 1900 + y;

      // ช่วงปีที่ยอมรับได้
      return fullYear >= 2018 && fullYear <= 2032;
    }

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

    for (final match in matchesLoose) {
      // ไม่รู้ Format DD/MM หรือ MM/DD จึงแปลงและตรวจสอบความถูกต้อง
      // โดยลองสลับตำแหน่งดู ว่าแบบไหนสลับแล้วเป็นดูเป็น วันที่ที่ถูกต้อง ก็เอาอันนั้น

      String p1 = match.group(1)!;
      String p2 = match.group(2)!;
      String p3 = match.group(3)!;

      int? v1 = int.tryParse(p1);
      int? v2 = int.tryParse(p2);
      int? v3 = int.tryParse(p3);

      if (v1 != null && v2 != null && v3 != null) {
        if (isValidDate(v1, v2, v3)) return "$v1/$v2/$v3"; // d m y
        if (isValidDate(v2, v1, v3)) return "$v2/$v1/$v3"; // m d y
        if (isValidDate(v3, v2, v1)) return "$v3/$v2/$v1"; // y m d
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
    for (final match in matchesAnchor) {
      String dateRaw = match.group(2)!;
      final subParts = dateRaw.split(RegExp(r'[\.\/\-\s]'));
      if (subParts.length >= 3) {
        int d = int.tryParse(subParts[0]) ?? 0;
        int m = int.tryParse(subParts[1]) ?? 0;
        int y = int.tryParse(subParts[2]) ?? 0;

        // ถ้าเจอผ่าน Keyword มั่นใจได้ระดับนึง แต่ก็เช็ค Valid อีกรอบเพื่อความชัวร์
        if (isValidDate(d, m, y)) return "$d/$m/$y";
      }
    }

    // -----------------------------------------
    // Part 4: STRATEGY 3 - Fallback กรณีตัวเลขล้วน
    // -----------------------------------------
    // กันสำหรับ format ที่ไม่มีตัวคั่น เช่นพิมพ์แบบ dot matrix จางๆ
    //  231025 (23 ต.ค. 25) หรือ 20231023

    // 4.1 กลุ่มตัวเลขติดๆกัน เช่น 201225 (6 หรือ 8 หลัก)
    final digitGroups = RegExp(r'(\d{6,8})').allMatches(digitsOnly);
    for (final match in digitGroups) {
      String raw = match.group(0)!;
      List<List<int>> candidates = [];

      if (raw.length == 6) {
        // ตัดแบ่ง 2-2-2 (dd mm yy หรือ yy mm dd)
        int v1 = int.parse(raw.substring(0, 2));
        int v2 = int.parse(raw.substring(2, 4));
        int v3 = int.parse(raw.substring(4, 6));
        candidates.add([v1, v2, v3]); // d m y
        candidates.add([v3, v2, v1]); // y m d
      } else if (raw.length == 8) {
        // ตัดแบ่ง 2-2-4 หรือ 4-2-2 (ddmmyyyy หรือ yyyymmdd)
        int d = int.parse(raw.substring(0, 2));
        int m = int.parse(raw.substring(2, 4));
        int y = int.parse(raw.substring(4, 8));

        int yRev = int.parse(raw.substring(0, 4));
        int mRev = int.parse(raw.substring(4, 6));
        int dRev = int.parse(raw.substring(6, 8));

        candidates.add([d, m, y]);
        candidates.add([dRev, mRev, yRev]);
      }

      // วนลูปเช็คว่าส่วนที่ผ่านอันไหนเป็นวันที่จริง
      for (var c in candidates) {
        if (isValidDate(c[0], c[1], c[2])) return "${c[0]}/${c[1]}/${c[2]}";
      }
    }

    // 4.2 กรณีมีเว้นวรรค แต่ไม่มีเครื่องหมายอื่น (23 10 2023)
    final spacedPattern = RegExp(r'\b(\d{1,2})\s+(\d{1,2})\s+(\d{2,4})\b');
    final matchesSpaced = spacedPattern.allMatches(spacedText);
    for (final match in matchesSpaced) {
      int p1 = int.parse(match.group(1)!);
      int p2 = int.parse(match.group(2)!);
      int p3 = int.parse(match.group(3)!);

      if (isValidDate(p1, p2, p3)) return "$p1/$p2/$p3";
      if (isValidDate(p3, p2, p1)) return "$p3/$p2/$p1";
    }

    // ถ้าลองทุกอันแล้วยังไม่เจอ ยอมแพ้ return null
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
