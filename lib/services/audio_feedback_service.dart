import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioFeedbackService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ตัวแปรจับเวลา Debounce
  DateTime? _lastVibrate;
  DateTime? _lastRotateWarning;
  bool _isDisposed = false;

  /// เล่นเสียง Intro รอบแรก และวนซ้ำถ้า user ยังไม่ทำอะไร
  Future<void> playIntro() async {
    try {
      if (_isDisposed) return;
      await Future.delayed(const Duration(milliseconds: 1500));
      if (_isDisposed) return;

      await _audioPlayer.setReleaseMode(ReleaseMode.stop);

      // รอบที่ 1
      await _audioPlayer.play(AssetSource('audio/camera_is_ready.mp3'));
      await _audioPlayer.onPlayerComplete.first;

      await Future.delayed(const Duration(seconds: 3));
      if (_isDisposed) return;

      // รอบที่ 2
      await _audioPlayer.play(AssetSource('audio/camera_is_ready.mp3'));
    } catch (e) {
      debugPrint("Error playing intro audio: $e");
    }
  }

  /// หยุดเสียงทุกอย่างทันที ถ้าเจอรูป หรือออกจากหน้า
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// สั่นเบาๆ เมื่อเจอ Text (แต่ยังไม่ใช่วันที่)
  void triggerHapticLight() {
    HapticFeedback.selectionClick();
  }

  ///  เมื่อเจอวันที่ถูกต้อง หยุดเสียงเก่า -> สั่นรัว -> เล่นเสียง Siren
  Future<void> playFoundDate() async {
    final now = DateTime.now();
    // เช็คว่าเพิ่งเล่นไปเมื่อกี้หรือเปล่า (กันรัว)
    if (_lastVibrate == null || now.difference(_lastVibrate!).inSeconds >= 3) {
      debugPrint(">>> FOUND! VIBRATE RAPIDLY !!! <<<");

      // หยุดเสียงพูดอื่นๆ ก่อน
      await stop();

      // สั่นเตือน
      for (int i = 0; i < 3; i++) {
        if (_isDisposed) return;
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // เล่นเสียง Siren
      if (!_isDisposed) {
        await _audioPlayer.play(AssetSource('audio/Siren.mp3'));
      }

      _lastVibrate = now;
    }
  }

  ///  เมื่อมุมผิด เล่นเสียงเตือนให้หมุน
  Future<void> playRotateWarning() async {
    final now = DateTime.now();
    // เช็คเวลาไม่ให้เตือนถี่เกินไป (ทุก 4 วิ)
    if (_lastRotateWarning == null ||
        now.difference(_lastRotateWarning!).inSeconds >= 4) {
      // สั่นเตือน
      for (int i = 0; i < 3; i++) {
        if (_isDisposed) return;
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
      }
      // ถ้ามีเสียงอื่นเล่นอยู่ (เช่น Siren) อย่าเพิ่งแทรก
      if (_audioPlayer.state != PlayerState.playing) {
        debugPrint(">>> WRONG ANGLE: Playing warning sound");
        await _audioPlayer.play(AssetSource('audio/rotate_warning.mp3'));
      }
      _lastRotateWarning = now;
    }
  }

  /// เล่นเสียงเมื่อเปิดไฟฉาย
  Future<void> playFlashOn() async {
    if (_isDisposed) return;
    await _audioPlayer.stop(); // ตัดเสียงเก่า (ถ้ามี) เพื่อให้เสียง UI ชัดเจน
    await _audioPlayer.play(AssetSource('audio/flashlight_on.mp3'));
  }

  /// เล่นเสียงเมื่อปิดไฟฉาย
  Future<void> playFlashOff() async {
    if (_isDisposed) return;
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource('audio/flashlight_off.mp3'));
  }

  /// คืนค่า Resource
  void dispose() {
    _isDisposed = true;
    _audioPlayer.dispose();
  }
}
