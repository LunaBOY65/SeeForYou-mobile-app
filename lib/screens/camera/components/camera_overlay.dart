import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CameraOverlay extends StatelessWidget {
  final bool isFlashOn;
  final VoidCallback onToggleFlash;
  final VoidCallback onGalleryTap;
  final VoidCallback onCaptureTap;

  const CameraOverlay({
    super.key,
    required this.isFlashOn,
    required this.onToggleFlash,
    required this.onGalleryTap,
    required this.onCaptureTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // เปลี่ยนเป็นข้อความบอกสถานะด้านล่างแทน หรือปล่อยโล่ง
        Align(
          alignment: Alignment.center,
          child: Text(
            "ส่องกล้องไปทั่วๆ เพื่อค้นหา",
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.8),
              fontSize: 18,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
        ),

        // ปุ่ม Flash
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 20,
          child: IconButton(
            icon: Icon(
              isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
              size: 30,
            ),
            onPressed: onToggleFlash,
          ),
        ),

        // ปุ่ม Gallery
        Positioned(
          bottom: 60,
          left: 40,
          child: GestureDetector(
            onTap: onGalleryTap,
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

        // ปุ่มถ่ายรูป
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: onCaptureTap,
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
