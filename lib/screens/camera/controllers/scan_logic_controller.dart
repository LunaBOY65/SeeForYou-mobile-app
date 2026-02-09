import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:seeforyou_app/services/audio_feedback_service.dart';
import 'package:seeforyou_app/services/expiry_scanner_service.dart';

/// Controller สำหรับจัดการ Logic การ "สแกนอัตโนมัติ"
/// ทำหน้าที่: สั่งกล้องถ่ายรูป -> ส่งให้ AI ดู -> ตัดสินใจว่ารูปใช้ได้ไหม
class ScanLogicController {
  // บริการจัดการเสียงและการสั่น
  final AudioFeedbackService _feedbackService;

  // บริการ AI แกะตัวอักษร
  int _consecutiveFoundCount = 0;

  //(เป็นตัวนับ)ฟังก์ชันที่จะถูกเรียกเมื่อเจอรูปที่ใช้ได้จริงจะส่ง Path กลับไป
  final ExpiryScannerService _scannerService = ExpiryScannerService();

  // ตัวนับต้องเจอวันที่ถูกต้องติดกัน n ครั้งถึงจะยอมรับได้ (เพื่อกันพลาด)
  final Function(String path) onFound;

  // Timer ตั้งเวลาสำหรับวนลูปถ่ายภาพ
  Timer? _scanTimer;

  // บอกสถานะว่าตอนนี้ยุ่งอยู่ไหม หรือกำลังวิเคราะห์ภาพเก่าอยู่หรือรึเปล่า
  bool _isBusy = false;

  ScanLogicController(this._feedbackService, {required this.onFound});

  /// เริ่มต้นระบบ Auto Scan
  /// [controller] คือตัวคุมกล้องที่ส่งมาจากหน้า CameraScreen
  void startLoop(CameraController controller) {
    // สั่งหยุดของเก่าก่อน (เผื่อมีการเรียกซ้อน)
    stopLoop();

    debugPrint(">>> START SCAN LOOP");
    // ตั้งเวลาให้ทำงานทุกๆ 1 วินาที (ปรับเวลาได้ตรงนี้นะ)
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) async {
      await _processScan(controller);
    });
  }

  /// สั่งหยุดการสแกนทันที
  /// เมื่อได้รูปแล้ว, หรือ User กดออกจากหน้ากล้อง
  void stopLoop() {
    _scanTimer?.cancel(); // ยกเลิกตัวจับเวลา
    _scanTimer = null; // เคลียร์ค่าทิ้ง
    _isBusy = false; // ปลดล็อคสถานะ
  }

  /// คืนค่า Memory เมื่อเลิกใช้หน้านี้ถาวร
  void dispose() {
    stopLoop();
    _scannerService.dispose(); // ปิดระบบสแกนเรา
  }

  /// ไส้ในกระบวนการถ่ายและวิเคราะห์ภาพ 1 รอบ
  Future<void> _processScan(CameraController controller) async {
    // 1. เช็คความพร้อมไหม: ถ้าเครื่องยุ่งอยู่ หรือกล้องยังไม่พร้อม ให้ข้ามรอบนี้ไปเลย
    if (_isBusy || !controller.value.isInitialized) return;

    // 2. บอกขึ้นป้ายว่า "ยุ่งอยู่" ห้ามใครแทรก
    _isBusy = true;
    try {
      // 3. สั่งกล้องถ่ายรูป (จะได้ไฟล์ชั่วคราวมา)
      final imageFile = await controller.takePicture();

      // 4. ส่งรูปไปให้ AI ดู (ขั้นตอนนี้กินเวลานิดหน่อยนะ)
      final result = await _scannerService.processImageSmart(imageFile.path);

      // DEBUG SECTION
      if (result.expiryDate != null) {
        debugPrint("SCAN RESULT: Found ${result.expiryDate}");
        if (result.isWrongAngle) debugPrint("Angle: WRONG (${result.angle})");
      }

      // LOGIC ตัดสินใจตรงนี้
      if (result.expiryDate != null) {
        // [กรณี 1] ถ้า AI บอกว่า "เจอวันที่"
        if (result.isWrongAngle) {
          // ถ้าภาพเอียงเกินไป -> รีเซ็ตตัวนับ -> เตือนให้หมุน
          _consecutiveFoundCount = 0;
          _feedbackService.playRotateWarning();
        } else {
          // ถ้าภาพตรงและเจอวันที่ -> นับคะแนนความมั่นใจเพิ่ม +1
          _consecutiveFoundCount++;
          debugPrint(
            "Found: ${result.expiryDate} (Count: $_consecutiveFoundCount)",
          );

          // ถ้ามั่นใจครบ 2 ครั้งติดกัน
          if (_consecutiveFoundCount >= 2) {
            stopLoop(); // หยุดสแกน
            _feedbackService.playFoundDate(); // สั่นบอก User
            onFound(imageFile.path); // ส่งรูปกลับไปใช้งานจริง
            return; // จบการทำงานเลย ไม่ให้โค้ดด้านล่างลบรูปทิ้ง
          }
        }
      } else {
        // [กรณี 2] ไม่เจอวันที่เหมาะสมเลย
        _consecutiveFoundCount = 0; // รีเซ็ตความมั่นใจ

        // เช็ค Error ย่อยๆ เพื่อช่วยบอกทาง User
        if (result.isWrongAngle) {
          _feedbackService.playRotateWarning();
        } else if (result.hasText) {
          _feedbackService
              .triggerHapticLight(); // สั่นเบาๆ บอกว่ามีตัวหนังสือนะแต่ยังไม่เจอวันที่
        }
      }
      // 5. ลบไฟล์ขยะทิ้ง
      // ถ้าโค้ดวิ่งมาถึงบรรทัดนี้ แปลว่ารูปนี้ยังไม่ผ่านนะ
      // ต้องลบทิ้งเพื่อไม่ให้เมมเต็ม
      try {
        await File(imageFile.path).delete();
      } catch (_) {}
    } catch (e) {
      debugPrint("Scan Loop Error: $e");
    } finally {
      // 6. เสร็จงานรอบนี้แล้ว รอบหน้าเข้ามาใหม่ได้
      if (_scanTimer != null) {
        _isBusy = false;
      }
    }
  }
}
