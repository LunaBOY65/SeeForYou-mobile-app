import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seeforyou_app/screens/camera/components/camera_overlay.dart';
import 'package:seeforyou_app/screens/camera/controllers/scan_logic_controller.dart';
import 'package:seeforyou_app/services/audio_feedback_service.dart';

/// หน้าจอหลักสำหรับกล้องถ่ายภาพและสแกนวันหมดอายุ
///
/// หน้าที่หลัก:
/// - แสดงผล Preview จากกล้อง
/// - ควบคุมฮาร์ดแวร์ (Zoom, Flash/Torch)
/// - จัดการ Lifecycle ของกล้อง
/// - เชื่อมต่อกับ [ScanLogicController] เพื่อสแกนภาพอัตโนมัติ
class CameraScreen extends StatefulWidget {
  /// Callback เมื่อกดปุ่มถ่ายภาพ (Shutter)
  final VoidCallback? onCapture;

  /// Callback ส่ง path รูปกลับไปตอนเลือกจาก Gallery
  final Function(String path)? onImageSelected;

  const CameraScreen({super.key, this.onCapture, this.onImageSelected});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isFlashOn = false; // สถานะไฟฉาย
  double _maxZoom = 1.0;

  // Logic & Services
  late ScanLogicController _scanController;
  final AudioFeedbackService _feedbackService = AudioFeedbackService();

  @override
  void initState() {
    super.initState();
    _scanController = ScanLogicController(_feedbackService);
    _initCamera();
  }

  /// เริ่มต้นการทำงานของกล้องและการตั้งค่าที่จำเป็นสำหรับ OCR
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;
    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false,
      //  กำหนด Format ให้เหมาะกับ ML Kit
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    try {
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture; // รอให้กล้องเปิดเสร็จก่อน

      // ปรับ Zoom (ถ้าอยากปรับ)
      _maxZoom = await _controller!.getMaxZoomLevel();
      double targetZoom = 1.0;
      if (targetZoom > _maxZoom) {
        targetZoom = _maxZoom; // กันค่าเกิน limit เครื่อง
      }

      await _controller!.setZoomLevel(targetZoom);

      // ตั้งค่าเริ่มต้นให้ปิดไฟฉาย
      try {
        await _controller!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
      } catch (e) {
        debugPrint("Error setting flash mode: $e");
      }

      // ตั้งเป็น Auto Focus เพื่อให้ปรับระยะชัดได้เองตลอดเวลา
      await _controller?.setFocusMode(FocusMode.auto);

      await _controller?.setExposureMode(ExposureMode.auto);

      // เริ่มระบบสแกนอัตโนมัติ (Snapshot Loop)
      if (_controller != null) {
        _scanController.startLoop(_controller!);
      }

      // เล่นเสียงแนะนำการใช้งาน ไม่ต้องรอ await
      _feedbackService.playIntro();
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
    // เช็ค mounted อีกครั้งเผื่อ user กด back ไปแล้วระหว่าง init
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // คืน Resource ทุกอย่างเมื่อปิดหน้านี้
    _scanController.stopLoop();
    _scanController.dispose();
    _feedbackService.dispose();
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
      //  หยุดสแกนก่อนถ่ายจริง เพื่อไม่ให้กล้องแย่ง Resource กัน (สำคัญมาก)
      _scanController.stopLoop();

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
                CameraOverlay(
                  isFlashOn: _isFlashOn,
                  onToggleFlash: () {
                    setState(() {
                      _isFlashOn = !_isFlashOn;
                      _controller!.setFlashMode(
                        _isFlashOn ? FlashMode.torch : FlashMode.off,
                      );
                    });
                  },
                  onGalleryTap: _openGallery,
                  onCaptureTap: _takePicture,
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
