import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

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
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(width: 2),
              ),
              child: const Center(child: Text('ภาพที่เพิ่งถ่าย (TODO)')),
            ),
            const SizedBox(height: 16),

            // กล่องข้อความอธิบาย
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(width: 1),
                ),
                child: SingleChildScrollView(
                  child: Text(sampleText, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ปุ่มเล่นเสียง (เชื่อม Botnoi Voice API ภายหลัง)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: เรียก Botnoi Voice API play
                },
                icon: const Icon(Icons.volume_up),
                label: const Text('เล่นเสียง'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
