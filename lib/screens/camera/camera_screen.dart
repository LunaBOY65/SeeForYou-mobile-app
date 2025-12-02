import 'package:flutter/material.dart';

class CameraScreen extends StatelessWidget {
  final VoidCallback? onCapture; // เผื่อคุณจะเชื่อม API ภายหลัง

  const CameraScreen({super.key, this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // พื้นหลังจำลองกล้อง (ตอนนี้เป็นสีดำก่อน)
        Container(
          color: Colors.black87,
          width: double.infinity,
          height: double.infinity,
          child: const Center(
            child: Icon(Icons.camera_alt, size: 100, color: Colors.white24),
          ),
        ),

        // ปุ่ม Flash มุมขวาบน
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 20,
          child: IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white, size: 30),
            onPressed: () {
              // TODO: Flash toggle
            },
          ),
        ),

        // ปุ่มกดถ่ายรูปตรงกลางล่าง
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: onCapture ?? () {},
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  color: Colors.white30,
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
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
