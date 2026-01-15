import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seeforyou_app/screens/intro/intro_screen.dart';

// screens
import '../camera/camera_screen.dart';
import '../result/result_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0; // เริ่มต้นที่หน้ากล้อง (Index 1)

  String? _imagePath;

  @override
  Widget build(BuildContext context) {
    final screens = [
      // Index 0: หน้า Intro
      IntroScreen(
        onNext: () {
          setState(() => _index = 1); // สั่งเปลี่ยนไปหน้ากล้อง
        },
      ),

      CameraScreen(
        onCapture: () {
          // ถ่ายเสร็จโยนไปหน้า Result
          setState(() => _index = 2);
        },
        onImageSelected: (path) {
          setState(() {
            _imagePath = path; // เก็บ Path รูป
            _index = 2; // กระโดดไปหน้า Result
          });
        },
      ),
      ResultScreen(
        //ส่ง Path รูปไปให้หน้า Result (เดี๋ยวเราต้องไปแก้ ResultScreen ให้รับค่านี้)
        imagePath: _imagePath,
        onRetake: () {
          // จากหน้าผลลัพธ์ -> กลับมาหน้ากล้อง (index 1)
          setState(() {
            _imagePath = null;
            _index = 1;
          });
        },
      ),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) {
            HapticFeedback.vibrate(); // สั่นตอนกดปุ่ม
            setState(() => _index = i);
          },
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed, // ป้องกันปุ่มเด้งไปมา
          elevation: 0, // เอาเงาออก
          selectedFontSize: 17,
          unselectedFontSize: 17,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          items: [
            // เพิ่มปุ่มที่ 1: วิธีใช้
            _buildNavItem(
              index: 0,
              label: 'วิธีใช้',
              iconData:
                  Icons.info_outline_rounded, // ใช้ Icon เพราะไม่มีไฟล์ svg
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

  // เพิ่มฟังก์ชันใหม่ตรงนี้ (ก่อนปิดปีกกา Class)
  BottomNavigationBarItem _buildNavItem({
    required int index,
    required String label,
    String? assetPath,
    IconData? iconData,
  }) {
    final isSelected = _index == index;
    const double circleSize = 48;
    const double iconSize = 27;

    Widget iconWidget;
    if (assetPath != null) {
      iconWidget = SvgPicture.asset(
        assetPath,
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(
          isSelected ? Colors.black : Colors.grey,
          BlendMode.srcIn,
        ),
      );
    } else {
      iconWidget = Icon(
        iconData,
        size: iconSize,
        color: isSelected ? Colors.black : Colors.grey,
      );
    }

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
