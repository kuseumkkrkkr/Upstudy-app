import 'dart:async';

import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';

enum _AcademyDetailTab {
  info('학원 정보'),
  attendance('출석 기록'),
  timetable('학생 시간표'),
  submissions('제출 기록'),
  report('학습 보고서'),
  snapshot('학습 스냅샷'),
  groups('학원 그룹');

  const _AcademyDetailTab(this.label);
  final String label;
}

class StudentAcademyDetailsDialog extends StatefulWidget {
  const StudentAcademyDetailsDialog({
    super.key,
    required this.academyId,
    required this.academyName,
    required this.subtitle,
    required this.teacher,
    required this.fallbackSchedule,
    required this.preview,
  });

  final String academyId;
  final String academyName;
  final String subtitle;
  final String teacher;
  final List<Map<String, dynamic>> fallbackSchedule;
  final bool preview;

  @override
  State<StudentAcademyDetailsDialog> createState() =>
      _StudentAcademyDetailsDialogState();
}

class _StudentAcademyDetailsDialogState
    extends State<StudentAcademyDetailsDialog> {
  _AcademyDetailTab _tab = _AcademyDetailTab.info;
  bool _loading = false;
  String? _error;
  List<AcademyGroup> _groups = const [];
  List<AttendanceLog> _attendance = const [];
  List<GroupSubmission> _submissions = const [];
  List<TimetablePlan> _plans = const [];
  List<StudentOverviewSnapshot> _snapshots = const [];
  SubmissionReport? _report;

  /// 필요한 변수는 미리보기 여부와 학원 ID다.
  /// 작동 원리는 캡처 입력은 즉시 표시하고 실제 화면은 모달을 연 시점에만 관련 GET을 병렬 실행한다.
  @override
  void initState() {
    super.initState();
    if (!widget.preview) unawaited(_load());
  }

  /// 필요한 변수는 현재 사용자·학원 ID와 학원 상세 API다.
  /// 작동 원리는 그룹·출석·제출·스냅샷을 한 번에 조회한 뒤 첫 그룹 시간표와 첫 제출 보고서만 후속 조회한다.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ApiClient.instance.getMyProfile();
      final responses = await Future.wait<dynamic>([
        ApiClient.instance.listAcademyGroups(academyId: widget.academyId),
        ApiClient.instance.listAttendance(userId: profile.userId),
        ApiClient.instance.listSubmissions(userId: profile.userId),
        ApiClient.instance.listSnapshots(
          userId: profile.userId,
          academyId: widget.academyId,
          limit: 20,
        ),
      ]);
      final groups =
          (responses[0] as ApiResponse<List<AcademyGroup>>).data ?? const [];
      final attendance =
          (responses[1] as ApiResponse<List<AttendanceLog>>).data ?? const [];
      final submissions =
          (responses[2] as ApiResponse<List<GroupSubmission>>).data ?? const [];
      final snapshots =
          (responses[3] as ApiResponse<List<StudentOverviewSnapshot>>).data ??
          const [];
      final details = await Future.wait<dynamic>([
        if (groups.isNotEmpty)
          ApiClient.instance.listTimetablePlans(groups.first.groupId),
        if (submissions.isNotEmpty)
          ApiClient.instance.getSubmissionReport(
            submissions.first.submissionId,
          ),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _attendance = attendance;
        _submissions = submissions;
        _snapshots = snapshots;
        for (final detail in details) {
          if (detail is ApiResponse<List<TimetablePlan>>) {
            _plans = detail.data ?? const [];
          } else if (detail is ApiResponse<SubmissionReport>) {
            _report = detail.data;
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '학원 상세 정보를 불러오지 못했습니다.';
      });
    }
  }

  /// 필요한 변수는 선택 탭과 로딩된 학원 데이터다.
  /// 작동 원리는 HTML의 전면 모달처럼 제목·탭·상태 목록을 한 개 스크롤 안에서 교체한다.
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACADEMY',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.7,
                            color: Colors.black54,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          '학원 정보',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '소속 학원과 출석·시간표·제출·보고서를 확인합니다.',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tab in _AcademyDetailTab.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(tab.label),
                          selected: _tab == tab,
                          onSelected: (_) => setState(() => _tab = tab),
                          selectedColor: const Color(0xFF202022),
                          labelStyle: TextStyle(
                            color: _tab == tab ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 로딩·오류·미리보기 상태다.
  /// 작동 원리는 네트워크 상태를 먼저 처리하고 선택 탭의 실제 또는 안전한 예시 데이터를 표시한다.
  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton(onPressed: _load, child: const Text('다시 불러오기')),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: switch (_tab) {
        _AcademyDetailTab.info => _infoRows(),
        _AcademyDetailTab.attendance => _attendanceRows(),
        _AcademyDetailTab.timetable => _timetableRows(),
        _AcademyDetailTab.submissions => _submissionRows(),
        _AcademyDetailTab.report => _reportRows(),
        _AcademyDetailTab.snapshot => _snapshotRows(),
        _AcademyDetailTab.groups => _groupRows(),
      },
    );
  }

  /// 필요한 변수는 학원명·반·담당 교사다.
  /// 작동 원리는 세 핵심 소속 정보를 강조 행으로 표시한다.
  List<Widget> _infoRows() => [
    _AcademyDetailHero(name: widget.academyName),
    _DetailRow(title: '소속 반', detail: widget.subtitle, meta: '활성'),
    _DetailRow(title: '담당 교사', detail: widget.teacher, meta: '연결됨'),
  ];

  /// 필요한 변수는 최근 출석 로그다.
  /// 작동 원리는 최신 기록부터 최대 12개를 표시하고 미리보기에서는 시안 상태를 제공한다.
  List<Widget> _attendanceRows() {
    if (_attendance.isEmpty) {
      return const [
        _DetailRow(title: '오늘 출석', detail: '18:54 입실이 기록되었습니다.', meta: '출석'),
        _DetailRow(title: '최근 30일', detail: '출석 11 · 지각 1 · 결석 0', meta: '92%'),
      ];
    }
    return _attendance
        .take(12)
        .map((log) {
          return _DetailRow(
            title: log.date,
            detail: log.note ?? '학원 출석 기록',
            meta: log.status,
          );
        })
        .toList(growable: false);
  }

  /// 필요한 변수는 시간표 계획 또는 현재 코스 일정이다.
  /// 작동 원리는 서버 계획을 우선하고 없으면 학생 화면에서 이미 받은 일정만 재사용한다.
  List<Widget> _timetableRows() {
    if (_plans.isNotEmpty) {
      return _plans
          .map((plan) {
            return _DetailRow(
              title: '시간표 ${plan.version}',
              detail: plan.planJson,
              meta: plan.applied ? '적용됨' : '대기',
            );
          })
          .toList(growable: false);
    }
    if (widget.fallbackSchedule.isNotEmpty) {
      return widget.fallbackSchedule
          .map((item) {
            return _DetailRow(
              title: item['title']?.toString() ?? '함수 심화',
              detail: item['detail']?.toString() ?? '학원 수업 계획',
              meta: item['time']?.toString() ?? '목 19:30',
            );
          })
          .toList(growable: false);
    }
    return const [
      _DetailRow(title: '함수 심화', detail: '중2 심화반 정규 수업', meta: '목 19:30'),
    ];
  }

  /// 필요한 변수는 학생 제출 기록이다.
  /// 작동 원리는 최신 제출을 상태·시각과 함께 최대 12개 표시한다.
  List<Widget> _submissionRows() {
    if (_submissions.isEmpty) {
      return const [
        _DetailRow(
          title: '일차함수 12문제',
          detail: '4 / 12 진행 · 오늘 마감',
          meta: '진행 중',
        ),
        _DetailRow(title: '그래프 형성평가', detail: '어제 제출', meta: '채점 완료'),
      ];
    }
    return _submissions
        .take(12)
        .map((item) {
          return _DetailRow(
            title: item.assignmentId,
            detail: item.submittedAt?.toLocal().toString() ?? '제출 시각 없음',
            meta: item.status,
          );
        })
        .toList(growable: false);
  }

  /// 필요한 변수는 첫 제출 보고서다.
  /// 작동 원리는 정답률·학습 시간·약점·교사 피드백을 시안 카드로 분리한다.
  List<Widget> _reportRows() {
    final report = _report;
    if (report == null) {
      return const [
        _DetailRow(title: '최근 정답률', detail: '일차함수 형성평가', meta: '82%'),
        _DetailRow(
          title: '교사 피드백',
          detail: '기울기 부호와 변화량 순서를 다시 확인하세요.',
          meta: '확인',
        ),
      ];
    }
    return [
      _DetailRow(
        title: '최근 정답률',
        detail: '풀이 시간 ${report.timeSpentSeconds ?? 0}초',
        meta: '${((report.correctRate ?? 0) * 100).round()}%',
      ),
      _DetailRow(
        title: '약점 개념',
        detail: (report.weakTags ?? const ['분석 중']).join(' · '),
        meta: 'TAG',
      ),
      _DetailRow(
        title: '교사 피드백',
        detail: report.feedback ?? '등록된 피드백이 없습니다.',
        meta: '확인',
      ),
    ];
  }

  /// 필요한 변수는 최근 학습 스냅샷이다.
  /// 작동 원리는 점수·출석률·생성 시각을 최신순 카드로 표시한다.
  List<Widget> _snapshotRows() {
    if (_snapshots.isEmpty) {
      return const [
        _DetailRow(
          title: '최근 학습 상태',
          detail: '함수 단원 진행 42% · OVR 18.6',
          meta: '오늘',
        ),
      ];
    }
    return _snapshots
        .take(12)
        .map((item) {
          return _DetailRow(
            title: '학습 점수 ${item.overallScore?.toStringAsFixed(1) ?? '-'}',
            detail: '출석률 ${item.attendanceRate?.toStringAsFixed(1) ?? '-'}%',
            meta: item.createdAt?.toLocal().toString().split(' ').first ?? '최근',
          );
        })
        .toList(growable: false);
  }

  /// 필요한 변수는 소속 학원 그룹 목록이다.
  /// 작동 원리는 그룹명·학년/과목·정원을 한 행에 표시한다.
  List<Widget> _groupRows() {
    if (_groups.isEmpty) {
      return const [
        _DetailRow(title: '중2 심화반', detail: '중학교 2학년 · 수학', meta: '12 / 20'),
      ];
    }
    return _groups
        .map((group) {
          return _DetailRow(
            title: group.name,
            detail: '${group.grade ?? '학년 공통'} · ${group.subject ?? '수학'}',
            meta: '정원 ${group.maxMembers}',
          );
        })
        .toList(growable: false);
  }
}

class _AcademyDetailHero extends StatelessWidget {
  const _AcademyDetailHero({required this.name});
  final String name;

  /// 필요한 변수는 학원명이다.
  /// 작동 원리는 HTML 학원 카드의 검은 A 마크와 소속명을 모달 첫 카드에 재사용한다.
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F7),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF202022),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Text(
            'A',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.title,
    required this.detail,
    required this.meta,
  });
  final String title;
  final String detail;
  final String meta;

  /// 필요한 변수는 제목·설명·상태다.
  /// 작동 원리는 학원 상세 데이터를 테두리 없는 고밀도 목록 행으로 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE1E1E4)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          meta,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
