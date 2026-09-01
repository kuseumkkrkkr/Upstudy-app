import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:s11/app/student_feature_flags.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

/// Canary-only student services demo. The fixture never sends an inquiry to a
/// provider and stores only the selected demo state in this process.
enum StudentServiceKind { academy, tutor }

class StudentServiceProvider {
  const StudentServiceProvider({
    required this.id,
    required this.name,
    required this.area,
    required this.focus,
    required this.distance,
    required this.detail,
    required this.priceOrCapacity,
    required this.slots,
    required this.x,
    required this.y,
  });

  final String id;
  final String name;
  final String area;
  final String focus;
  final String distance;
  final String detail;
  final String priceOrCapacity;
  final List<String> slots;
  final double x;
  final double y;
}

final class StudentServicesDemoStore {
  StudentServicesDemoStore._();

  static final StudentServicesDemoStore instance = StudentServicesDemoStore._();

  final List<DemoServiceRequest> requests = <DemoServiceRequest>[];

  void add(DemoServiceRequest request) {
    requests.insert(0, request);
  }
}

class DemoServiceRequest {
  DemoServiceRequest({
    required this.kind,
    required this.provider,
    required this.grade,
    required this.subject,
    required this.slot,
  });

  final StudentServiceKind kind;
  final StudentServiceProvider provider;
  final String grade;
  final String subject;
  final String slot;
  bool cancelled = false;
}

const _academies = <StudentServiceProvider>[
  StudentServiceProvider(
    id: 'mapo',
    name: 'AIFlow 마포 학습관',
    area: '망원동 · 도보 8분',
    focus: '중등 수학 · 고등 수학',
    distance: '620m',
    detail: '진단 결과에 맞춰 개념 학습과 서술형 첨삭을 한 흐름으로 운영합니다.',
    priceOrCapacity: '중2 내신 집중반 2자리',
    slots: ['8월 27일(수) 18:30', '8월 28일(목) 17:00', '8월 30일(토) 11:00'],
    x: 38,
    y: 47,
  ),
  StudentServiceProvider(
    id: 'gongdeok',
    name: 'AIFlow 공덕 수학관',
    area: '공덕동 · 버스 12분',
    focus: '고등 수학 · 수능',
    distance: '1.8km',
    detail: '학교별 시험 범위와 학생 풀이 기록을 연결해 매주 학습 계획을 조정합니다.',
    priceOrCapacity: '고2 내신 대비반 1자리',
    slots: ['8월 27일(수) 19:30', '8월 29일(금) 18:00', '8월 31일(일) 14:00'],
    x: 68,
    y: 34,
  ),
  StudentServiceProvider(
    id: 'yeonnam',
    name: 'AIFlow 연남 센터',
    area: '연남동 · 지하철 15분',
    focus: '중등 수학 · 자기주도',
    distance: '2.4km',
    detail: '소수 정원으로 공부 습관과 오답 복습 주기를 함께 관리합니다.',
    priceOrCapacity: '중3 고등 준비반 3자리',
    slots: ['8월 28일(목) 16:30', '8월 30일(토) 13:00'],
    x: 55,
    y: 70,
  ),
];

const _tutors = <StudentServiceProvider>[
  StudentServiceProvider(
    id: 'seojin',
    name: '박서진 선생님',
    area: '마포·서대문 방문',
    focus: '중등 수학 · 내신',
    distance: '1.1km',
    detail: '학교 기출과 학생 오답을 함께 보며 풀이를 말로 설명하는 연습을 진행합니다.',
    priceOrCapacity: '회당 45,000원 · 수학교육과 · 지도 4년',
    slots: ['8월 26일(화) 19:00', '8월 28일(목) 19:00', '8월 30일(토) 10:00'],
    x: 34,
    y: 42,
  ),
  StudentServiceProvider(
    id: 'minjun',
    name: '김민준 선생님',
    area: '마포 온라인·방문',
    focus: '고등 수학 · 미적분',
    distance: '1.7km',
    detail: '개념을 짧게 확인한 뒤 시간 제한 문제로 시험 대응 속도를 높입니다.',
    priceOrCapacity: '회당 60,000원 · 수학과 · 지도 6년',
    slots: ['8월 25일(월) 20:00', '8월 27일(수) 20:00'],
    x: 67,
    y: 32,
  ),
  StudentServiceProvider(
    id: 'hayoon',
    name: '이하윤 선생님',
    area: '마포·은평 방문',
    focus: '중등 수학 · 기초',
    distance: '2.3km',
    detail: '학습량보다 매주 혼자 풀 수 있는 문제 수를 늘리는 데 집중합니다.',
    priceOrCapacity: '회당 40,000원 · 초중등 전문 · 지도 5년',
    slots: ['8월 29일(금) 18:30', '8월 30일(토) 14:00'],
    x: 60,
    y: 72,
  ),
];

class StudentServicesDemoPage extends StatefulWidget {
  const StudentServicesDemoPage({
    super.key,
    this.kind = StudentServiceKind.academy,
  });

  final StudentServiceKind kind;

  @override
  State<StudentServicesDemoPage> createState() =>
      _StudentServicesDemoPageState();
}

class _StudentServicesDemoPageState extends State<StudentServicesDemoPage> {
  bool _mapView = true;
  String _query = '';
  String _filter = '전체';
  String? _selectedId;

  List<StudentServiceProvider> get _items =>
      widget.kind == StudentServiceKind.academy ? _academies : _tutors;

  @override
  void initState() {
    super.initState();
    _selectedId = _items.first.id;
  }

  List<StudentServiceProvider> get _filtered {
    final query = _query.trim().toLowerCase();
    return _items.where((item) {
      final matchesQuery =
          query.isEmpty ||
          '${item.name} ${item.area} ${item.focus}'.toLowerCase().contains(
            query,
          );
      final matchesFilter = switch (_filter) {
        '중등' => item.focus.contains('중등'),
        '고등' => item.focus.contains('고등'),
        '2km 이내' =>
          item.distance == '620m' ||
              item.distance == '1.1km' ||
              item.distance == '1.7km' ||
              item.distance == '1.8km',
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  StudentServiceProvider get _selected => _items.firstWhere(
    (item) => item.id == _selectedId,
    orElse: () => _items.first,
  );

  void _openProfile(StudentServiceProvider item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StudentServiceProfilePage(kind: widget.kind, provider: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noun = widget.kind == StudentServiceKind.academy ? '학원' : '선생님';
    final items = _filtered;
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      appBar: AppBar(
        title: Text('$noun 찾기'),
        backgroundColor: Colors.white,
        foregroundColor: StudentDensityTokens.ink,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '샘플 문의 내역',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const StudentServiceRequestsPage(),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      bottomNavigationBar: const MobileStudentBottomAppBar(),
      body: StudentDensityPage(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DemoNotice(),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: '지역·$noun 검색',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(
                    color: StudentDensityTokens.lineStrong,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(
                    color: StudentDensityTokens.lineStrong,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ViewToggle(
                    label: '지도',
                    active: _mapView,
                    onTap: () => setState(() => _mapView = true),
                  ),
                ),
                Expanded(
                  child: _ViewToggle(
                    label: '목록',
                    active: !_mapView,
                    onTap: () => setState(() => _mapView = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['전체', '중등', '고등', '2km 이내'].map((filter) {
                  final active = _filter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: active,
                      onSelected: (_) => setState(() => _filter = filter),
                      selectedColor: StudentDensityTokens.ink,
                      labelStyle: TextStyle(
                        color: active ? Colors.white : StudentDensityTokens.ink,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (_mapView)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _OsmDemoMap(
                        items: items,
                        selectedId: _selectedId,
                        onSelect: (id) => setState(() => _selectedId = id),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProviderCard(
                      item: _selected,
                      kind: widget.kind,
                      onTap: () => _openProfile(_selected),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('조건에 맞는 결과가 없어요.'))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) => _ProviderCard(
                          item: items[index],
                          kind: widget.kind,
                          onTap: () => _openProfile(items[index]),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class StudentServiceProfilePage extends StatelessWidget {
  const StudentServiceProfilePage({
    super.key,
    required this.kind,
    required this.provider,
  });

  final StudentServiceKind kind;
  final StudentServiceProvider provider;

  @override
  Widget build(BuildContext context) {
    final academy = kind == StudentServiceKind.academy;
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      appBar: AppBar(
        title: Text(academy ? '학원 소개' : '선생님 소개'),
        backgroundColor: Colors.white,
        foregroundColor: StudentDensityTokens.ink,
        elevation: 0,
      ),
      bottomNavigationBar: const MobileStudentBottomAppBar(),
      body: StudentDensityPage(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        child: ListView(
          children: [
            const _DemoNotice(),
            const SizedBox(height: 12),
            StudentDensitySurface(
              radius: 0,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    academy ? 'AIFlow 인증 샘플' : '본인·학력 확인 샘플',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    provider.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${provider.area} · ${provider.focus}',
                    style: const TextStyle(color: StudentDensityTokens.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            StudentDensitySurface(
              radius: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '소개',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(provider.detail, style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 18),
                  Text(
                    academy ? '현재 과정' : '가능 시간',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.priceOrCapacity,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  ...provider.slots.map(
                    (slot) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(slot),
                      trailing: const Icon(Icons.arrow_forward, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: _OsmDemoMap(
                items: [provider],
                selectedId: provider.id,
                onSelect: (_) {},
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: StudentDensityTokens.ink,
                minimumSize: const Size.fromHeight(52),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _InquirySheet(kind: kind, provider: provider),
              ),
              child: Text(academy ? '상담 신청' : '수업 문의'),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentServiceRequestsPage extends StatefulWidget {
  const StudentServiceRequestsPage({super.key});

  @override
  State<StudentServiceRequestsPage> createState() =>
      _StudentServiceRequestsPageState();
}

class _StudentServiceRequestsPageState
    extends State<StudentServiceRequestsPage> {
  @override
  Widget build(BuildContext context) {
    final requests = StudentServicesDemoStore.instance.requests;
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      appBar: AppBar(
        title: const Text('샘플 문의 내역'),
        backgroundColor: Colors.white,
        foregroundColor: StudentDensityTokens.ink,
        elevation: 0,
      ),
      bottomNavigationBar: const MobileStudentBottomAppBar(),
      body: StudentDensityPage(
        padding: const EdgeInsets.all(14),
        child: requests.isEmpty
            ? const Center(child: Text('아직 샘플 문의가 없어요.'))
            : ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final request = requests[index];
                  return StudentDensitySurface(
                    radius: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.cancelled ? '취소됨' : '샘플 접수됨',
                          style: TextStyle(
                            color: request.cancelled
                                ? StudentDensityTokens.muted
                                : StudentDensityTokens.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          request.provider.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${request.grade} · ${request.subject} · ${request.slot}',
                        ),
                        if (!request.cancelled)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => request.cancelled = true),
                              child: const Text('신청 취소'),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class SchoolExamPrepPage extends StatefulWidget {
  const SchoolExamPrepPage({super.key});

  @override
  State<SchoolExamPrepPage> createState() => _SchoolExamPrepPageState();
}

class _SchoolExamPrepPageState extends State<SchoolExamPrepPage> {
  List<String> _tasks = const <String>[];
  List<bool> _completed = const <bool>[];
  String? _school;
  String? _exam;
  String? _examId;
  DateTime? _date;
  int _version = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {
      final payload = await ApiClient.instance.fetchActiveSchoolExamPlan();
      final plan = payload['plan'];
      final rawTasks = payload['tasks'];
      if (!mounted) return;
      setState(() {
        if (plan is Map) {
          _school = plan['school']?.toString();
          _exam = plan['exam_name']?.toString();
          _examId = plan['exam_id']?.toString();
          _date = DateTime.tryParse(plan['exam_date']?.toString() ?? '');
          _version = int.tryParse(plan['version']?.toString() ?? '') ?? 0;
        }
        final parsed = rawTasks is List
            ? rawTasks.whereType<Map>().toList(growable: false)
            : const <Map>[];
        _tasks = parsed.map((task) => task['title'].toString()).toList();
        _completed = parsed
            .map((task) => task['completed'] == true)
            .toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _dday {
    final date = _date;
    if (date == null) return 0;
    final value = date.difference(DateTime.now()).inDays;
    return value < 0 ? 0 : value;
  }

  Future<void> _editSettings() async {
    final school = TextEditingController(text: _school ?? '');
    var selectedExam = _exam ?? '2학기 중간고사';
    var selectedDate = _date ?? DateTime.now().add(const Duration(days: 14));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '시험 설정',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: school,
              decoration: const InputDecoration(
                labelText: '학교',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedExam,
              decoration: const InputDecoration(
                labelText: '시험',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '2학기 중간고사', child: Text('2학기 중간고사')),
                DropdownMenuItem(value: '2학기 기말고사', child: Text('2학기 기말고사')),
              ],
              onChanged: (value) => selectedExam = value ?? selectedExam,
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('시험일'),
              subtitle: Text(
                '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: sheetContext,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  initialDate: selectedDate,
                );
                if (picked != null) selectedDate = picked;
              },
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                final nextSchool = school.text.trim();
                if (nextSchool.isEmpty) return;
                try {
                  final saved = await ApiClient.instance.saveActiveSchoolExamPlan(
                    school: nextSchool,
                    examName: selectedExam,
                    examDate:
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    examId: _examId,
                    version: _version,
                  );
                  if (!mounted) return;
                  setState(() {
                    _school = saved['school']?.toString() ?? nextSchool;
                    _exam = saved['exam_name']?.toString() ?? selectedExam;
                    _date = selectedDate;
                    _version =
                        int.tryParse(saved['version']?.toString() ?? '') ??
                        _version + 1;
                  });
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                } catch (_) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text('시험 설정을 저장하지 못했어요.')),
                    );
                  }
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    school.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      appBar: AppBar(
        title: const Text('내신 대비'),
        backgroundColor: Colors.white,
        foregroundColor: StudentDensityTokens.ink,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _editSettings,
            tooltip: '시험 설정',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: const MobileStudentBottomAppBar(),
      body: StudentDensityPage(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        child: ListView(
          children: [
            const _DemoNotice(),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              StudentDensitySurface(
                radius: 0,
                color: StudentDensityTokens.ink,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_school ?? '학교 미설정'} · ${_exam ?? '수학 시험 미연결'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '시험일까지 필요한 것만',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '수학 시험 범위와 남은 할 일을 확인하세요.',
                            style: TextStyle(color: Color(0xB3FFFFFF)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'D-$_dday',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '수학',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              StudentDensitySurface(
                radius: 0,
                child: _tasks.isEmpty
                    ? const Text('연결된 수학 시험의 범위와 할 일이 없어요. 시험을 먼저 연결해 주세요.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '연결된 시험 범위',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value:
                                _completed.where((done) => done).length /
                                _completed.length,
                            color: StudentDensityTokens.ink,
                            backgroundColor: StudentDensityTokens.surfaceMuted,
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(
                            _tasks.length,
                            (index) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _completed[index],
                              onChanged: (value) => setState(
                                () => _completed[index] = value ?? false,
                              ),
                              title: Text(_tasks[index]),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Text('문제 시작 · 연결된 시험 없음'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InquirySheet extends StatefulWidget {
  const _InquirySheet({required this.kind, required this.provider});

  final StudentServiceKind kind;
  final StudentServiceProvider provider;

  @override
  State<_InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends State<_InquirySheet> {
  String? _grade;
  String? _subject;
  String? _slot;
  bool _consent = false;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.kind == StudentServiceKind.academy ? '상담 신청' : '수업 문의';
    if (_submitted) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '샘플 신청이 접수됐어요.',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text('실제 사업자에게 전송되지 않습니다.'),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        ),
      );
    }
    final valid =
        _grade != null && _subject != null && _slot != null && _consent;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.provider.name,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _grade,
              decoration: const InputDecoration(
                labelText: '학년',
                border: OutlineInputBorder(),
              ),
              items: ['중1', '중2', '중3', '고1', '고2', '고3']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _grade = value),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _subject,
              decoration: const InputDecoration(
                labelText: '주로 도움받을 과목',
                border: OutlineInputBorder(),
              ),
              items: ['수학 내신', '수학 선행', '수능 수학']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _subject = value),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _slot,
              decoration: InputDecoration(
                labelText:
                    '가능한 첫 ${widget.kind == StudentServiceKind.academy ? '상담' : '수업'} 시간',
                border: const OutlineInputBorder(),
              ),
              items: widget.provider.slots
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _slot = value),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: (value) => setState(() => _consent = value ?? false),
              title: const Text('샘플 접수 상태 저장에 동의합니다.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            FilledButton(
              onPressed: valid
                  ? () {
                      StudentServicesDemoStore.instance.add(
                        DemoServiceRequest(
                          kind: widget.kind,
                          provider: widget.provider,
                          grade: _grade!,
                          subject: _subject!,
                          slot: _slot!,
                        ),
                      );
                      setState(() => _submitted = true);
                    }
                  : null,
              child: Text('$label 보내기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OsmDemoMap extends StatelessWidget {
  const _OsmDemoMap({
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final List<StudentServiceProvider> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(37.553, 126.914),
          initialZoom: 13,
          maxZoom: 16,
          minZoom: 11,
        ),
        children: [
          TileLayer(
            urlTemplate: const String.fromEnvironment(
              'OSM_TILE_URL',
              defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            userAgentPackageName: 'com.aiflow.s11',
          ),
          MarkerLayer(
            markers: [
              for (final item in items)
                Marker(
                  point: LatLng(
                    37.553 + (50 - item.y) * .003,
                    126.914 + (item.x - 50) * .004,
                  ),
                  width: item.id == selectedId ? 42 : 34,
                  height: item.id == selectedId ? 42 : 34,
                  child: GestureDetector(
                    onTap: () => onSelect(item.id),
                    child: CircleAvatar(
                      backgroundColor: item.id == selectedId
                          ? StudentDensityTokens.ink
                          : Colors.white,
                      child: Text(
                        '${items.indexOf(item) + 1}',
                        style: TextStyle(
                          color: item.id == selectedId
                              ? Colors.white
                              : StudentDensityTokens.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.item,
    required this.kind,
    required this.onTap,
  });

  final StudentServiceProvider item;
  final StudentServiceKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StudentDensitySurface(
      radius: 0,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: StudentDensityTokens.ink,
            foregroundColor: Colors.white,
            child: Icon(
              kind == StudentServiceKind.academy
                  ? Icons.school_outlined
                  : Icons.person_outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.area} · ${item.distance}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: StudentDensityTokens.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                Text(item.focus),
                const SizedBox(height: 4),
                Text(
                  item.priceOrCapacity,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, size: 18),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      backgroundColor: active ? StudentDensityTokens.ink : Colors.white,
      foregroundColor: active ? Colors.white : StudentDensityTokens.ink,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      side: BorderSide(color: StudentDensityTokens.lineStrong),
    ),
    child: Text(label),
  );
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFE9E9EC),
    child: Padding(
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '샘플 데이터 · 실제 사업자나 결제사로 전송되지 않아요.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}

class StudentStoreDemoPage extends StatefulWidget {
  const StudentStoreDemoPage({super.key});

  @override
  State<StudentStoreDemoPage> createState() => _StudentStoreDemoPageState();
}

class _StudentStoreDemoPageState extends State<StudentStoreDemoPage> {
  int _points = 0;
  int _tab = 0;
  final _owned = <String>{};
  bool _loading = true;
  String? _error;

  static const _rewards = <({String id, String name, int cost})>[
    (id: 'background-01', name: '풀이 배경 01', cost: 1200),
    (id: 'timer-theme', name: '집중 타이머 테마', cost: 800),
    (id: 'profile-badge', name: '프로필 배지', cost: 2000),
    (id: 'review-ticket', name: '오답 복습권', cost: 600),
  ];

  @override
  void initState() {
    super.initState();
    if (StudentFeatureFlags.storeDemo) {
      _loadStore();
    } else {
      _loading = false;
      _error = '데모 기능이 비활성화되어 있어요.';
    }
  }

  Future<void> _loadStore() async {
    try {
      final snapshot = await ApiClient.instance.fetchDemoStudentStore();
      final items = snapshot['items'];
      if (!mounted) return;
      setState(() {
        _points = int.tryParse(snapshot['points']?.toString() ?? '') ?? 0;
        _owned
          ..clear()
          ..addAll(
            items is List
                ? items
                      .whereType<Map>()
                      .where((item) => item['owned'] == true)
                      .map((item) => item['id'].toString())
                : const <String>[],
          );
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '데모 상점을 불러오지 못했어요.';
        });
      }
    }
  }

  Future<void> _redeem(({String id, String name, int cost}) reward) async {
    if (_owned.contains(reward.id) || _loading) return;
    final key = '${reward.id}-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final result = await ApiClient.instance.redeemDemoStudentStoreItem(
        itemId: reward.id,
        idempotencyKey: key,
      );
      if (!mounted) return;
      final status = result['status']?.toString();
      if (status == 'completed' || status == 'duplicate') {
        setState(() {
          _points = int.tryParse(result['points']?.toString() ?? '') ?? _points;
          _owned.add(reward.id);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('포인트 교환에 실패했어요. 잠시 후 다시 시도해 주세요.')),
        );
      }
    }
  }

  Future<void> _showSubscription(String label) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '구독권 결제 UI 데모',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text('실제 카드 결제나 구독 entitlement는 생성되지 않습니다.'),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('데모 확인'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      appBar: AppBar(
        title: const Text('마켓플레이스'),
        backgroundColor: Colors.white,
        foregroundColor: StudentDensityTokens.ink,
        elevation: 0,
      ),
      bottomNavigationBar: const MobileStudentBottomAppBar(),
      body: StudentDensityPage(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        child: ListView(
          children: [
            const _DemoNotice(),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              StudentDensitySurface(radius: 0, child: Text(_error!))
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _ViewToggle(
                      label: '포인트 상점',
                      active: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                  ),
                  Expanded(
                    child: _ViewToggle(
                      label: '구독권',
                      active: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_tab == 0) ...[
                StudentDensitySurface(
                  radius: 0,
                  color: StudentDensityTokens.ink,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '보유 포인트',
                        style: TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_points}P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '학습 활동으로 모은 데모 포인트',
                        style: TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '포인트 상품',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ..._rewards.map(
                  (reward) => StudentDensitySurface(
                    radius: 0,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            reward.id == 'background-01'
                                ? '01'
                                : reward.id == 'timer-theme'
                                ? '02'
                                : reward.id == 'profile-badge'
                                ? '03'
                                : '04',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: StudentDensityTokens.muted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reward.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${reward.cost}P',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: StudentDensityTokens.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: _owned.contains(reward.id)
                              ? null
                              : () => _redeem(reward),
                          child: Text(
                            _owned.contains(reward.id) ? '교환 완료' : '교환',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'AIFlow PASS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  '필요한 기간만 선택하세요.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                StudentDensitySurface(
                  radius: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1개월',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '월 9,900원',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text('모든 학습 자료 · AI 튜터 확대'),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () => _showSubscription('1개월 구독권'),
                        child: const Text('선택'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                StudentDensitySurface(
                  radius: 0,
                  color: StudentDensityTokens.surfaceMuted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '6개월 · 추천',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '49,000원',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text('월 8,167원 · 모든 학습 자료'),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () => _showSubscription('6개월 구독권'),
                        child: const Text('선택'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
