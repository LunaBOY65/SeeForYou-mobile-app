import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'vision_helper.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  // สร้างตาราง (Table) ที่นี่
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePath TEXT,
        resultText TEXT,
        timestamp TEXT
      )
    ''');
  }

  // ฟังก์ชันเพิ่มข้อมูล (Insert)
  Future<int> insertHistory(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('history', row);
  }

  // ฟังก์ชันดึงข้อมูลทั้งหมด (Select All)
  Future<List<Map<String, dynamic>>> getHistory() async {
    Database db = await database;
    return await db.query(
      'history',
      orderBy: "timestamp DESC",
    ); // เรียงจากใหม่ไปเก่า
  }

  // ฟังก์ชันลบข้อมูล (Optional)
  Future<void> deleteHistory(int id) async {
    Database db = await database;
    await db.delete('history', where: 'id = ?', whereArgs: [id]);
  }
}
