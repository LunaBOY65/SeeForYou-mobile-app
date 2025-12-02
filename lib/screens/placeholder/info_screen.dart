import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลแอป'), centerTitle: true),
      body: const Center(
        child: Text(
          'หน้าสำหรับคู่มือหรือประวัติการวิเคราะห์\n(แก้ภายหลังได้)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
