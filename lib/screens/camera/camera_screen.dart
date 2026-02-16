import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seeforyou_app/screens/camera/components/camera_overlay.dart';
import 'package:seeforyou_app/screens/camera/controllers/scan_logic_controller.dart';
import 'package:seeforyou_app/services/audio_feedback_service.dart';

/// หน้าจอหลักสำหรับกล้องถ่ายภาพ (Camera Screen)
/// หน้าที่คือ แสดงภาพกล้อง, จัดการปุ่มเปิด - ปิดแฟลช, เลือกรูปจากแกลเลอรี
/// เชื่อมต่อกับระบบ Auto Scan เพื่อค้นหาวันหมดอายุอัตโนมัติด้วย
class CameraScreen extends StatefulWidget {
  /// ฟังก์ชัน Callback ที่จะส่งที่อยู่ไฟล์รูป (path) กลับไปเมื่อสแกนสำเร็จ หรือเลือกรูปจากแกลเลอรี
  final Function(String path)? onImageSelected;

  const CameraScreen({super.key, this.onImageSelected});

  @override
  // สร้าง State ของ CameraScreen เพื่อจัดการกับข้อมูลและการเปลี่ยนแปลงต่างๆ ในหน้านี้
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // ตัวแปรจัดการกล้อง
  // ควบคุมการตั้งค่าและการทำงานของกล้อง
  // รอให้กล้องเตรียมความพร้อมเสร็จ
  // เก็บสถานะว่ากำลังเปิดไฟฉายอยู่หรือไม่
  // ตัวแปรล็อคปุ่มแฟลชชั่วคราว (กันคนกดรัว) เพื่อป้องกันการกดซ้ำขณะรอฮาร์ดแวร์ทำงาน
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isFlashOn = false;
  bool _isTogglingFlash = false;

  // ตัวแปรระบบ AI และเสียงเตือน
  // ควบคุมลูปการถ่ายภาพส่งให้ AI ตรวจสอบ
  // จัดการเสียงเตือนและระบบสั่น
  late ScanLogicController _scanController;
  final AudioFeedbackService _feedbackService = AudioFeedbackService();

  @override
  void initState() {
    super.initState();

    // เริ่มต้นระบบสแกนอัตโนมัติ พร้อมผูกเงื่อนไขว่าถ้าสแกนเจอวันที่แล้วให้ทำอะไรต่อ...
    _scanController = ScanLogicController(
      _feedbackService,
      // เมื่อเจอรูปที่ใช่ ให้ส่ง path ส่งรูปไปใช้งานต่อ เช่น ส่งกลับไปหน้า ResultScreen
      onFound: (path) => widget.onImageSelected?.call(path),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    // หากล้องทั้งหมดในเครื่อง แล้วดึงตัวแรกมาใช้ (ปกติคือกล้องหลังตัวหลัก)
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    // ตั้งค่ากล้องก่อนเริ่มใช้งาน
    _controller = CameraController(
      firstCamera,
      // ปรับความละเอียดเพื่อให้ AI อ่านตัวหนังสือได้ชัดเจนขึ้น
      // ปิดไมค์ เพราะถ่ายแค่ภาพนิ่ง ไม่ได้อัดวีดีโอ
      // ตั้งค่า Format ภาพให้ตรงกับระบบ OS กันแอปเด้ง
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    try {
      // สั่งเปิดกล้อง
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;

      // ค่าเริ่มต้น ปิดไฟฉาย ปรับโฟกัสและแสงอัตโนมัติ
      await _controller!.setFlashMode(FlashMode.off);
      await _controller?.setFocusMode(FocusMode.auto);
      await _controller?.setExposureMode(ExposureMode.auto);

      // เริ่มวนลูปสั่งถ่ายภาพตามรอบ เพื่อส่งให้ AI ตรวจสอบ และเล่นเสียงพูดแนะนำการใช้งาน
      _scanController.startLoop(_controller!);
      _feedbackService.playIntro();
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // คืนทรัพยากรทุกอย่างตอนผู้ใช้ออกจากหน้านี้
    // สำคัญมาก! ต้องเคลียร์การทำงานทุกอย่างตอนผู้ใช้ออกจากหน้านี้
    // เพื่อไม่ให้กล้องแอบเปิดค้างไว้ จะทำให้มือถือร้อน แบตไหล และแอปอื่นใช้กล้องไม่ได้
    _scanController.dispose();
    _feedbackService.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// ฟังก์ชันเปิดแกลเลอรีเพื่อให้ผู้ใช้เลือกรูปภาพในเครื่อง (มีไว้เฉยๆ)
  Future<void> _openGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    // ถ้ามีรูปที่เลือกมา ให้ส่งกลับไปประมวลผลต่อเลย
    if (image != null) widget.onImageSelected?.call(image.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          // ยืนยันว่ากล้องเตรียมพร้อมเสร็จแล้ว ค่อยโชว์ UI
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                // 1. แสดงภาพจากกล้องแบบเต็มหน้าจอ
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CameraPreview(_controller!),
                ),
                // 2. UI ปุ่มกดต่างๆ โปร่งใสทับซ้อนวางลอยทับอยู่บนภาพกล้อง (ปุ่มเปิดไฟฉาย, ปุ่มแกลเลอรี)
                CameraOverlay(
                  isFlashOn: _isFlashOn,

                  // ฟังก์ชันเปิด-ปิดแฟลช (ป้องกันผู้ใช้กดรัวจนฮาร์ดแวร์กล้องค้าง)
                  onToggleFlash: () async {
                    // 1. ด่านสกัด
                    // เช็คว่าตอนนี้ระบบกำลังยุ่งกับการเปิด-ปิดไฟฉายอยู่ไหม (_isTogglingFlash เป็น true ไหม)
                    // ถ้ากำลังยุ่งอยู่ คำสั่ง return จะทำหน้าที่ดีดการกดครั้งนี้ทิ้งไป และโค้ดที่อยู่ด้านล่างจะไม่ถูกทำงานเตะออกจากฟังก์ชัน
                    if (_isTogglingFlash) return;

                    // 2. ถ้าผ่านด่านข้างบนมาได้ (แปลว่าระบบว่างอยู่) เริ่มอัปเดตหน้าจอ UI ทันทีเลย
                    // ให้ผู้ใช้เห็นว่าปุ่มแฟลชถูกกดแล้ว สถานะเปลี่ยนเพื่อให้รู้ว่าระบบกำลังทำงานอยู่
                    setState(() {
                      // ล็อคปุ่มทันที (เปิดโหมดกำลังยุ่ง) ที่นิ้วแตะ เพื่อป้องกันการกดรัวๆ ขณะฮาร์ดแวร์ทำงาน
                      // สลับสถานะ หรือ ไอคอน (ปิด -> เปิด, เปิด -> ปิด)
                      _isTogglingFlash = true;
                      _isFlashOn = !_isFlashOn;
                    });

                    // 3. เล่นเสียงบอกสถานะ
                    // ทำตรงนี้เลยไม่ต้องรอให้ฮาร์ดแวร์ทำงานเสร็จ เพราะการสั่งเปิด - ปิดไฟฉายอาจใช้เวลานิดหน่อย
                    if (_isFlashOn) {
                      _feedbackService.playFlashOn();
                    } else {
                      _feedbackService.playFlashOff();
                    }

                    // 4. สั่งฮาร์ดแวร์เปิด-ปิดไฟฉายที่ตัวมือถือจริงๆ (ขั้นตอนนี้กินเวลาวินาที)
                    try {
                      // ใช้ await เพื่อสั่งให้โปรแกรม หยุดรอ จนกว่าไฟจะติดหรือดับจริงๆ
                      await _controller!.setFlashMode(
                        _isFlashOn ? FlashMode.torch : FlashMode.off,
                      );
                    } catch (e) {
                      // ถ้าเกิดเหตุไม่คาดฝัน เช่น ระบบกล้องรวน ระบบจะแวะมาเข้าที่ catch เพื่อไม่ให้แอปเด้งหลุด
                      debugPrint("Flash Toggle Error: $e");
                    } finally {
                      // 5. ปลดล็อคประตู ซึ่งจะทำงานเสมอ ไม่ว่าจะสำเร็จหรือพัง
                      // mounted เช็คว่าผู้ใช้ยังเปิดอยู่ไหม ปิดหน้านี้หนีไปใช่ไหม
                      // ถ้ายังอยู่ ก็สั่งปลดล็อคตัวแปร ให้กลับมากดปุ่มแฟลชรอบต่อไปได้
                      if (mounted) setState(() => _isTogglingFlash = false);
                    }
                  },
                  onGalleryTap: _openGallery,
                ),
              ],
            );
          } else {
            // ระหว่างรอกล้องเปิด ให้แสดงโหลดหมุนๆ
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            );
          }
        },
      ),
    );
  }
}
