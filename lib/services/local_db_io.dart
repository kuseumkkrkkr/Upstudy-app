import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'local_db.dart';

class LocalDbIo implements LocalDb {
  LocalDbIo();

  static const String _dbName = 's11_local.db';
  static const int _dbVersion = 1;
  static const String _tableKeyValue = 'kv_store';

  Database? _db;
  Completer<Database>? _opening;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    if (_opening != null) return _opening!.future;
    final completer = Completer<Database>();
    _opening = completer;
    () async {
      try {
        final dbPath = await getDatabasesPath();
        final path = p.join(dbPath, _dbName);
        final db = await openDatabase(
          path,
          version: _dbVersion,
          onCreate: (database, _) async {
            await database.execute('''
CREATE TABLE IF NOT EXISTS $_tableKeyValue (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
          },
        );
        _db = db;
        completer.complete(db);
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _opening = null;
      }
    }();
    return completer.future;
  }

  @override
  Future<String?> getString(String key) async {
    final db = await _open();
    final rows = await db.query(
      _tableKeyValue,
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  @override
  Future<void> setString(String key, String value) async {
    final db = await _open();
    await db.insert(
      _tableKeyValue,
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String key) async {
    final db = await _open();
    await db.delete(
      _tableKeyValue,
      where: 'key = ?',
      whereArgs: [key],
    );
  }
}

LocalDb createLocalDbImpl() => LocalDbIo();
