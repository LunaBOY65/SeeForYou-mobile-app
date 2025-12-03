import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

class ResultScreen extends StatelessWidget {
  final VoidCallback? onRetake; // 1. เพิ่มตัวแปรรับฟังก์ชัน

  const ResultScreen({super.key, this.onRetake}); // 2. แก้ไข Constructor

  @override
  Widget build(BuildContext context) {
    // ในอนาคตรับผลลัพธ์ผ่าน Provider / Riverpod / arguments
    final sampleText = 'มีผู้ชายหนึ่งคนนั่งอยู่ทางซ้าย ... (ตัวอย่างผลลัพธ์)';

    return Scaffold(
      appBar: AppBar(title: const Text('ผลการวิเคราะห์'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // กล่องแสดงรูปภาพตัวอย่างที่วิเคราะห์แล้ว (ตามสเก็ตช์)
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFFF5F5F5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // กล่องข้อความอธิบาย
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    sampleText,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.6,
                      color: Color(0xFF212121),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ปุ่มเล่นเสียง (เชื่อม Botnoi Voice API ภายหลัง)
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  // --- ปุ่มซ้าย: ถ่ายใหม่ (กลับไปหน้ากล้อง) ---
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300], // ใช้พื้นขาว
                        foregroundColor: Colors.black, // ไอคอน/ตัวหนังสือดำ
                        elevation: 0,
                        // side: const BorderSide(
                        //   color: Colors.black, // เพิ่มขอบดำหนาๆ ให้เห็นชัด
                        //   width: 2,
                        // ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        // ให้ปุ่มยืดเต็มพื้นที่แนวตั้งของ SizedBox
                        alignment: Alignment.center,
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        onRetake?.call(); // คำสั่งกลับไปหน้าก่อนหน้า (กล้อง)
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/camera_icon.svg',
                            width: 40,
                            height: 40,
                            colorFilter: const ColorFilter.mode(
                              Colors.black,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'ถ่ายใหม่',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16), // เว้นระยะห่างระหว่างปุ่ม
                  // --- ปุ่มขวา: เล่นเสียง (ปุ่มหลัก สีเหลือง) ---
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFFFFD700,
                        ), // สีเหลือง (High Contrast)
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        // TODO: เรียก Botnoi Voice API play
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/audio_icon.svg',
                            width: 50,
                            height: 50,
                            colorFilter: const ColorFilter.mode(
                              Colors.black,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'เล่นเสียง',
                            style: TextStyle(
                              fontSize:
                                  24, // ลดขนาดตัวหนังสือลงนิดหน่อยให้พอดีกับปุ่มครึ่งจอ
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
