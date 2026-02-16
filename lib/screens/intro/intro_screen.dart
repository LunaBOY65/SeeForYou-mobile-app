import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

/// หน้าจอแนะนำการใช้งาน IntroScreen
/// ใช้ StatefulWidget เพราะหน้านี้ต้องมีการอัปเดตหน้าจอด้วย (เช่น การจับเวลากดค้าง, การเล่นเสียง)
class IntroScreen extends StatefulWidget {
  // ตัวแปรสำหรับรับคำสั่งเปลี่ยนหน้า เอาไว้รับคำสั่งจากหน้า RootScreen
  // คล้ายรีโมทพอกดปุ๊บ มันจะไปสั่งให้ RootScreen เปลี่ยนหน้าให้
  final VoidCallback? onNext;

  // Constructor สำหรับรับค่า onNext เข้ามาใช้งาน
  const IntroScreen({super.key, this.onNext});

  @override
  // คอยจัดการข้อมูลและการเปลี่ยนแปลงของหน้านี้ ซึ่งไปเรียกหรือเขียนคลาส _IntroScreenState อยู่ข้างล่างอีกที
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _hintPlayer = AudioPlayer();
  Timer? _holdTimer;
  // เอาไว้เช็คว่ากำลังเล่นเสียงอธิบายยาวๆอยู่ไหม จะได้ไม่เล่นเสียงอื่นแทรก
  bool _isPlayingInstruction = false;
  // ตัวนับว่าผู้ใช้กดหน้าจอค้างมากี่วินาทีแล้ว
  int _secondsHeld = 0;

  // เริ่มต้นหน้าจอมาให้เล่นเสียงบอกวิธีใช้ก่อนเลย (เล่นซ้ำ 2 รอบถ้ายังไม่ได้กดหน้าจอ)
  @override
  void initState() {
    super.initState();
    _playHintLoop();
  }

  //คืนทรัพยากร
  @override
  void dispose() {
    // ทำงานตอนที่ปิดหรือเปลี่ยนหน้านี้ เป็นการคืนทรัพยากรให้ระบบ
    // สำคัญมาก! ต้องสั่งปิดเครื่องเล่นเสียงและตัวจับเวลาทั้งหมด
    // เพื่อไม่ให้มันไปทำงานแอบกินแบตหรือส่งเสียงในขณะที่ผู้ใช้เปลี่ยนไปหน้าอื่นแล้ว
    _audioPlayer.dispose();
    _hintPlayer.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  /// เล่นเสียงบอกวิธีใช้งาน (เล่นซ้ำ 2 รอบหากผู้ใช้ยังไม่ได้กดหน้าจอ)
  Future<void> _playHintLoop() async {
    try {
      if (_isPlayingInstruction) {
        return;
      }

      await _hintPlayer.setReleaseMode(ReleaseMode.stop);

      // วนลูปเล่นเสียง 2 รอบ
      for (int i = 0; i < 2; i++) {
        // mounted เช็คว่าผู้ใช้ยังเปิดหน้านี้อยู่ไหม ถ้าเปลี่ยนหน้าไปแล้วจะได้หยุดทำงานของเสียงและตัวจับเวลา
        if (!mounted || _isPlayingInstruction) break;

        await _hintPlayer.play(AssetSource('audio/hint.mp3'));
        await _hintPlayer.onPlayerComplete.first;

        if (i == 0 && mounted) await Future.delayed(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint("Hint Audio Error: $e");
    }
  }

  /// เริ่มจับเวลาเมื่อผู้ใช้กดค้างที่หน้าจอ
  void _startHolding() {
    if (_isPlayingInstruction) return;
    _hintPlayer.stop();
    _holdTimer?.cancel();
    _secondsHeld = 0;

    // Timer.periodic สั่งให้ทำงานซ้ำๆทุก 1 วินาที เพื่อเช็คว่าผู้ใช้กดค้างครบ 3 วิหรือยัง
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsHeld++;

      // สั่นเตือน 2 จังหวะ (ตึบ-ตึบ) เพื่อบอกผู้ใช้ว่าผ่านไปแล้ว 1 วินาทีแล้วนะ
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) HapticFeedback.heavyImpact();
      });

      if (_secondsHeld >= 3) {
        // เมื่อกดค้างครบ 3 วินาทีตามที่กำหนดไว้ ให้หยุดจับเวลาและเล่นเสียงคำอธิบาย
        _holdTimer?.cancel();
        _playInstructionAudio();
      }
    });
  }

  /// ยกเลิกการจับเวลาเมื่อผู้ใช้ปล่อยมือก่อนครบ 3 วินาที
  void _stopHolding() {
    _holdTimer?.cancel();
    _secondsHeld = 0;

    // หากปล่อยมือก่อนครบกำหนด และยังไม่ได้เล่นเสียงอธิบายให้กลับไปเล่นเสียงบอกใบ้ใหม่
    if (!_isPlayingInstruction) {
      _playHintLoop();
    }
  }

  /// เล่นเสียงคำอธิบายหลักเมื่อผู้ใช้กดค้างครบเวลาที่กำหนดไว้
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

  /// เปลี่ยนไปหน้าถัดไป และหยุดการทำงานของเสียงรวมถึงตัวจับเวลาทั้งหมด
  /// กันเหนียวให้แน่ใจว่าทุกอย่างถูกกหยุดก่อนเปลี่ยนหน้า เพื่อไม่ให้มีเสียงหรือการจับเวลาที่หลงเหลือไปทำงานในหน้าถัดไป
  void _triggerNextPage() {
    _holdTimer?.cancel();
    _hintPlayer.stop();
    _audioPlayer.stop();
    widget.onNext?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: SafeArea(
        // SafeArea กันไม่ให้เนื้อหาไปทับแถบสถานะมือถือ
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GestureDetector(
            // ควบคุมการ touch หน้าจอทั้งหมดที่ปุ่มใหญ่นี้ปุ่มเดียว
            // ใช้ตรวจการปัดนิ้วซ้าย-ขวา
            onHorizontalDragEnd: (details) {
              // เช็คว่ามีความเร็วในการปัดจริงนะ และค่าความเร็วติดลบ (< 0)
              // ซึ่งในระบบแอป การปัดไปทางซ้าย คือการย้อนศรแกน X ค่าความเร็วจะติดลบเสมอ
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < 0) {
                HapticFeedback.heavyImpact();
                _triggerNextPage(); // สั่งเปลี่ยนไปหน้าถัดไป
              }
            },
            // [Touch Action]
            // เมื่อนิ้วแตะโดนหน้าจอ
            // เมื่อยกนิ้วขึ้น
            // เมื่อนิ้วขยับหลุดออกจากปุ่ม
            onLongPressDown: (_) => _startHolding(),
            onLongPressUp: () => _stopHolding(),
            onLongPressCancel: () => _stopHolding(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
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
                    'assets/icons/one-finger-tap.svg',
                    width: 100,
                    height: 100,
                    colorFilter: const ColorFilter.mode(
                      Colors.black87,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "กดค้าง 3 วินาที",
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
                      "(ปัดซ้ายเพื่อเริ่มใช้งาน)",
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
