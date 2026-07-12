import 'teacher_operations_store_stub.dart'
    if (dart.library.html) 'teacher_operations_store_web.dart'
    if (dart.library.io) 'teacher_operations_store_io.dart';

enum FinanceEntryType {
  income('income', '수입'),
  expense('expense', '지출');

  const FinanceEntryType(this.code, this.label);

  final String code;
  final String label;

  static FinanceEntryType fromCode(String value) {
    return value == expense.code ? expense : income;
  }
}

class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.occurredOn,
    required this.title,
    required this.category,
    required this.type,
    required this.amount,
    required this.memo,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime occurredOn;
  final String title;
  final String category;
  final FinanceEntryType type;
  final double amount;
  final String memo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'occurred_on': formatDateKey(occurredOn),
      'title': title,
      'category': category,
      'type': type.code,
      'amount': amount,
      'memo': memo,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, Object?> toJson() => toMap();

  static FinanceEntry fromMap(Map<String, Object?> map) {
    return FinanceEntry(
      id: map['id'].toString(),
      occurredOn: parseDateKey(map['occurred_on'].toString()),
      title: map['title']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      type: FinanceEntryType.fromCode(map['type']?.toString() ?? ''),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      memo: map['memo']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class FinanceSummary {
  const FinanceSummary({required this.income, required this.expense});

  final double income;
  final double expense;

  double get balance => income - expense;
}

class ScheduleEntry {
  const ScheduleEntry({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.title,
    required this.note,
    required this.calendarSynced,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String title;
  final String note;
  final bool calendarSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'starts_at': startsAt.millisecondsSinceEpoch,
      'ends_at': endsAt?.millisecondsSinceEpoch,
      'title': title,
      'note': note,
      'calendar_synced': calendarSynced ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, Object?> toJson() => toMap();

  static ScheduleEntry fromMap(Map<String, Object?> map) {
    return ScheduleEntry(
      id: map['id'].toString(),
      startsAt: DateTime.fromMillisecondsSinceEpoch(
        (map['starts_at'] as num?)?.toInt() ?? 0,
      ),
      endsAt: map['ends_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (map['ends_at'] as num?)?.toInt() ?? 0,
            ),
      title: map['title']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      calendarSynced: (map['calendar_synced'] as num?)?.toInt() == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

abstract class TeacherOperationsStore {
  static final TeacherOperationsStore instance = createTeacherOperationsStore();

  Future<List<FinanceEntry>> listFinanceEntries({
    required DateTime start,
    required DateTime end,
  });

  Future<FinanceSummary> financeSummary({
    required DateTime start,
    required DateTime end,
  });

  Future<void> upsertFinanceEntry(FinanceEntry entry);

  Future<void> deleteFinanceEntry(String id);

  Future<List<ScheduleEntry>> listScheduleEntries({
    required DateTime start,
    required DateTime end,
  });

  Future<void> upsertScheduleEntry(ScheduleEntry entry);

  Future<void> deleteScheduleEntry(String id);
}

TeacherOperationsStore createTeacherOperationsStore() {
  return createTeacherOperationsStoreImpl();
}

String formatDateKey(DateTime value) {
  final local = DateTime(value.year, value.month, value.day);
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

DateTime parseDateKey(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return DateTime.now();
  return DateTime(
    int.tryParse(parts[0]) ?? DateTime.now().year,
    int.tryParse(parts[1]) ?? DateTime.now().month,
    int.tryParse(parts[2]) ?? DateTime.now().day,
  );
}

String newLocalId(String prefix) {
  final now = DateTime.now().microsecondsSinceEpoch;
  return '${prefix}_$now';
}
