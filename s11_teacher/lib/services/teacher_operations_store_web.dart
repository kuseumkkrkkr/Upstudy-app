import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'teacher_operations_store.dart';

class TeacherOperationsStoreWeb implements TeacherOperationsStore {
  static const String _financeKey = 'teacher_ops.finance.v1';
  static const String _scheduleKey = 'teacher_ops.schedule.v1';

  @override
  Future<List<FinanceEntry>> listFinanceEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    final items = await _loadFinance();
    final startKey = formatDateKey(start);
    final endKey = formatDateKey(end);
    return items.where((entry) {
      final key = formatDateKey(entry.occurredOn);
      return key.compareTo(startKey) >= 0 && key.compareTo(endKey) <= 0;
    }).toList()..sort((a, b) {
      final dateCompare = b.occurredOn.compareTo(a.occurredOn);
      if (dateCompare != 0) return dateCompare;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  @override
  Future<FinanceSummary> financeSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final items = await listFinanceEntries(start: start, end: end);
    var income = 0.0;
    var expense = 0.0;
    for (final item in items) {
      if (item.type == FinanceEntryType.expense) {
        expense += item.amount;
      } else {
        income += item.amount;
      }
    }
    return FinanceSummary(income: income, expense: expense);
  }

  @override
  Future<void> upsertFinanceEntry(FinanceEntry entry) async {
    final items = await _loadFinance();
    final next = [entry, ...items.where((item) => item.id != entry.id)];
    await _saveFinance(next);
  }

  @override
  Future<void> deleteFinanceEntry(String id) async {
    final items = await _loadFinance();
    await _saveFinance(items.where((item) => item.id != id).toList());
  }

  @override
  Future<List<ScheduleEntry>> listScheduleEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    final items = await _loadSchedule();
    return items.where((entry) {
      return entry.startsAt.compareTo(start) >= 0 &&
          entry.startsAt.compareTo(end) <= 0;
    }).toList()..sort((a, b) {
      final startCompare = a.startsAt.compareTo(b.startsAt);
      if (startCompare != 0) return startCompare;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  @override
  Future<void> upsertScheduleEntry(ScheduleEntry entry) async {
    final items = await _loadSchedule();
    final next = [entry, ...items.where((item) => item.id != entry.id)];
    await _saveSchedule(next);
  }

  @override
  Future<void> deleteScheduleEntry(String id) async {
    final items = await _loadSchedule();
    await _saveSchedule(items.where((item) => item.id != id).toList());
  }

  Future<List<FinanceEntry>> _loadFinance() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_financeKey);
    if (raw == null || raw.isEmpty) return <FinanceEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <FinanceEntry>[];
      return decoded
          .whereType<Map>()
          .map((item) => FinanceEntry.fromMap(Map<String, Object?>.from(item)))
          .toList();
    } catch (_) {
      return <FinanceEntry>[];
    }
  }

  Future<void> _saveFinance(List<FinanceEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _financeKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<ScheduleEntry>> _loadSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scheduleKey);
    if (raw == null || raw.isEmpty) return <ScheduleEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ScheduleEntry>[];
      return decoded
          .whereType<Map>()
          .map((item) => ScheduleEntry.fromMap(Map<String, Object?>.from(item)))
          .toList();
    } catch (_) {
      return <ScheduleEntry>[];
    }
  }

  Future<void> _saveSchedule(List<ScheduleEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scheduleKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}

TeacherOperationsStore createTeacherOperationsStoreImpl() {
  return TeacherOperationsStoreWeb();
}
