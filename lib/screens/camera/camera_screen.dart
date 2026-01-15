import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seeforyou_app/screens/camera/components/camera_overlay.dart';
import 'package:seeforyou_app/services/expiry_scanner_service.dart';

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
  bool _isFlashOn = true; // สถานะไฟฉาย
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;

  final ExpiryScannerService _scannerService = ExpiryScannerService();

  bool _isScanning = false; // ป้องกันการประมวลผลซ้อนกัน
  DateTime? _lastVibrate; // ป้องกันการสั่นรัวเกินไป
  DateTime? _lastRotateWarning;
  Timer? _scanTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();

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
      //  กำหนด Format ให้เหมาะกับ ML Kit (Android=nv21, iOS=bgra8888)
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    try {
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture; // รอให้กล้องเปิดเสร็จก่อน

      // 1. ตั้งค่า Zoom (ต้องทำหลังจาก initialize เสร็จแล้วเท่านั้น)
      _maxZoom = await _controller!.getMaxZoomLevel();
      // ตรวจสอบว่า Zoom 1.5 ไม่เกินค่าสูงสุดที่เครื่องรับได้
      double targetZoom = 1.5;
      if (targetZoom > _maxZoom) targetZoom = _maxZoom;

      await _controller!.setZoomLevel(targetZoom);
      _currentZoom = targetZoom;

      // [เพิ่ม] บังคับเปิดไฟฉาย (Torch) ทันที! สำคัญมากสำหรับ OCR
      // ช่วยลด Noise และลดการสั่นไหวของภาพ (Shutter speed จะสูงขึ้น)
      try {
        await _controller!.setFlashMode(FlashMode.torch);
        _isFlashOn = true;
      } catch (e) {
        debugPrint("Device might not support Torch: $e");
      }

      // เปลี่ยนเป็นเริ่มระบบ "Snapshot Loop" แทน
      // ตั้ง Focus เป็น auto ไว้เพื่อให้ภาพชัดตอนถ่าย
      await _controller?.setFocusMode(FocusMode.auto);

      // เริ่มระบบสแกนทันที
      _startScanLoop();

      // สั่งเล่นเสียง (ไม่ต้องใส่ await) เพื่อให้มันทำงานขนานกันไป
      _playIntroAudio();
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
    if (mounted) setState(() {});
  }

  // ฟังก์ชันเล่นเสียง Intro
  Future<void> _playIntroAudio() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      // ใช้ mode lowLatency เพื่อให้เล่นทันที
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.play(AssetSource('audio/intro.mp3'));

      // รอให้เสียงรอบแรกเล่นจนจบ
      await _audioPlayer.onPlayerComplete.first;
      await Future.delayed(const Duration(seconds: 3));

      // ผู้ใช้ปิดหน้านี้ไปแล้ว (dispose) ไม่ต้องเล่นต่อ
      if (!mounted) return;

      // รอบที่ 2
      await _audioPlayer.play(AssetSource('audio/intro.mp3'));
    } catch (e) {
      debugPrint("Error playing intro audio: $e");
    }
  }

  @override
  void dispose() {
    // คืนทรัพยากร ML Kit
    _scannerService.dispose();
    _scanTimer?.cancel();
    _audioPlayer.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _startScanLoop() {
    // วนลูปถ่ายภาพทุกๆ 2 วินาที (ปรับเวลาได้ตามความเหมาะสม)
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) async {
      // ถ้ากำลังประมวลผลอยู่ หรือกล้องไม่พร้อม ให้ข้ามรอบนี้ไป
      if (_isScanning ||
          _controller == null ||
          !_controller!.value.isInitialized)
        return;

      _isScanning = true;
      try {
        // 1. ถ่ายภาพเบื้องหลัง (XFile)
        final imageFile = await _controller!.takePicture();

        // เรียกใช้ Logic จาก Service
        final result = await _scannerService.processImageSmart(imageFile.path);

        // DEBUG LOG: ดูข้อมูล
        if (result.expiryDate != null) {
          debugPrint("--------------------------------------------------");
          debugPrint("เจอวันหมดอายุ: ${result.expiryDate}");

          if (result.boundingBox != null) {
            // แปลงค่าตำแหน่งให้ดูง่ายๆ
            final rect = result.boundingBox!;
            debugPrint(
              "📍 ตำแหน่ง (x,y): (${rect.left.toStringAsFixed(0)}, ${rect.top.toStringAsFixed(0)})",
            );
            debugPrint(
              "📏 ขนาด (w,h): ${rect.width.toStringAsFixed(0)} x ${rect.height.toStringAsFixed(0)}",
            );

            // บอกโซนคร่าวๆ (สมมติภาพกว้างประมาณ 720-1080 px)
            // อันนี้เป็น Logic ง่ายๆ ไว้ดูเอง
            String zone = "ตรงกลาง";
            if (rect.top < 300) zone = "ด้านบน";
            if (rect.top > 800) zone = "ด้านล่าง";
            debugPrint("โซน: $zone");
          }

          if (result.angle != null) {
            debugPrint(" องศา: ${result.angle!.toStringAsFixed(2)}°");
            if (result.isWrongAngle)
              debugPrint("สถานะ: เอียงผิดปกติ (Warning)");
            else
              debugPrint("สถานะ: มุมปกติ (OK)");
          }
          debugPrint("--------------------------------------------------");
        }

        // [เพิ่ม] Logic Feedback สำหรับคนตาบอด
        if (result.expiryDate != null) {
          //  เจอวันที่แล้ว แต่เช็คก่อนว่ามุมถูกไหม
          if (result.isWrongAngle) {
            // เจอวันที่นะ แต่เอียง -> เตือนให้หมุน
            // (Priority สูงกว่า success เพราะถ้าอ่านเอียงๆ อาจผิดพลาดได้)
            _handleWrongAngle();
          } else {
            // เจอวันที่ และมุมดีแล้ว
            _handleFoundDate(result.expiryDate!);
          }
        } else if (result.isWrongAngle) {
          // เจอตัวหนังสือ แต่มุมผิด
          // ให้แจ้งเตือนให้หมุน
          _handleWrongAngle();
        } else if (result.hasText) {
          // ไม่เจอวันที่ แต่เจอตัวหนังสือ
          // สั่นเบาๆ
          HapticFeedback.selectionClick();
          debugPrint(">>> Found Text (Keep looking)");
        } else {
          // ไม่เจออะไรเลย
          debugPrint(">>> Empty Image");
        }

        // 3. ลบไฟล์ทิ้งเพื่อไม่ให้รกเครื่อง
        final file = File(imageFile.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("Scan Loop Error: $e");
      } finally {
        _isScanning = false;
      }
    });
  }

  // ฟังก์ชันจัดการเมื่อเจอวันที่ (แยกออกมาให้ดูง่าย)
  Future<void> _handleFoundDate(String date) async {
    debugPrint(">>> FOUND DATE: $date");
    final now = DateTime.now();
    if (_lastVibrate == null || now.difference(_lastVibrate!).inSeconds >= 3) {
      debugPrint(">>> FOUND! VIBRATE RAPIDLY !!! <<<");

      // [ย้ายขึ้นมาบนสุด] หยุดเสียง Intro/Rotate ทันทีที่เจอวัน เพื่อความเงียบสงัดก่อน Siren
      await _audioPlayer.stop();

      for (int i = 0; i < 3; i++) {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
      }

      await _audioPlayer.play(AssetSource('audio/Siren.mp3'));

      _lastVibrate = now;
    }
  }

  // [เพิ่ม] ฟังก์ชันจัดการเมื่อมุมผิด (เล่นเสียงเตือน)
  Future<void> _handleWrongAngle() async {
    debugPrint(">>> WRONG ANGLE: Rotate device");
    final now = DateTime.now();

    // เช็คเวลา: ไม่ให้เตือนบ่อยเกินไป (ทุกๆ 4 วินาที)
    if (_lastRotateWarning == null ||
        now.difference(_lastRotateWarning!).inSeconds >= 4) {
      // ถ้ากำลังเล่นเสียง Intro หรือ Siren อยู่ อย่าเพิ่งแทรก
      if (_audioPlayer.state != PlayerState.playing) {
        // เป็นเสียงพูดเช่น "กรุณาหมุน"
        await _audioPlayer.play(AssetSource('audio/rotate_warning.mp3'));
      }

      _lastRotateWarning = now;
    }
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
      _scanTimer?.cancel(); // + หยุดการ Scan อัตโนมัติก่อนถ่ายจริง

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
