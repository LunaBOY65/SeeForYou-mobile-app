import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// screens
import '../camera/camera_screen.dart';
import '../result/result_screen.dart';
import '../settings/settings_screen.dart';
import '../placeholder/info_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 1; // เริ่มต้นที่หน้ากล้อง (Index 1)

  @override
  Widget build(BuildContext context) {
    final screens = [
      const InfoScreen(),
      CameraScreen(
        onCapture: () {
          // ถ่ายเสร็จโยนไปหน้า Result
          setState(() => _index = 2);
        },
      ),
      const ResultScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBarTheme(
        // ใช้ Theme เพื่อกำหนดรูปแบบวงกลม
        data: NavigationBarThemeData(
          indicatorColor: Colors.transparent, // กำหนดรูปร่างเป็นวงกลม
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.white, // สีพื้นหลังของบาร์ (สีดำ)
          height: 90, // ความสูงของบาร์
          destinations: [
            // 1. Info
            NavigationDestination(
              icon: const Icon(
                Icons.info_outline,
                color: Colors.grey,
              ), // ไอคอนตอนไม่เลือก
              selectedIcon: Container(
                // 2. สร้างวงกลมเองตรงนี้
                width: 60, // กำหนดความกว้างวงกลม (ยิ่งเยอะยิ่งใหญ่)
                height: 60, // กำหนดความสูงวงกลม
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700), // สีเหลือง
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.black,
                  size: 30,
                ),
              ),
              label: 'Info',
            ),

            // 2. Camera
            NavigationDestination(
              icon: SvgPicture.asset(
                'assets/icons/camera_icon.svg',
                width: 30,
                height: 30,
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
              selectedIcon: Container(
                width: 60, // ปรับขนาดวงกลมได้ตามใจชอบตรงนี้
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  // ต้องมี Center เพื่อจัด icon ให้อยู่กลางวงกลม
                  child: SvgPicture.asset(
                    'assets/icons/camera_icon.svg',
                    width: 30,
                    height: 30,
                    colorFilter: const ColorFilter.mode(
                      Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              label: 'กล้อง',
            ),

            // 3. Result
            NavigationDestination(
              icon: SvgPicture.asset(
                'assets/icons/robotics_icon.svg',
                width: 30,
                height: 30,
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
              selectedIcon: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/robotics_icon.svg',
                    width: 30,
                    height: 30,
                    colorFilter: const ColorFilter.mode(
                      Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              label: 'ผลลัพธ์',
            ),

            // 4. Settings
            NavigationDestination(
              icon: SvgPicture.asset(
                'assets/icons/settings_icon.svg',
                width: 30,
                height: 30,
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
              selectedIcon: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/settings_icon.svg',
                    width: 30,
                    height: 30,
                    colorFilter: const ColorFilter.mode(
                      Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              label: 'ตั้งค่า',
            ),
          ],
        ),
      ),
    );
  }
}
