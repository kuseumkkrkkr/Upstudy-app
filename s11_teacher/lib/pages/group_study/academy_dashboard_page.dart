import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:s11_teacher/services/api_client.dart';
import 'package:s11_teacher/shared/theme/app_colors.dart';
import 'package:s11_teacher/shared/ui/ios26/teacher_studio_shell.dart';
import 'package:s11_teacher/widgets/teacher_app_drawer.dart';

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

/// 필요 변수: 기존 학원 대시보드 탭 컨트롤러.
/// 작동 원리: 구형 TabBar 대신 선택 탭만 검은 캡슐로 표시하고 원래 TabBarView 상태를 그대로 전환한다.
class _AcademyTabStrip extends StatelessWidget {
  const _AcademyTabStrip({required this.controller});

  final TabController controller;

  static const _labels = ['출석부', '수납/납입', '상담 이력', '학생별 요약'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => SizedBox(
        height: 54,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          scrollDirection: Axis.horizontal,
          itemCount: _labels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final selected = controller.index == index;
            return Material(
              color: selected ? Colors.black : const Color(0xFFF1F1F3),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => controller.animateTo(index),
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  child: Center(
                    child: Text(
                      _labels[index],
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
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
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE1E1E5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.black, size: 18),
                ),
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
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 필요 변수: 로딩·오류·정상 상태에서 표시할 본문과 상단 작업 목록.
  /// 작동 원리: 모든 상태를 동일한 교사용 작업공간 셸 안에 넣어 탐색 구조가 사라지지 않도록 한다.
  Widget _dashboardShell({
    required Widget child,
    List<TeacherStudioAction> actions = const [],
  }) {
    return TeacherStudioShell(
      currentRoute: '/groups',
      eyebrow: 'ACADEMY OPERATIONS',
      title: '학원 운영',
      description: '출석, 수납, 상담과 학생 현황을 탭별로 확인합니다.',
      onBack: () => Navigator.of(context).maybePop(),
      endDrawer: const TeacherAppDrawer(currentRoute: '/groups'),
      actions: actions,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: ColoredBox(color: Colors.white, child: child),
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
      return _dashboardShell(
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _dashboardShell(
        actions: [
          TeacherStudioAction(
            label: '다시 시도',
            icon: Icons.refresh_rounded,
            onTap: _loadData,
            primary: true,
          ),
        ],
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F6),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 32),
                const SizedBox(height: 14),
                const Text(
                  '데이터를 불러오지 못했습니다',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, height: 1.45),
                ),
              ],
            ),
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

    return _dashboardShell(
      actions: [
        TeacherStudioAction(
          label: '새로고침',
          icon: Icons.refresh_rounded,
          onTap: _loadData,
        ),
      ],
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                _summaryCard('총 학생 수', '$totalMembers명', Icons.people_outline),
                const SizedBox(width: 10),
                _summaryCard(
                  '오늘 출석률',
                  attendanceRate,
                  Icons.check_circle_outline,
                ),
                const SizedBox(width: 10),
                _summaryCard('이번달 수납률', paymentRate, Icons.payments_outlined),
              ],
            ),
          ),
          _AcademyTabStrip(controller: _tabController),
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
