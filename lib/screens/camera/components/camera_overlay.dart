import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CameraOverlay extends StatelessWidget {
  final bool isFlashOn;
  final VoidCallback onToggleFlash;
  final VoidCallback onGalleryTap;

  const CameraOverlay({
    super.key,
    required this.isFlashOn,
    required this.onToggleFlash,
    required this.onGalleryTap,
  });

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
      ],
    );
  }
}
