import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'teacher_operations_store.dart';

class TeacherOperationsStoreIo implements TeacherOperationsStore {
  static const String _dbName = 's11_teacher_operations.db';
  static const int _dbVersion = 1;
  static const String _financeTable = 'teacher_finance_entries';
  static const String _scheduleTable = 'teacher_schedule_entries';

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
            await _createSchema(database);
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

  static Future<void> _createSchema(Database database) async {
    final batch = database.batch();
    batch.execute('''
CREATE TABLE IF NOT EXISTS $_financeTable (
  id TEXT PRIMARY KEY,
  occurred_on TEXT NOT NULL,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  type TEXT NOT NULL,
  amount REAL NOT NULL,
  memo TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
    batch.execute('''
CREATE INDEX IF NOT EXISTS idx_teacher_finance_date
ON $_financeTable (occurred_on, type)
''');
    batch.execute('''
CREATE TABLE IF NOT EXISTS $_scheduleTable (
  id TEXT PRIMARY KEY,
  starts_at INTEGER NOT NULL,
  ends_at INTEGER,
  title TEXT NOT NULL,
  note TEXT NOT NULL,
  calendar_synced INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
    batch.execute('''
CREATE INDEX IF NOT EXISTS idx_teacher_schedule_range
ON $_scheduleTable (starts_at)
''');
    await batch.commit(noResult: true);
  }

  @override
  Future<List<FinanceEntry>> listFinanceEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _open();
    final rows = await db.query(
      _financeTable,
      where: 'occurred_on BETWEEN ? AND ?',
      whereArgs: [formatDateKey(start), formatDateKey(end)],
      orderBy: 'occurred_on DESC, updated_at DESC',
    );
    return rows.map(FinanceEntry.fromMap).toList();
  }

  @override
  Future<FinanceSummary> financeSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _open();
    final rows = await db.rawQuery(
      '''
SELECT type, COALESCE(SUM(amount), 0) AS total
FROM $_financeTable
WHERE occurred_on BETWEEN ? AND ?
GROUP BY type
''',
      [formatDateKey(start), formatDateKey(end)],
    );
    var income = 0.0;
    var expense = 0.0;
    for (final row in rows) {
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      if (row['type'] == FinanceEntryType.expense.code) {
        expense = total;
      } else {
        income = total;
      }
    }
    return FinanceSummary(income: income, expense: expense);
  }

  @override
  Future<void> upsertFinanceEntry(FinanceEntry entry) async {
    final db = await _open();
    await db.insert(
      _financeTable,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteFinanceEntry(String id) async {
    final db = await _open();
    await db.delete(_financeTable, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<ScheduleEntry>> listScheduleEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _open();
    final rows = await db.query(
      _scheduleTable,
      where: 'starts_at BETWEEN ? AND ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'starts_at ASC, updated_at DESC',
    );
    return rows.map(ScheduleEntry.fromMap).toList();
  }

  @override
  Future<void> upsertScheduleEntry(ScheduleEntry entry) async {
    final db = await _open();
    await db.insert(
      _scheduleTable,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteScheduleEntry(String id) async {
    final db = await _open();
    await db.delete(_scheduleTable, where: 'id = ?', whereArgs: [id]);
  }
}

TeacherOperationsStore createTeacherOperationsStoreImpl() {
  return TeacherOperationsStoreIo();
}
