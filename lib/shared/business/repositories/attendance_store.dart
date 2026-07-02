import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/services/storage/local_db.dart';

const _attendanceStoreKey = 'attendance_log_v1';

class AttendanceSnapshot {
  const AttendanceSnapshot({
    required this.weekKey,
    required this.weekCount,
    required this.lastAttendanceDateKey,
  });

  final String weekKey;
  final int weekCount;
  final String lastAttendanceDateKey;

  factory AttendanceSnapshot.empty() {
    return const AttendanceSnapshot(
      weekKey: '',
      weekCount: 0,
      lastAttendanceDateKey: '',
    );
  }

  factory AttendanceSnapshot.fromJson(Map<String, dynamic> json) {
    return AttendanceSnapshot(
      weekKey: json['week_key']?.toString() ?? '',
      weekCount: (json['week_count'] as num?)?.toInt() ?? 0,
      lastAttendanceDateKey: json['last_attendance']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'week_key': weekKey,
      'week_count': weekCount,
      'last_attendance': lastAttendanceDateKey,
    };
  }

  AttendanceSnapshot copyWith({
    String? weekKey,
    int? weekCount,
    String? lastAttendanceDateKey,
  }) {
    return AttendanceSnapshot(
      weekKey: weekKey ?? this.weekKey,
      weekCount: weekCount ?? this.weekCount,
      lastAttendanceDateKey:
          lastAttendanceDateKey ?? this.lastAttendanceDateKey,
    );
  }
}

class AttendanceStore {
  static final ValueNotifier<AttendanceSnapshot> notifier =
      ValueNotifier<AttendanceSnapshot>(AttendanceSnapshot.empty());
  static bool _loaded = false;
  static String _storageKey = _attendanceStoreKey;
  static String? _activeUsername;

  static Future<void> _syncUserScope() async {
    final scopedFromAuth = (await AuthStorage.instance.readUsername())?.trim();
    final prefs = await SharedPreferences.getInstance();
    final scopedFromLegacy = prefs.getString('username')?.trim();
    final username = (scopedFromAuth != null && scopedFromAuth.isNotEmpty)
        ? scopedFromAuth
        : scopedFromLegacy;
    final scopedKey = (username == null || username.isEmpty)
        ? _attendanceStoreKey
        : '$_attendanceStoreKey::$username';
    if (_activeUsername == username && _storageKey == scopedKey) return;
    _activeUsername = username;
    _storageKey = scopedKey;
    _loaded = false;
    notifier.value = AttendanceSnapshot.empty();
  }

  static Future<AttendanceSnapshot> load() async {
    await _syncUserScope();
    if (_loaded) return notifier.value;
    final raw = await _loadRaw();
    AttendanceSnapshot snapshot = AttendanceSnapshot.empty();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          snapshot = AttendanceSnapshot.fromJson(decoded);
        }
      } catch (_) {
        // Ignore corrupted payloads.
      }
    }
    final normalized = _normalizeForWeek(snapshot, DateTime.now());
    if (!identical(normalized, snapshot)) {
      await _persist(normalized);
      return normalized;
    }
    notifier.value = snapshot;
    _loaded = true;
    return snapshot;
  }

  static Future<AttendanceSnapshot> ensureDailyAttendance() async {
    await _syncUserScope();
    final snapshot = _loaded ? notifier.value : await load();
    final now = DateTime.now();
    final weekKey = _weekKeyFor(now);
    var updated = snapshot;
    if (snapshot.weekKey != weekKey) {
      updated = updated.copyWith(weekKey: weekKey, weekCount: 0);
    }
    final todayKey = _formatDateKey(now);
    if (updated.lastAttendanceDateKey != todayKey) {
      final nextCount = updated.weekCount + 1;
      updated = updated.copyWith(
        weekKey: weekKey,
        weekCount: nextCount > 7 ? 7 : nextCount,
        lastAttendanceDateKey: todayKey,
      );
    }
    if (!identical(updated, snapshot)) {
      await _persist(updated);
    }
    return notifier.value;
  }

  static bool isTodayChecked(AttendanceSnapshot snapshot) {
    return snapshot.lastAttendanceDateKey == _formatDateKey(DateTime.now());
  }

  static String weekRangeLabel(DateTime date) {
    final start = _weekStart(date);
    final end = start.add(const Duration(days: 6));
    String format(DateTime value) =>
        '${value.month}.${value.day.toString().padLeft(2, '0')}';
    return '${format(start)}~${format(end)}';
  }

  static AttendanceSnapshot _normalizeForWeek(
    AttendanceSnapshot snapshot,
    DateTime date,
  ) {
    final currentWeekKey = _weekKeyFor(date);
    if (snapshot.weekKey == currentWeekKey) return snapshot;
    return snapshot.copyWith(weekKey: currentWeekKey, weekCount: 0);
  }

  static Future<void> _persist(AttendanceSnapshot snapshot) async {
    await _syncUserScope();
    notifier.value = snapshot;
    _loaded = true;
    await LocalDb.instance
        .setString(_storageKey, jsonEncode(snapshot.toJson()));
  }

  static Future<String?> _loadRaw() async {
    // load uses the user-scoped key prepared in _syncUserScope
    final db = LocalDb.instance;
    final cached = await db.getString(_storageKey);
    if (cached != null && cached.isNotEmpty) return cached;
    if (kIsWeb) return cached;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_storageKey);
    if (legacy != null && legacy.isNotEmpty) {
      await db.setString(_storageKey, legacy);
      return legacy;
    }
    return cached;
  }

  static DateTime _weekStart(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final daysFromMonday = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: daysFromMonday));
  }

  static String _weekKeyFor(DateTime date) {
    return _formatDateKey(_weekStart(date));
  }

  static String _formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
