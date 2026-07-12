import 'teacher_operations_store.dart';

class TeacherOperationsStoreUnsupported implements TeacherOperationsStore {
  @override
  Future<List<FinanceEntry>> listFinanceEntries({
    required DateTime start,
    required DateTime end,
  }) {
    throw UnsupportedError('TeacherOperationsStore is not supported.');
  }

  @override
  Future<FinanceSummary> financeSummary({
    required DateTime start,
    required DateTime end,
  }) {
    throw UnsupportedError('TeacherOperationsStore is not supported.');
  }

  @override
  Future<void> upsertFinanceEntry(FinanceEntry entry) {
    throw UnsupportedError('TeacherOperationsStore is not supported.');
  }

  @override
  Future<void> deleteFinanceEntry(String id) {
    throw UnsupportedError('TeacherOperationsStore is not supported.');
  }

  @override
  Future<List<ScheduleEntry>> listScheduleEntries({
    required DateTime start,
    required DateTime end,
  }) {
    throw UnsupportedError('TeacherOperationsStore is not supported.');
  }

  @override
  Future<void> upsertScheduleEntry(ScheduleEntry entry) {
    throw UnsupportedError('TeacherOperationsStore is not supported.');
  }

  @override
  Future<void> deleteScheduleEntry(String id) {
    throw UnsupportedError('TeacherOperationsStore is not supported.');
  }
}

TeacherOperationsStore createTeacherOperationsStoreImpl() {
  return TeacherOperationsStoreUnsupported();
}
