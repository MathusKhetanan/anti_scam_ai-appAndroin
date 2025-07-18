// lib/database/scam_history_db.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ScamHistoryDB {
  static final ScamHistoryDB _instance = ScamHistoryDB._internal();
  factory ScamHistoryDB() => _instance;
  ScamHistoryDB._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'scam_history.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scam_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message_text TEXT NOT NULL,
            scam_probability REAL NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<int> insertHistory(String message, double probability) async {
    final db = await database;
    return await db.insert('scam_history', {
      'message_text': message,
      'scam_probability': probability,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await database;
    return await db.query('scam_history', orderBy: 'timestamp DESC');
  }
}
