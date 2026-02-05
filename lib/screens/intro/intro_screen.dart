import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

class IntroScreen extends StatefulWidget {
  final VoidCallback? onNext;

  const IntroScreen({super.key, this.onNext});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _hintPlayer = AudioPlayer();
  Timer? _holdTimer;
  bool _isPlayingInstruction = false;
  int _secondsHeld = 0;

  @override
  void initState() {
    super.initState();
    _playHintLoop(); // เริ่มเล่นเสียงวนทันทีที่เปิดหน้านี้
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _hintPlayer.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  // ฟังก์ชันเล่นเสียงวน (จะเล่นวนไปเรื่อยๆ จนกว่าคนจะกด)
  Future<void> _playHintLoop() async {
    try {
      if (_isPlayingInstruction) {
        return; // ถ้ากำลังฟังคำอธิบายหลักอยู่ ไม่ต้องเล่นอันนี้
      }

      await _hintPlayer.setReleaseMode(ReleaseMode.loop); // ตั้งโหมดวนลูป

      // เช็คว่าหน้าจอยังอยู่ไหม ถ้าถูกปิดไปแล้ว (dispose) ไม่ต้องเล่นต่อ
      if (!mounted) return;

      await _hintPlayer.play(AssetSource('audio/hint.mp3'));
    } catch (e) {
      debugPrint("Hint Audio Error: $e");
    }
  }

  void _startHolding() {
    if (_isPlayingInstruction) return;
    _hintPlayer.stop();
    _secondsHeld = 0;

    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsHeld++;

      // สั่นแรง 2 จังหวะ (Tick Tick) เพื่อบอกว่าผ่านไป 1 วิแล้ว
      // HapticFeedback.heavyImpact();
      // Future.delayed(const Duration(milliseconds: 200), () {
      //   if (mounted) HapticFeedback.heavyImpact();
      // });

      HapticFeedback.heavyImpact();

      if (_secondsHeld >= 5) {
        // เมื่อครบ 5 วิ
        _holdTimer?.cancel();
        _playInstructionAudio(); // เล่นเสียงคำอธิบายหลัก
      }
    });
  }

  void _stopHolding() {
    _holdTimer?.cancel();
    _secondsHeld = 0;

    // ถ้าปล่อยมือก่อนครบ (และเสียงหลักยังไม่เล่น) ให้กลับมาเล่นเสียงวนใหม่
    if (!_isPlayingInstruction) {
      _playHintLoop();
    }
  }

  Future<void> _playInstructionAudio() async {
    try {
      setState(() => _isPlayingInstruction = true);
      HapticFeedback.heavyImpact();
      await _audioPlayer.play(AssetSource('audio/instruction.mp3'));
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      debugPrint("Error playing audio: $e");
    } finally {
      if (mounted) setState(() => _isPlayingInstruction = false);
    }
  }

  void _triggerNextPage() {
    _hintPlayer.stop();
    _audioPlayer.stop(); // หยุดเสียง
    // เรียกใช้ callback ที่ส่งมาจาก RootScreen เพื่อเปลี่ยน index
    widget.onNext?.call();
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ Container แทน Scaffold เพราะ RootScreen มี Scaffold ให้แล้ว
    return Container(
      color: const Color(0xFFF5F5F5), // พื้นหลังสีเทาอ่อน
      child: SafeArea(
        // เพิ่ม SafeArea เพื่อป้องกันปุ่มทับติ่งจอ
        child: Padding(
          padding: const EdgeInsets.all(16.0), // เว้นระยะขอบรอบด้าน
          child: GestureDetector(
            // การกดและปัดอยู่ที่ตัวปุ่มใหญ่ปุ่มเดียวเลย
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < 0) {
                HapticFeedback.mediumImpact();
                _triggerNextPage();
              }
            },
            onLongPressDown: (_) => _startHolding(),
            onLongPressUp: () => _stopHolding(),
            onLongPressCancel: () => _stopHolding(),
            child: Container(
              width: double.infinity,
              height: double.infinity, // ให้เต็มพื้นที่ Safe Area
              decoration: BoxDecoration(
                // เปลี่ยนเป็นสีเหลือง
                color: _isPlayingInstruction
                    ? const Color(0xFFDAA520)
                    : const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/one-finger-tap.svg', // อย่าลืมวางไฟล์ไว้ใน assets/icons/ และประกาศใน pubspec.yaml
                    width: 100,
                    height: 100,
                    colorFilter: const ColorFilter.mode(
                      Colors.black87,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "กดค้าง 5 วินาที",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const Text(
                    "เพื่อฟังคำอธิบาย",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Opacity(
                    opacity: 0.5,
                    child: const Text(
                      "(ปัดซ้ายเพื่อเริ่ม)",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
