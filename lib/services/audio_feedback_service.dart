import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// สำหรับจัดการเสียงเตือนและระบบสั่นของแอปหลักๆ
class AudioFeedbackService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ตัวแปรจับเวลาไม่ให้แอปเล่นเสียงหรือสั่นรัวเกินไป
  // จำเวลาที่สั่นเตือน เจอวันที่ ครั้งล่าสุด
  // จำเวลาที่เตือน ภาพเอียง ครั้งล่าสุด
  // เช็คว่าหน้านี้ถูกปิดไปหรือยัง (ถ้าปิดไปแล้วห้ามเล่นเสียงหรือสั่นอีก)
  DateTime? _lastVibrate;
  DateTime? _lastRotateWarning;
  bool _isDisposed = false;

  /// สั่งเตือน 3 จังหวะติดกัน ใช้เรียกใช้ซ้ำๆ ภายในคลาสนี้
  // สั่งให้มือถือสั่นแรงๆ 3 ครั้งติดกัน (ตึ๊บ-ตึ๊บ-ตึ๊บ)
  Future<void> _vibrateThreeTimes() async {
    for (int i = 0; i < 3; i++) {
      // ถ้าปิดหน้ากล้องหนีไปแล้ว ให้หยุดทำงานทันที
      if (_isDisposed) return;
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  /// เล่นเสียงไฟล์ที่กำหนด สั่งหยุดเสียงเก่าก่อนเสมอ ไม่ให้เสียงพูดตีกันฟังไม่รู้เรื่อง
  Future<void> _playSound(String fileName) async {
    if (_isDisposed) return;
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource('audio/$fileName'));
  }

  /// เล่นเสียงแนะนำการใช้งานตอนเปิดกล้องขึ้นมา เช่น กล้องพร้อมใช้งานแล้วค่ะ...
  /// จะเล่นทั้งหมด 2 รอบ โดยเว้นระยะห่างกัน 2 วินาที เผื่อผู้ใช้ฟังไม่ทันในรอบแรก
  Future<void> playIntro() async {
    try {
      if (_isDisposed) return;
      await Future.delayed(const Duration(milliseconds: 1300));

      if (_isDisposed) return;
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);

      // รอบที่ 1
      await _audioPlayer.play(AssetSource('audio/camera_is_ready.mp3'));
      await _audioPlayer.onPlayerComplete.first;

      await Future.delayed(const Duration(seconds: 2));
      if (_isDisposed) return;

      // รอบที่ 2
      await _audioPlayer.play(AssetSource('audio/camera_is_ready.mp3'));
    } catch (e) {
      debugPrint("Error playing intro audio: $e");
    }
  }

  /// สั่งหยุดเสียงทุกอย่างที่กำลังเล่นอยู่ทันที ถ้าเจอรูป หรือออกจากหน้านี้ไปแล้ว
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// สั่นเบาๆ 1 ครั้ง เพื่อบอกว่า เริ่มจับตัวหนังสือได้แล้วนะ แต่ยังไม่ใช่วันที่
  void triggerHapticLight() {
    HapticFeedback.selectionClick();
  }

  /// เมื่อ ai มั่นใจว่า เจอวันที่หมดอายุแล้ว
  /// จะสั่นเตือน แต่จะเช็คเวลาก่อนเพื่อไม่ให้เครื่องสั่นค้างถ้าระบบส่งคำสั่งมารัวๆ
  Future<void> playFoundDate() async {
    final now = DateTime.now();
    // เช็คว่าเพิ่งเล่นไปเมื่อกี้หรือเปล่า (กันรัว)
    // ถ้าเพิ่งสั่นเตือนไปไม่ถึง 3 วินาที จะข้ามไปก่อน (ป้องกันมือถือสั่นค้าง)
    if (_lastVibrate == null || now.difference(_lastVibrate!).inSeconds >= 3) {
      debugPrint(">>> FOUND! VIBRATE RAPIDLY !!! <<<");

      // ตัดเสียงพูดอื่นๆทิ้งไปเลย เพราะการเจอวันที่สำคัญที่สุด
      await stop();

      // สั่น 3 จังหวะให้ผู้ใช้รู้ตัวว่าสแกนเสร็จแล้ว
      await _vibrateThreeTimes();

      _lastVibrate = now;
    }
  }

  /// ทำงานเมื่อ ai พบว่ามุมเอียง
  /// ส่งเสียงเตือนและสั่น แต่จะหน่วงเวลาไว้ 4 วินาที ไม่ให้พูดจนน่ารำคาญ
  Future<void> playRotateWarning() async {
    final now = DateTime.now();
    // เช็คเวลาไม่ให้เตือนถี่เกินไป ถ้าเพิ่งบ่นไปไม่ถึง 4 วินาที ให้เงียบไว้ก่อน
    if (_lastRotateWarning == null ||
        now.difference(_lastRotateWarning!).inSeconds >= 4) {
      await _vibrateThreeTimes();
      // ถ้ามีเสียงอื่นเล่นอยู่อย่าเพิ่งแทรก
      if (_audioPlayer.state != PlayerState.playing) {
        debugPrint(">>> WRONG ANGLE: Playing warning sound");
        await _audioPlayer.play(AssetSource('audio/rotate_warning.mp3'));
      }
      _lastRotateWarning = now;
    }
  }

  /// เล่นเสียงเมื่อเปิดไฟฉาย
  Future<void> playFlashOn() async {
    await _playSound('flashlight_on.mp3');
  }

  /// เล่นเสียงเมื่อปิดไฟฉาย
  Future<void> playFlashOff() async {
    await _playSound('flashlight_off.mp3');
  }

  /// คืนค่า Resource
  void dispose() {
    _isDisposed = true;
    _audioPlayer.dispose();
  }
}
