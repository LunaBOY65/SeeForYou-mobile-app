// ปรับค่า เช่น ภาษา, ความเร็วเสียง, URL ของ backend (ดึงจาก constants)

import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า'), centerTitle: true),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Server URL'),
            subtitle: Text(backendBaseUrl),
            trailing: const Icon(Icons.edit),
            onTap: () {
              // ถ้าจะให้แก้ในแอป ค่อยเพิ่ม dialog ทีหลัง
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('ภาษาเสียงพูด'),
            subtitle: Text('ไทย (ปรับได้ในอนาคต)'),
          ),
          const ListTile(title: Text('ความเร็วเสียง'), subtitle: Text('ปกติ')),
        ],
      ),
    );
  }
}
