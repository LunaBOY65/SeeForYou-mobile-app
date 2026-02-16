import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

// คลาสหน้าต่าง UI ที่จะเอาไปวางทับลงบนภาพกล้องอีกที เช่น พวกปุ่มแฟลช ปุมแกลเลอรี
// ใช้เป็น StatefulWidget เพราะต้องให้มันมีความจำ เพื่อจำเวลาที่ผู้ใช้กดปุ่ม (ระบบกดเบิ้ล)
class CameraOverlay extends StatefulWidget {
  // ตัวแปรที่ต้องรับมาจากหน้าแม่ (CameraScreen)
  // รับสถานะมาบอกว่า ตอนนี้ไฟฉายเปิดอยู่ไหม? (เอาไว้เปลี่ยนรูปไอคอน เปิด/ปิดแฟลช)
  // รับคำสั่งจากหน้าแม่ ว่าถ้าผู้ใช้กดปุ่มแฟลช ให้ไปเรียกฟังก์ชันเปิดปิดกล้องที่หน้าแม่นะ
  // รับคำสั่งจากหน้าแม่ ว่าถ้าผู้ใช้กดปุ่มแกลเลอรี ให้ไปเรียกฟังก์ชันเปิดแกลเลอรีที่หน้าแม่นะ
  final bool isFlashOn;
  final VoidCallback onToggleFlash;
  final Future<void> Function() onGalleryTap;

  // Constructor กฎบังคับว่าถ้าหน้าแม่เรียกใช้ CameraOverlay
  // ต้องส่งข้อมูล 3 ตัวข้างบนมาให้ครบถ้วนนะ ไม่งั้นจะไม่ยอมให้ทำงาน
  const CameraOverlay({
    super.key,
    required this.isFlashOn,
    required this.onToggleFlash,
    required this.onGalleryTap,
  });

  // สร้าง State ของ CameraOverlay เพื่อให้มันมีความจำและจัดการกับการกดปุ่มได้
  @override
  State<CameraOverlay> createState() => _CameraOverlayState();
}

class _CameraOverlayState extends State<CameraOverlay> {
  // ตัวแปรจำเวลา ที่ผู้ใช้แตะปุ่มครั้งล่าสุด เอาไว้คำนวณการกดเบิ้ล
  // สร้างแปรตัวเล่นเสียงหน้านี้ด้วยเลย
  DateTime? _lastTapTime;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ฟังก์ชันจัดการการกดเบิ้ล 2 ครั้งเพื่อเปิดแกลเลอรี
  Future<void> _handleGalleryTap() async {
    // ดึงเวลาปัจจุบันตอนที่นิ้วแตะปุ่ม
    final now = DateTime.now();

    // เช็คว่าเคยกดมาก่อนหน้านี้ไหม และเวลาห่างจากรอบที่แล้วไม่เกิน 1.5 วินาที (1500 ms) รึเปล่า ถ้าใช่ถือว่าเป็นการกดเบิ้ล
    // 1. ตั้งว่าไม่ได้กดเบิ้ลไว้ก่อน
    bool isDoubleTap = false;

    // 2. เช็คก่อนว่า เคยมีประวัติการกดปุ่มมาก่อนไหม (ถ้าไม่เคยกดเลย _lastTapTime จะยังเป็น null อยู่)
    // สาเหตุที่ต้องเช็ค != null เพราะตอนเปิดแอปมาใหม่ๆ ระบบเดิมจะยัง Null อยู่
    // ถ้าเอาเวลาปัจจุบันไปลบกับ Null เลย แอปจะ Error แล้วเด้งหลุดทันที
    if (_lastTapTime != null) {
      // เอาเวลาปัจจุบัน ตั้งลบด้วย เวลาที่กดครั้งล่าสุด เพื่อดูว่าห่างกันกี่ Milliseconds
      // ยืนยันกับแอปว่า เช็คแล้วนะว่าระบบไม่ใช้ Null แล้ว สามารถเอาเวลาปัจจุบันไปลบกับเวลาที่กดครั้งล่าสุดได้เลย
      int timePassed = now.difference(_lastTapTime!).inMilliseconds;

      // ถ้าเวลาห่างจากการกดครั้งแรกไม่ถึง 1.5 วินาที (1500 ms) แปลว่ากดเบิ้ลจริง
      isDoubleTap = timePassed < 1500;
    }

    //3. สั่นแรง 1 ที ทุกครั้งที่นิ้วแตะโดนปุ่ม ไม่ว่าจะกดครั้งแรก หรือกดเบิ้ลก็ตาม
    HapticFeedback.heavyImpact();

    //4. ตัดสินว่าจะทำอะไร
    if (isDoubleTap) {
      // ล้างความจำเวลาทิ้งเตรียมสำหรับการกดรอบใหม่
      _lastTapTime = null;

      // หยุดเสียงบอกชื่อปุ่ม
      // สั่งเปิดแกลเลอรีรอจนกว่าผู้ใช้จะเลือกรูปหรือปิด
      // ทันทีที่แกลเลอรีปิดเล่นเสียง
      await _audioPlayer.stop();
      await widget.onGalleryTap();
      await _audioPlayer.play(AssetSource('audio/closeGallery.mp3'));
    } else {
      // ถ้าไม่ใช่ หรือเพิ่งกดครั้งแรก
      // จำเวลาของรอบนี้เอาไว้รอกดครั้งหน้า
      // หยุดเสียงที่อาจจะค้าง และเล่นเสียง
      _lastTapTime = now;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/openGallery.mp3'));
    }
  }

  // คืนทรัพยากรเมื่อหน้านี้ถูกปิด
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ปุ่ม Flash
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 20,
          child: IconButton(
            icon: Icon(
              widget.isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
              size: 30,
            ),
            onPressed: widget.onToggleFlash,
          ),
        ),

        // ปุ่ม Gallery
        Positioned(
          bottom: 60,
          right: 40,
          child: GestureDetector(
            onTap: _handleGalleryTap,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SvgPicture.asset(
                  'assets/icons/folder_icon.svg',
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
