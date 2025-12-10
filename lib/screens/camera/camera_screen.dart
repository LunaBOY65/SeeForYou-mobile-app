import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  final VoidCallback? onCapture; // เผื่อคุณจะเชื่อม API ภายหลัง
  final Function(String path)?
  onImageSelected; // ส่ง path รูปกลับไปเมื่อเลือกจาก Gallery

  const CameraScreen({super.key, this.onCapture, this.onImageSelected});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  // ฟังก์ชันเริ่มการทำงานกล้อง
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;
    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  //สำหรับเปิด Gallery ให้มีการอัปเดต state รูป preview
  Future<void> _openGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (widget.onImageSelected != null) {
        widget.onImageSelected!(image.path);
      }
    }
  }

  // เพิ่มฟังก์ชันถ่ายรูป
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      HapticFeedback.heavyImpact(); // สั่นแรงๆ ให้รู้ว่าถ่ายแล้ว
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();

      widget.onImageSelected?.call(image.path);
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ FutureBuilder เพื่อรอให้กล้องพร้อมก่อนแสดงผล
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                // ภาพจากกล้องเต็มจอ
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CameraPreview(_controller!),
                ),

                // ปุ่ม Flash มุมขวาบน
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  right: 20,
                  child: IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      // TODO: Flash toggle
                      setState(() {
                        _isFlashOn = !_isFlashOn;
                        _controller!.setFlashMode(
                          _isFlashOn ? FlashMode.torch : FlashMode.off,
                        );
                      });
                    },
                  ),
                ),

                // เพิ่มปุ่ม Gallery ทางซ้ายล่าง (วางตำแหน่งไว้ข้างๆ ปุ่มถ่ายรูป)
                Positioned(
                  bottom: 60,
                  left: 40,
                  child: GestureDetector(
                    onTap: _openGallery,
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

                // ปุ่มกดถ่ายรูปตรงกลางล่าง
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Semantics(
                      child: GestureDetector(
                        onTap: _takePicture, // เรียกฟังก์ชันถ่ายจริง
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
                ),
              ],
            );
          } else {
            // ระหว่างรอกล้องเปิด
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            );
          }
        },
      ),
    );
  }
}
