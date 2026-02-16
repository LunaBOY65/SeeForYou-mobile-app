import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seeforyou_app/screens/intro/intro_screen.dart';
import '../camera/camera_screen.dart';
import '../result/result_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  // ตัวแปรควบคุมหน้าจอ 0 = หน้าแนะนำวิธีใช้, 1 = หน้ากล้อง, 2 = หน้าผลลัพธ์
  int _index = 0;

  // ตัวแปรสำหรับจัดการ 2 จังหวะการกดปุ่มใน BottomNavigationBar
  // เก็บเลข index ปุ่มล่าสุดที่เพิ่งโดนแตะ (-1 คือยังไม่มีการแตะปุ่มใดๆ)
  // เก็บเวลาล่าสุดที่แตะปุ่ม
  // เล่นเสียงสำหรับอ่านชื่อเมนู
  // เก็บที่อยู่ไฟล์รูปภาพที่เพิ่งถ่าย เพื่อส่งข้ามจากหน้าอื่น
  int _lastTappedIndex = -1;
  DateTime? _lastTapTime;
  final AudioPlayer _navPlayer = AudioPlayer();
  String? _imagePath;

  @override
  void dispose() {
    // คืนทรัพยากร AudioPlayer เมื่อหน้าจอถูกทิ้ง
    _navPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // เตรียมหน้าจอทั้ง 3 หน้า ไว้ในตัวแปรแบบ List
    final screens = [
      // หน้า 0
      IntroScreen(
        onNext: () {
          // เมื่อผู้ใช้ปัดซ้ายหรือกดผ่านหน้าแนะนำ ให้เปลี่ยนไปหน้ากล้อง (หน้าที่ 1)
          setState(() => _index = 1);
        },
      ),

      // หน้า 1
      CameraScreen(
        onImageSelected: (path) {
          // เมื่อถ่ายรูปเสร็จ หรือเลือกรูปจากแกลเลอรีได้แล้ว
          setState(() {
            // นำ path ของรูปมาเก็บไว้ แล้วเปลี่ยนไปหน้าผลลัพธ์ (หน้าที่ 2)
            _imagePath = path;
            _index = 2;
          });
        },
      ),

      // หน้า 2
      ResultScreen(
        // ส่งที่อยู่ไฟล์รูปภาพที่ได้จากหน้ากล้อง ไปให้หน้าผลลัพธ์ใช้ต่อ
        imagePath: _imagePath,
        onRetake: () {
          setState(() {
            // เมื่อผู้ใช้กดปุ่มถ่ายใหม่ให้ล้างรูปภาพเดิม แล้วกลับไปหน้ากล้อง (หน้าที่ 1)
            _imagePath = null;
            _index = 1;
          });
        },
      ),
    ];

    return Scaffold(
      // เลือกแสดงหน้าจอตามค่า _index (0, 1 หรือ 2)
      body: screens[_index],

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          // เมื่อมีการแตะปุ่มเมนูด้านล่าง ให้ไปเรียกใช้ฟังก์ชัน Double Tap แทนการเปลี่ยนหน้าทันที
          onTap: _handleNavTap,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 17,
          unselectedFontSize: 17,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          items: [
            _buildNavItem(
              index: 0,
              label: 'วิธีใช้',
              assetPath: 'assets/icons/information.svg',
            ),
            _buildNavItem(
              index: 1,
              label: 'กล้อง',
              assetPath: 'assets/icons/camera_icon.svg',
            ),
            _buildNavItem(
              index: 2,
              label: 'ผลลัพธ์',
              assetPath: 'assets/icons/robotics_icon.svg',
            ),
          ],
        ),
      ),
    );
  }

  /// ฟังก์ชันสำหรับจัดการปุ่มเมนูด้านล่างแบบ 2 จังหวะ
  void _handleNavTap(int index) async {
    final now = DateTime.now();

    // เช็คเงื่อนไขว่าเป็นการกดเบิ้ล (แตะปุ่มเดิมซ้ำในเวลาไม่เกิน 1.5 วินาที) หรือไม่
    bool isDoubleTap =
        _lastTappedIndex == index &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 1500;
    HapticFeedback.heavyImpact();

    if (isDoubleTap) {
      // กรณีกดเบิ้ลเป็นการกดยืนยัน
      setState(() {
        // สั่งเปลี่ยนไปหน้าที่ผู้ใช้เลือก
        _index = index;

        // ถ้ากดเปลี่ยนไปหน้าที่ไม่ใช่่หน้าผลลัพธ์ เช่น กลับไปหน้าวิธีใช้ หรือหน้ากล้อง
        // ให้ล้างความจำรูปภาพเดิมทิ้งไปเลย
        if (index != 2) {
          _imagePath = null;
        }
      });
      // ล้างค่าปุ่มที่จำไว้ทิ้งไป เพื่อเตรียมรับการกดรอบใหม่
      _lastTappedIndex = -1;
    } else {
      // กรณีเป็นการกดครั้งแรก หรือกดเปลี่ยนปุ่ม
      // จำหมายปุ่มและเวลาที่กดเอาไว้
      _lastTappedIndex = index;
      _lastTapTime = now;

      // หยุดเสียงเดิมที่อาจจะพูดค้างอยู่ แล้วเช็คว่าจะให้เล่นเสียงไหน
      await _navPlayer.stop();
      String soundFile = '';
      if (index == 1) soundFile = 'audio/camera_page.mp3';
      if (index == 2) soundFile = 'audio/results_page.mp3';
      if (soundFile.isNotEmpty) {
        await _navPlayer.play(AssetSource(soundFile));
      }
    }
  }

  /// สำหรับวาดปุ่มเมนูแต่ละปุ่ม
  /// ถ้าปุ่มไหนถูกเลือกอยู่ (isSelected) จะสร้างวงกลมสีเหลืองมาเป็นพื้นหลังให้
  BottomNavigationBarItem _buildNavItem({
    required int index,
    required String label,
    required String assetPath,
  }) {
    // เช็คว่าปุ่มที่กำลังวาดอยู่นี้ ตรงกับหน้าจอที่กำลังเปิดอยู่ไหม
    final isSelected = _index == index;
    const double circleSize = 48;
    const double iconSize = 27;

    // ตัวไอคอน ถ้าถูกเลือกจะเป็นสีดำ ถ้าไม่ถูกเลือกจะเป็นสีเทา
    Widget iconWidget = SvgPicture.asset(
      assetPath,
      width: iconSize,
      height: iconSize,
      colorFilter: ColorFilter.mode(
        isSelected ? Colors.black : Colors.grey,
        BlendMode.srcIn,
      ),
    );

    return BottomNavigationBarItem(
      icon: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        child: iconWidget,
      ),
      activeIcon: Container(
        margin: const EdgeInsets.only(bottom: 6),
        width: circleSize,
        height: circleSize,
        decoration: const BoxDecoration(
          color: Color(0xFFFFD700),
          shape: BoxShape.circle,
        ),
        child: Center(child: iconWidget),
      ),
      label: label,
    );
  }
}
