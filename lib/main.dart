import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seeforyou_app/screens/root/root_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        textTheme: GoogleFonts.sarabunTextTheme(),
      ),
      home: const RootScreen(),
    );
  }
}
