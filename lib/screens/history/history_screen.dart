import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติ'), centerTitle: true),
      body: const Center(
        child: Text(
          'ประวัติการวิเคราะห์\n(แก้ภายหลังได้)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
