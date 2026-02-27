import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/svg.dart';
import 'package:seeforyou_app/services/api_service.dart';

class ResultScreen extends StatefulWidget {
  final VoidCallback? onRetake;
  final String? imagePath;
  const ResultScreen({super.key, this.onRetake, this.imagePath});

  @override
  // สร้าง State ของ ResultScreen เพื่อจัดการกับข้อมูลและการเปลี่ยนแปลงต่างๆ ในหน้านี้
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  // ตัวแปรควบคุมสถานะการโหลดข้อมูล (true = กำลังโหลด, false = โหลดเสร็จแล้ว)
  bool _isLoading = false;

  // ข้อความผลลัพธ์ (คำอธิบายภาพ) ที่จะนำไปแสดงบนหน้าจอ
  String _resultText = "";

  // เครื่องเล่นเสียง สำหรับเปิดเสียงแจ้งเตือนและเสียงอ่านคำอธิบายภาพ
  final AudioPlayer _audioPlayer = AudioPlayer();

  // สำหรับระบบปุ่มกด 2 จังหวะ
  // เก็บชื่อปุ่ม
  // เก็บเวลาที่กดครั้งล่าสุด
  String? _focusedButton;
  DateTime? _lastTapTime;

  // ลิงก์ไฟล์เสียงผลลัพธ์ที่ได้กลับมาจาก API
  String? _audioUrl;

  @override
  void initState() {
    super.initState();
    if (widget.imagePath != null) {
      /// ถ้ามีรูปส่งมาจริงๆ ถึงจะค่อยเปลี่ยนป้ายเป็น กำลังยุ่ง
      _isLoading = true;
      _analyzeImage();
    } else {
      // กรณีเกิดข้อผิดพลาดหรือไม่มีรูปภาพถูกส่งมา ให้แสดงข้อความรอรับภาพ
      _resultText = "รอรับภาพ...";
    }
  }

  @override
  void dispose() {
    // เคลียร์หน่วยความจำเมื่อผู้ใช้ปิดหน้านี้
    // สำคัญมาก ต้องสั่งหยุดตัวเล่นเสียง เพื่อไม่ให้แอปแอบเล่นเสียงค้างหรือกินแบต
    _audioPlayer.dispose();
    super.dispose();
  }

  // ฟังก์ชันสำหรับเล่นเสียงอ่านคำอธิบายภาพที่ได้จาก API
  Future<void> _playAudio() async {
    // สั่งหยุดเสียงที่อาจจะเล่นค้างอยู่ก่อนเสมอ
    await _audioPlayer.stop();

    // เช็คว่ามีลิงก์เสียงส่งมา และต้องไม่เป็นค่าว่าง ("")
    if (_audioUrl != null && _audioUrl != "") {
      try {
        // ลองเล่นเสียงผลลัพธ์ที่ได้จาก Botnoi (ผ่านเน็ต)
        await _audioPlayer.play(UrlSource(_audioUrl!));
      } catch (_) {
        // ถ้าเน็ตผู้ใช้หลุดกระทันหันตอนกำลังจะเล่นเสียง ให้เล่นเสียงแจ้งเตือนจากในเครื่องแทน
        await _audioPlayer.play(AssetSource('audio/error_sound.mp3'));
      }
    } else {
      // ถ้าเซิร์ฟเวอร์ Botnoi ล่ม หรือ พอยท์หมด (ไม่มีลิงก์ส่งมา)
      // ให้เล่นเสียงแจ้งเตือนจากในเครื่อง เพื่อไม่ให้ผู้ใช้พิการทางสายตารอเก้อ
      await _audioPlayer.play(AssetSource('audio/error_sound.mp3'));
    }
  }

  // ฟังก์ชันส่งรูปภาพขึ้นไปให้เซิร์ฟเวอร์ (API) ประมวลผลและรอรับคำอธิบายกลับมา
  Future<void> _analyzeImage() async {
    final stopwatch = Stopwatch()..start();
    debugPrint("[PERFORMANCE] Start measuring End-to-End latency...");

    // 1. เล่นเสียงบอกผู้ใช้ว่า "กำลังประมวลผล" เพื่อให้รู้ว่าแอปไม่ได้ค้าง
    _audioPlayer.play(AssetSource('audio/in_progress.mp3'));

    try {
      // ทำการ Resize และบีบอัดภาพก่อนส่ง
      File imageFile = File(widget.imagePath!);

      // สร้างชื่อไฟล์ใหม่สำหรับรูปที่ถูกย่อแล้ว (เติมคำว่า _resized ต่อท้าย)
      final String targetPath = widget.imagePath!.replaceAll(
        RegExp(r'\.\w+$'),
        '_resized.jpg',
      );

      debugPrint(
        "[API_UPLOAD] Original File Size: ${imageFile.lengthSync()} bytes",
      );

      // สั่งย่อขนาดภาพให้ด้านใดด้านหนึ่งไม่เกิน 640 พิกเซล (มาตรฐานที่ YOLO ชอบ)
      final XFile?
      compressedXFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        minWidth: 640,
        minHeight: 640,
        quality:
            80, // ปรับคุณภาพการบีบอัดได้ที่ตรงนี้ (0-100) ยิ่งต่ำยิ่งบีบอัดมาก แต่คุณภาพลดลง
      );

      // ตรวจสอบว่าบีบอัดสำเร็จไหม ถ้าสำเร็จให้เปลี่ยนมาใช้ไฟล์ใหม่นี้แทนไฟล์เดิม
      if (compressedXFile != null) {
        imageFile = File(compressedXFile.path);
        debugPrint(
          "[API_UPLOAD] Resized File Size: ${imageFile.lengthSync()} bytes",
        );
      } else {
        debugPrint("[API_UPLOAD] Warning: Resize failed, using original file.");
      }
      debugPrint("[API_UPLOAD] Sending image to server...");
      final response = await ApiService.uploadImage(imageFile);

      // 2. ตรวจสอบสถานะการตอบกลับ (Status Code 200 หมายถึงทำงานสำเร็จ)
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final message = data['message'] ?? "ไม่สามารถอ่านค่าได้";
        final audioUrl = data['audio_url'];

        if (mounted) {
          // setState คือการสั่งให้หน้าจอรีเฟรชตัวเอง เพื่อแสดงข้อมูลใหม่ที่เราเพิ่งได้มา
          setState(() {
            _isLoading = false;
            _resultText = message;
            _audioUrl = audioUrl;
          });

          // หยุดจับเวลาและปริ้นผลลัพธ์ กรณีสำเร็จ
          stopwatch.stop();
          debugPrint(
            "[PERFORMANCE] End-to-End Latency (Success): ${stopwatch.elapsedMilliseconds} ms",
          );

          _playAudio();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _resultText =
                "เกิดข้อผิดพลาดจากเซิร์ฟเวอร์ (Code: ${response.statusCode})";
            _audioUrl = "";
          });

          // หยุดจับเวลาและปริ้นผลลัพธ์ กรณี API ตอบกลับเป็น Error
          stopwatch.stop();
          debugPrint(
            "[PERFORMANCE] End-to-End Latency (Server Error): ${stopwatch.elapsedMilliseconds} ms",
          );

          // พอมันเห็นว่าเป็นค่าว่าง ไปเรียกเสียง error_sound.mp3 อัตโนมัติ
          _playAudio();
        }
      }
    } catch (e) {
      // catch จะทำงานก็ต่อเมื่อเกิดข้อผิดพลาดรุนแรง เช่น เน็ตหลุด หรือ API ล่ม
      if (mounted) {
        setState(() {
          _isLoading = false;
          _resultText = "การเชื่อมต่อขัดข้อง: $e";
          _audioUrl = "";
        });

        // หยุดจับเวลาและปริ้นผลลัพธ์ (กรณีเน็ตหลุด หรือเกิด Error ร้ายแรง)
        stopwatch.stop();
        debugPrint(
          "[PERFORMANCE] End-to-End Latency (Network/Exception): ${stopwatch.elapsedMilliseconds} ms",
        );

        _playAudio();
      }
    }
  }

  // ฟังก์ชันสำหรับจัดการปุ่มกด 2 จังหวะ (เช่น ปุ่มเล่นเสียง หรือปุ่มถ่ายใหม่)
  Future<void> _handleTwoStepButton(
    String key,
    String audioFile,
    VoidCallback onConfirmed,
  ) async {
    final now = DateTime.now();

    // เช็คเงื่อนไขว่าเป็นการกดเบิ้ลไหม
    bool isDoubleTap =
        _focusedButton == key &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 1500;

    // สั่งหยุดเสียงเดิมที่อาจจะเล่นค้างอยู่ และสั่งให้สั่นเพื่อตอบสนองการกด
    await _audioPlayer.stop();
    HapticFeedback.heavyImpact();
    if (isDoubleTap) {
      // ถ้าเป็นการกดเบิ้ลจริง -> ล้างค่าความจำทิ้ง และสั่งให้ปุ่มทำงาน
      _focusedButton = null;
      onConfirmed();
    } else {
      // ถ้าเป็นการกดครั้งแรก หรืออื่นๆ -> จำปุ่มและเวลาไว้ แล้วเล่นเสียงบอกชื่อปุ่ม
      _focusedButton = key;
      _lastTapTime = now;
      await _audioPlayer.play(AssetSource('audio/$audioFile'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คำอธิบายภาพ'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 250,
              width: double.infinity,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFFF5F5F5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: widget.imagePath != null
                  ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
                  // ถ้าไม่มีรูป (เป็น null) ให้แสดงไอคอนรูปภาพสีเทาแทน
                  : Center(
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
                  border: Border.all(color: const Color(0xFFFFD700), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isLoading
                    // ถ้า _isLoading เป็น true (กำลังประมวลผล) ให้แสดงหมุนๆ
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFD700),
                        ),
                      )
                    // ถ้าโหลดเสร็จแล้ว ให้แสดงข้อความคำอธิบาย
                    : SingleChildScrollView(
                        child: Text(
                          _resultText.isEmpty ? "ไม่พบข้อมูล" : _resultText,
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

            // ปุ่มเล่นเสียง
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                      ),
                      onPressed: () => _handleTwoStepButton(
                        'retake',
                        'take_photo_again.mp3',
                        () => widget.onRetake?.call(),
                      ),
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

                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => _handleTwoStepButton(
                        'play',
                        'replay_audio.mp3',
                        () => _playAudio(),
                      ),
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
                              fontSize: 24,
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
