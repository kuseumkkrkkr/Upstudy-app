import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:s11_teacher/services/api_client.dart';
import 'package:s11_teacher/shared/theme/app_colors.dart';

class AcademyDashboardPage extends StatefulWidget {
  const AcademyDashboardPage({
    super.key,
    required this.academyId,
    required this.groupId,
  });

  static const String routeName = '/academy/dashboard';

  final String academyId;
  final String groupId;

  @override
  State<AcademyDashboardPage> createState() => _AcademyDashboardPageState();
}

class _AcademyDashboardPageState extends State<AcademyDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isLoading = true;
  String? _error;

  List<AcademyGroupMember> _members = [];
  List<AttendanceLog> _attendanceLogs = [];
  List<TuitionPayment> _tuitionPayments = [];
  List<ParentConsultNote> _consultNotes = [];
  List<StudentOverviewSnapshot> _snapshots = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    if (widget.academyId.isEmpty || widget.groupId.isEmpty) {
      setState(() {
        _error = '학원 대시보드는 academyId와 groupId가 있어야 열 수 있습니다.';
        _isLoading = false;
      });
      return;
    }
    try {
      final client = ApiClient.instance;
      final results = await Future.wait([
        client.listAcademyGroupMembers(
          groupId: widget.groupId,
          status: 'active',
        ),
        client.listAttendanceLogs(groupId: widget.groupId),
        client.listTuitionPayments(academyId: widget.academyId),
        client.listConsultNotes(academyId: widget.academyId),
        client.listSnapshots(
          academyId: widget.academyId,
          groupId: widget.groupId,
        ),
      ]);
      setState(() {
        _members = results[0] as List<AcademyGroupMember>;
        _attendanceLogs = results[1] as List<AttendanceLog>;
        _tuitionPayments = results[2] as List<TuitionPayment>;
        _consultNotes = results[3] as List<ParentConsultNote>;
        _snapshots = results[4] as List<StudentOverviewSnapshot>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _summaryCard(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        color: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _thisMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Widget _attendanceTab() {
    if (_members.isEmpty) {
      return const Center(child: Text('학생 데이터가 없습니다.'));
    }

    final today = _today();
    final todayLogs = _attendanceLogs.where((l) => l.date == today).toList();

    // Group logs by userId for quick lookup
    final logMap = <String, AttendanceLog>{};
    for (final log in todayLogs) {
      logMap[log.userId] = log;
    }

    // Build a simple weekday list (Mon-Fri) for the current week
    final now = DateTime.now();
    final weekdayStart = now.subtract(Duration(days: now.weekday - 1));
    final weekDates = List.generate(5, (i) {
      final d = weekdayStart.add(Duration(days: i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });

    // Map all logs by (userId, date)
    final allLogMap = <String, AttendanceLog>{};
    for (final log in _attendanceLogs) {
      allLogMap['${log.userId}|${log.date}'] = log;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Card(
        color: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('학생')),
            DataColumn(label: Text('월')),
            DataColumn(label: Text('화')),
            DataColumn(label: Text('수')),
            DataColumn(label: Text('목')),
            DataColumn(label: Text('금')),
          ],
          rows: _members.map((member) {
            return DataRow(
              cells: [
                DataCell(Text(member.userId.substring(0, 6))),
                ...weekDates.map((date) {
                  final key = '${member.userId}|$date';
                  final log = allLogMap[key];
                  final isPresent =
                      log != null &&
                      (log.status == 'present' || log.status == 'late');
                  return DataCell(
                    Icon(
                      isPresent
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isPresent ? AppColors.primary : Colors.black26,
                      size: 18,
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _paymentTab() {
    final month = _thisMonth();
    final payments = _tuitionPayments
        .where((p) => p.monthLabel == month)
        .toList();

    if (payments.isEmpty) {
      return const Center(child: Text('이번 달 수납 데이터가 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final p = payments[index];
        final isPaid = p.paidAt != null;
        return Card(
          color: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(p.userId.substring(0, 6)),
            subtitle: Text(
              '수업료 ${p.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
            ),
            trailing: Chip(
              label: Text(
                isPaid ? '완료' : '미납',
                style: TextStyle(
                  fontSize: 12,
                  color: isPaid ? Colors.white : Colors.red,
                ),
              ),
              backgroundColor: isPaid
                  ? AppColors.primary
                  : Colors.red.withValues(alpha: 0.1),
              side: isPaid
                  ? BorderSide.none
                  : const BorderSide(color: Colors.red),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      },
    );
  }

  Widget _consultationTab() {
    if (_consultNotes.isEmpty) {
      return const Center(child: Text('상담 이력이 없습니다.'));
    }

    final sorted = [..._consultNotes]
      ..sort((a, b) {
        final ad = a.consultedAt;
        final bd = b.consultedAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final c = sorted[index];
        final dateStr = c.consultedAt != null
            ? '${c.consultedAt!.year}-${c.consultedAt!.month.toString().padLeft(2, '0')}-${c.consultedAt!.day.toString().padLeft(2, '0')}'
            : c.followUpDate ?? '';
        return Card(
          color: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        c.topic ?? '상담',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '상담 대상: ${c.parentName ?? c.studentUserId.substring(0, 6)}',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                if (c.content != null && c.content!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      c.content!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _studentSummaryTab() {
    if (_snapshots.isEmpty) {
      return const Center(child: Text('학생 요약 데이터가 없습니다.'));
    }

    // Sort by createdAt desc, take latest per user
    final latestByUser = <String, StudentOverviewSnapshot>{};
    for (final snap in _snapshots) {
      final existing = latestByUser[snap.userId];
      if (existing == null ||
          (snap.createdAt != null &&
              (existing.createdAt == null ||
                  snap.createdAt!.isAfter(existing.createdAt!)))) {
        latestByUser[snap.userId] = snap;
      }
    }

    final students = latestByUser.values.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final s = students[index];
        final score = s.overallScore;
        final scoreStr = score != null ? score.toStringAsFixed(1) : '-';

        // Weakness tags from snapshot_json (simple heuristic)
        final weakness = <String>[];
        if (s.snapshotJson != null && s.snapshotJson!.isNotEmpty) {
          // Try to extract weakness array from JSON string
          try {
            final decoded = jsonDecode(s.snapshotJson!) as Map<String, dynamic>;
            final w = decoded['weakness'];
            if (w is List) {
              weakness.addAll(w.map((e) => e.toString()));
            }
          } catch (_) {
            // ignore
          }
        }

        return Card(
          color: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                s.userId.substring(0, 1),
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
            title: Text(s.userId.substring(0, 6)),
            subtitle: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (weakness.isNotEmpty)
                  for (final tag in weakness)
                    Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.red.withValues(alpha: 0.08),
                      side: const BorderSide(color: Colors.red),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                else
                  const Text(
                    '약점 태그 없음',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '평균 $scoreStr점',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.tuitionStatus ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('학원 대시보드'),
          backgroundColor: AppColors.cardBg,
          foregroundColor: AppColors.primary,
          elevation: 0,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: const Border(
            bottom: BorderSide(color: AppColors.surfaceBorder),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('학원 대시보드'),
          backgroundColor: AppColors.cardBg,
          foregroundColor: AppColors.primary,
          elevation: 0,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: const Border(
            bottom: BorderSide(color: AppColors.surfaceBorder),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('오류: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }

    final today = _today();
    final todayPresent = _attendanceLogs
        .where(
          (l) =>
              l.date == today && (l.status == 'present' || l.status == 'late'),
        )
        .length;
    final totalMembers = _members.length;
    final attendanceRate = totalMembers > 0
        ? '${(todayPresent / totalMembers * 100).toStringAsFixed(0)}%'
        : '-';

    final month = _thisMonth();
    final monthPayments = _tuitionPayments
        .where((p) => p.monthLabel == month)
        .toList();
    final paidCount = monthPayments.where((p) => p.paidAt != null).length;
    final paymentRate = totalMembers > 0
        ? '${(paidCount / totalMembers * 100).toStringAsFixed(0)}%'
        : '-';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('학원 대시보드'),
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.primary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          tabs: const [
            Tab(text: '출석부'),
            Tab(text: '수납/납입'),
            Tab(text: '상담 이력'),
            Tab(text: '학생별 요약'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                _summaryCard('총 학생 수', '$totalMembers명', Icons.people),
                const SizedBox(width: 10),
                _summaryCard('오늘 출석률', attendanceRate, Icons.check_circle),
                const SizedBox(width: 10),
                _summaryCard('이번달 수납률', paymentRate, Icons.payments),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _attendanceTab(),
                _paymentTab(),
                _consultationTab(),
                _studentSummaryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
