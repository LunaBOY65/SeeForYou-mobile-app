import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:seeforyou_app/services/audio_feedback_service.dart';
import 'package:seeforyou_app/services/expiry_scanner_service.dart';

class ScanLogicController {
  // รับ Service เข้ามา (Dependency Injection) เพื่อช่วยจัดการเรื่องเสียง
  final AudioFeedbackService _feedbackService;

  // สร้าง Scanner Service ของตัวเอง
  final ExpiryScannerService _scannerService = ExpiryScannerService();

  Timer? _scanTimer;
  bool _isScanning = false;

  ScanLogicController(this._feedbackService);

  /// เริ่มต้น Loop การสแกนอัตโนมัติ
  void startLoop(CameraController controller) {
    // ป้องกันกามมทม าทมฟๆนรเปิด Loop ซ้อนกัน
    stopLoop();

    debugPrint(">>> START SCAN LOOP");
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) async {
      await _processScan(controller);
    });
  }

  /// หยุด Loop เช่น ตอนจะกดถ่ายรูปจริง หรือออกจากหน้า
  void stopLoop() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _isScanning = false;
  }

  /// คืนค่า Resource
  void dispose() {
    stopLoop();
    _scannerService.dispose();
  }

  /// Logic ภายในสำหรับการถ่ายและวิเคราะห์ภาพ 1 ครั้ง
  Future<void> _processScan(CameraController controller) async {
    // 1. ตรวจสอบสถานะความพร้อม
    if (_isScanning || !controller.value.isInitialized) return;

    _isScanning = true; // Lock
    try {
      // 2. ถ่ายภาพเบื้องหลัง (XFile)
      final imageFile = await controller.takePicture();

      // 3. ส่งวิเคราะห์ (AI)
      final result = await _scannerService.processImageSmart(imageFile.path);

      // --- DEBUG SECTION ---
      if (result.expiryDate != null) {
        debugPrint("SCAN RESULT: Found ${result.expiryDate}");
        if (result.isWrongAngle) debugPrint("Angle: WRONG (${result.angle})");
      }

      // 4. สั่ง Feedback (เรียกใช้ Service ที่รับมา)
      if (result.expiryDate != null) {
        if (result.isWrongAngle) {
          _feedbackService.playRotateWarning();
        } else {
          _feedbackService.playFoundDate();
        }
      } else if (result.isWrongAngle) {
        _feedbackService.playRotateWarning();
      } else if (result.hasText) {
        _feedbackService.triggerHapticLight();
      }

      // 5. ลบไฟล์ทิ้งทันที
      final file = File(imageFile.path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Scan Loop Error: $e");
    } finally {
      _isScanning = false; // Unlock
    }
  }
}
