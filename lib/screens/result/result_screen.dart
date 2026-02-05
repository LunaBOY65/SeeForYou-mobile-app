import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:seeforyou_app/services/api_service.dart';

class ResultScreen extends StatefulWidget {
  final VoidCallback? onRetake;
  final String? imagePath;

  const ResultScreen({super.key, this.onRetake, this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isLoading = true;
  String _resultText = "กำลังวิเคราะห์ภาพ... กรุณารอสักครู่";
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _localAudioPath; // เปลี่ยนจากเก็บ URL เป็นเก็บ Path ไฟล์ในเครื่องแทน

  @override
  void initState() {
    super.initState();
    _analyzeImage();
  }

  // ฟังก์ชันสำหรับคืนทรัพยากร
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ฟังก์ชันสั่งเล่นเสียง
  Future<void> _playAudio() async {
    // เล่นจากไฟล์ในเครื่อง (ปลอดภัย 100% ไม่ยิง Server ซ้ำ)
    if (_localAudioPath != null) {
      try {
        await _audioPlayer.stop();
        // ใช้ DeviceFileSource แทน UrlSource
        await _audioPlayer.play(DeviceFileSource(_localAudioPath!));
      } catch (e) {
        debugPrint("Error playing local audio: $e");
      }
    } else {
      debugPrint("Audio file not ready yet");
    }
  }

  // ฟังก์ชันยิง API ของจริง
  Future<void> _analyzeImage() async {
    if (widget.imagePath == null) {
      setState(() {
        _isLoading = false;
        _resultText = "ไม่พบไฟล์รูปภาพ กรุณาถ่ายใหม่";
      });
      return;
    }

    // เล่นเสียงพูด "กำลังประมวลผล"
    await _audioPlayer.play(AssetSource('audio/in_progress.mp3'));

    try {
      final imageFile = File(widget.imagePath!);

      // ยิง API จริงทันที (ไม่ต้องรอ 5 วิแล้ว)
      final response = await ApiService.uploadImage(imageFile);

      // เช็คผลลัพธ์
      if (response.statusCode == 200) {
        // แปลงข้อมูล JSON ที่ได้จาก Python Server
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final message = data['message'] ?? "ไม่สามารถอ่านค่าได้";
        final audioUrl = data['audio_url'];

        // --- เพิ่ม Logic: โหลดไฟล์เสียงเก็บลงเครื่องทันที ---
        String? localPath;
        if (audioUrl != null) {
          try {
            // 1. โหลดไฟล์
            final audioData = await http.get(Uri.parse(audioUrl));
            // 2. หาที่เก็บชั่วคราว (ใช้ Directory.systemTemp ไม่ต้องลง lib เพิ่ม)
            final tempDir = Directory.systemTemp;
            final tempFile = File('${tempDir.path}/tts_result.mp3');
            // 3. เขียนไฟล์ลงเครื่อง
            await tempFile.writeAsBytes(audioData.bodyBytes);
            localPath = tempFile.path;
          } catch (e) {
            debugPrint("Error downloading audio: $e");
          }
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _resultText = message;
            _localAudioPath = localPath; // เก็บ Path ในเครื่องแทน URL
          });

          // เล่นเสียงอัตโนมัติหลังวิเคราะห์เสร็จ
          _playAudio();
        }
      } else {
        if (mounted) {
          setState(() {
            // แสดงข้อความ Error ตามจริง หรือบอกว่าเชื่อมต่อไม่ได้
            _isLoading = false;
            _resultText =
                "เกิดข้อผิดพลาดจากเซิร์ฟเวอร์ (Code: ${response.statusCode})";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _resultText = "การเชื่อมต่อขัดข้อง: $e";
        });
      }
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
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              // ถ้ามี path ให้โชว์รูป ถ้าไม่มีโชว์ icon เดิม
              child: widget.imagePath != null
                  ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
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
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFD700),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          _resultText,
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
                  //  ปุ่มซ้าย ถ่ายใหม่ กลับไปหน้ากล้อง
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
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onRetake?.call();
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
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _playAudio();
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
