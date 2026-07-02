import 'package:flutter/material.dart';
import '../../../shared/services/api/api_client.dart';
import '../../../shared/services/api/models.dart';

class AcademyDashboardPage extends StatefulWidget {
  final String academyId;

  const AcademyDashboardPage({super.key, required this.academyId});

  @override
  State<AcademyDashboardPage> createState() => _AcademyDashboardPageState();
}

class _AcademyDashboardPageState extends State<AcademyDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Academy? _academy;
  List<AcademyGroup> _groups = [];
  List<AttendanceLog> _attendanceLogs = [];
  List<TuitionPayment> _tuitionPayments = [];
  List<ParentConsultNote> _consultNotes = [];
  List<StudentOverviewSnapshot> _snapshots = [];
  bool _loading = true;
  String? _error;

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
    try {
      setState(() { _loading = true; _error = null; });

      final academyRes = await ApiClient.instance.getAcademy(widget.academyId);
      final groupsRes = await ApiClient.instance.listAcademyGroups(academyId: widget.academyId);
      final attendanceRes = await ApiClient.instance.listAttendance();
      final tuitionRes = await ApiClient.instance.listTuitionPayments(academyId: widget.academyId);
      final consultRes = await ApiClient.instance.listConsultNotes(academyId: widget.academyId);
      final snapshotsRes = await ApiClient.instance.listSnapshots(academyId: widget.academyId, limit: 100);

      setState(() {
        _academy = academyRes.data;
        _groups = groupsRes.data ?? [];
        _attendanceLogs = attendanceRes.data ?? [];
        _tuitionPayments = tuitionRes.data ?? [];
        _consultNotes = consultRes.data ?? [];
        _snapshots = snapshotsRes.data ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Map<String, dynamic> _calculateStats() {
    final totalStudents = _groups.fold<int>(0, (sum, g) {
      // This is approximate since we don't have member counts per group in this view
      return sum + g.maxMembers;
    });

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todayAttendance = _attendanceLogs.where((log) => log.date == todayStr);
    final presentCount = todayAttendance.where((log) => log.status == 'present').length;
    final totalToday = todayAttendance.length;
    final attendanceRate = totalToday > 0 ? (presentCount / totalToday * 100) : 0.0;

    final monthLabel = '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final monthTuition = _tuitionPayments.where((t) => t.monthLabel == monthLabel).toList();
    final paidCount = monthTuition.length;
    final totalTuition = _groups.length * 10; // Approximate
    final tuitionRate = totalTuition > 0 ? (paidCount / totalTuition * 100) : 0.0;

    return {
      'totalStudents': totalStudents,
      'attendanceRate': attendanceRate,
      'tuitionRate': tuitionRate,
      'consultCount': _consultNotes.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return Scaffold(
      appBar: AppBar(
        title: Text(_academy?.name ?? '학원 대시보드'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '출석', icon: Icon(Icons.check_circle)),
            Tab(text: '수납', icon: Icon(Icons.payment)),
            Tab(text: '상담', icon: Icon(Icons.chat)),
            Tab(text: '요약', icon: Icon(Icons.summarize)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('오류: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _SummaryCards(stats: stats),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _AttendanceTab(
                            logs: _attendanceLogs,
                            groups: _groups,
                            onRefresh: _loadData,
                          ),
                          _TuitionTab(
                            payments: _tuitionPayments,
                            academyId: widget.academyId,
                            onRefresh: _loadData,
                          ),
                          _ConsultTab(
                            notes: _consultNotes,
                            academyId: widget.academyId,
                            onRefresh: _loadData,
                          ),
                          _StudentSummaryTab(
                            snapshots: _snapshots,
                            onRefresh: _loadData,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _SummaryCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: '학생 수',
              value: '${stats['totalStudents'] ?? 0}',
              icon: Icons.people,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              title: '출석률',
              value: '${(stats['attendanceRate'] ?? 0).toStringAsFixed(1)}%',
              icon: Icons.check_circle,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              title: '수납률',
              value: '${(stats['tuitionRate'] ?? 0).toStringAsFixed(1)}%',
              icon: Icons.payment,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTab extends StatefulWidget {
  final List<AttendanceLog> logs;
  final List<AcademyGroup> groups;
  final VoidCallback onRefresh;

  const _AttendanceTab({
    required this.logs,
    required this.groups,
    required this.onRefresh,
  });

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  String? _selectedGroupId;
  String? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final filteredLogs = widget.logs.where((log) {
      if (_selectedGroupId != null && log.groupId != _selectedGroupId) return false;
      if (_selectedDate != null && log.date != _selectedDate) return false;
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedGroupId,
                  decoration: const InputDecoration(
                    labelText: '그룹 필터',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체 그룹')),
                    ...widget.groups.map((g) => DropdownMenuItem(
                      value: g.groupId,
                      child: Text(g.name),
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedGroupId = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: '날짜 (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _selectedDate = v.isEmpty ? null : v),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredLogs.isEmpty
              ? const Center(child: Text('출석 기록이 없습니다'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('날짜')),
                      DataColumn(label: Text('그룹')),
                      DataColumn(label: Text('학생')),
                      DataColumn(label: Text('상태')),
                      DataColumn(label: Text('비고')),
                    ],
                    rows: filteredLogs.map((log) {
                      final group = widget.groups.firstWhere(
                        (g) => g.groupId == log.groupId,
                        orElse: () => AcademyGroup(
                          groupId: log.groupId,
                          academyId: '',
                          name: 'Unknown',
                        ),
                      );
                      return DataRow(
                        cells: [
                          DataCell(Text(log.date)),
                          DataCell(Text(group.name)),
                          DataCell(Text('User ${log.userId.substring(0, 8)}...')),
                          DataCell(_StatusChip(status: log.status)),
                          DataCell(Text(log.note ?? '-')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'present':
        color = Colors.green;
        label = '출석';
        break;
      case 'late':
        color = Colors.orange;
        label = '지각';
        break;
      case 'absent':
        color = Colors.red;
        label = '결석';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

class _TuitionTab extends StatefulWidget {
  final List<TuitionPayment> payments;
  final String academyId;
  final VoidCallback onRefresh;

  const _TuitionTab({
    required this.payments,
    required this.academyId,
    required this.onRefresh,
  });

  @override
  State<_TuitionTab> createState() => _TuitionTabState();
}

class _TuitionTabState extends State<_TuitionTab> {
  String? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final filteredPayments = _selectedMonth != null
        ? widget.payments.where((p) => p.monthLabel == _selectedMonth).toList()
        : widget.payments;

    final monthGroups = <String, List<TuitionPayment>>{};
    for (final payment in filteredPayments) {
      monthGroups.putIfAbsent(payment.monthLabel, () => []).add(payment);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedMonth,
                  decoration: const InputDecoration(
                    labelText: '월 필터',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    ...monthGroups.keys.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m),
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedMonth = v),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showAddPaymentDialog,
                icon: const Icon(Icons.add),
                label: const Text('수납 등록'),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredPayments.isEmpty
              ? const Center(child: Text('수납 기록이 없습니다'))
              : ListView.builder(
                  itemCount: filteredPayments.length,
                  itemBuilder: (context, index) {
                    final payment = filteredPayments[index];
                    return ListTile(
                      leading: const Icon(Icons.payment, color: Colors.green),
                      title: Text('User ${payment.userId.substring(0, 8)}...'),
                      subtitle: Text('${payment.monthLabel} • ${payment.method ?? '현금'}'),
                      trailing: Text(
                        '${payment.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showAddPaymentDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _AddPaymentDialog(),
    );
    if (result == null) return;

    try {
      await ApiClient.instance.createTuitionPayment(
        academyId: widget.academyId,
        userId: result['user_id']!,
        amount: int.parse(result['amount']!),
        monthLabel: result['month_label']!,
        method: result['method'],
      );
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수납이 등록되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: $e')),
        );
      }
    }
  }
}

class _AddPaymentDialog extends StatefulWidget {
  const _AddPaymentDialog();

  @override
  State<_AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<_AddPaymentDialog> {
  final _userIdCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _monthCtrl = TextEditingController();
  final _methodCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('수납 등록'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _userIdCtrl,
              decoration: const InputDecoration(labelText: '학생 ID'),
            ),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: '금액'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _monthCtrl,
              decoration: const InputDecoration(
                labelText: '월 (YYYY-MM)',
                hintText: '2026-05',
              ),
            ),
            TextField(
              controller: _methodCtrl,
              decoration: const InputDecoration(
                labelText: '결제 방법 (선택)',
                hintText: '현금, 카드, 계좌이체',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_userIdCtrl.text.isEmpty || _amountCtrl.text.isEmpty || _monthCtrl.text.isEmpty) return;
            Navigator.pop(context, {
              'user_id': _userIdCtrl.text,
              'amount': _amountCtrl.text,
              'month_label': _monthCtrl.text,
              'method': _methodCtrl.text.isEmpty ? null : _methodCtrl.text,
            });
          },
          child: const Text('등록'),
        ),
      ],
    );
  }
}

class _ConsultTab extends StatefulWidget {
  final List<ParentConsultNote> notes;
  final String academyId;
  final VoidCallback onRefresh;

  const _ConsultTab({
    required this.notes,
    required this.academyId,
    required this.onRefresh,
  });

  @override
  State<_ConsultTab> createState() => _ConsultTabState();
}

class _ConsultTabState extends State<_ConsultTab> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '상담 기록',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddConsultDialog,
                icon: const Icon(Icons.add),
                label: const Text('상담 등록'),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.notes.isEmpty
              ? const Center(child: Text('상담 기록이 없습니다'))
              : ListView.builder(
                  itemCount: widget.notes.length,
                  itemBuilder: (context, index) {
                    final note = widget.notes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.chat_bubble, color: Colors.blue),
                        title: Text(note.topic ?? '상담'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('학생: User ${note.studentUserId.substring(0, 8)}...'),
                            if (note.parentName != null)
                              Text('학부모: ${note.parentName}'),
                            if (note.content != null)
                              Text(note.content!, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showAddConsultDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _AddConsultDialog(),
    );
    if (result == null) return;

    try {
      await ApiClient.instance.createConsultNote(
        academyId: widget.academyId,
        studentUserId: result['student_user_id']!,
        parentName: result['parent_name'],
        topic: result['topic'],
        content: result['content'],
        followUpDate: result['follow_up_date'],
      );
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상담이 등록되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: $e')),
        );
      }
    }
  }
}

class _AddConsultDialog extends StatefulWidget {
  const _AddConsultDialog();

  @override
  State<_AddConsultDialog> createState() => _AddConsultDialogState();
}

class _AddConsultDialogState extends State<_AddConsultDialog> {
  final _studentIdCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _followUpCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('상담 등록'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _studentIdCtrl,
              decoration: const InputDecoration(labelText: '학생 ID'),
            ),
            TextField(
              controller: _parentNameCtrl,
              decoration: const InputDecoration(labelText: '학부모 이름 (선택)'),
            ),
            TextField(
              controller: _topicCtrl,
              decoration: const InputDecoration(labelText: '주제 (선택)'),
            ),
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(labelText: '내용'),
              maxLines: 3,
            ),
            TextField(
              controller: _followUpCtrl,
              decoration: const InputDecoration(
                labelText: '후속 날짜 (YYYY-MM-DD, 선택)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_studentIdCtrl.text.isEmpty) return;
            Navigator.pop(context, {
              'student_user_id': _studentIdCtrl.text,
              'parent_name': _parentNameCtrl.text.isEmpty ? null : _parentNameCtrl.text,
              'topic': _topicCtrl.text.isEmpty ? null : _topicCtrl.text,
              'content': _contentCtrl.text.isEmpty ? null : _contentCtrl.text,
              'follow_up_date': _followUpCtrl.text.isEmpty ? null : _followUpCtrl.text,
            });
          },
          child: const Text('등록'),
        ),
      ],
    );
  }
}

class _StudentSummaryTab extends StatelessWidget {
  final List<StudentOverviewSnapshot> snapshots;
  final VoidCallback onRefresh;

  const _StudentSummaryTab({
    required this.snapshots,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '학생 요약',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showBuildSnapshotDialog(context),
                icon: const Icon(Icons.refresh),
                label: const Text('새로 생성'),
              ),
            ],
          ),
        ),
        Expanded(
          child: snapshots.isEmpty
              ? const Center(child: Text('학생 요약 데이터가 없습니다'))
              : ListView.builder(
                  itemCount: snapshots.length,
                  itemBuilder: (context, index) {
                    final snapshot = snapshots[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ExpansionTile(
                        title: Text('User ${snapshot.userId.substring(0, 8)}...'),
                        subtitle: Row(
                          children: [
                            if (snapshot.overallScore != null)
                              _SummaryChip(
                                label: '점수: ${snapshot.overallScore!.toStringAsFixed(1)}',
                                color: Colors.blue,
                              ),
                            if (snapshot.attendanceRate != null) ...[
                              const SizedBox(width: 8),
                              _SummaryChip(
                                label: '출석: ${snapshot.attendanceRate!.toStringAsFixed(1)}%',
                                color: Colors.green,
                              ),
                            ],
                          ],
                        ),
                        children: [
                          if (snapshot.summaryJson != null)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(snapshot.summaryJson!),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showBuildSnapshotDialog(BuildContext context) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _BuildSnapshotDialog(),
    );
    if (result == null) return;

    try {
      await ApiClient.instance.buildStudentOverview(
        userId: result['user_id']!,
        academyId: result['academy_id']!,
        groupId: result['group_id'],
      );
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('학생 요약이 생성되었습니다')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('생성 실패: $e')),
        );
      }
    }
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _BuildSnapshotDialog extends StatefulWidget {
  const _BuildSnapshotDialog();

  @override
  State<_BuildSnapshotDialog> createState() => _BuildSnapshotDialogState();
}

class _BuildSnapshotDialogState extends State<_BuildSnapshotDialog> {
  final _userIdCtrl = TextEditingController();
  final _academyIdCtrl = TextEditingController();
  final _groupIdCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('학생 요약 생성'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _userIdCtrl,
              decoration: const InputDecoration(labelText: '학생 ID'),
            ),
            TextField(
              controller: _academyIdCtrl,
              decoration: const InputDecoration(labelText: '학원 ID'),
            ),
            TextField(
              controller: _groupIdCtrl,
              decoration: const InputDecoration(
                labelText: '그룹 ID (선택)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_userIdCtrl.text.isEmpty || _academyIdCtrl.text.isEmpty) return;
            Navigator.pop(context, {
              'user_id': _userIdCtrl.text,
              'academy_id': _academyIdCtrl.text,
              'group_id': _groupIdCtrl.text.isEmpty ? null : _groupIdCtrl.text,
            });
          },
          child: const Text('생성'),
        ),
      ],
    );
  }
}
