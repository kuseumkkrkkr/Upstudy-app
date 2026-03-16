class Course {
  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.duration,
    required this.progress,
    required this.benefits,
    required this.outline,
    required this.types,
    required this.units,
    this.focusTags = const [],
    this.lessons = 0,
  });

  final String id;
  final String title;
  final String description;
  final String level;
  final String duration;
  final double progress;
  final List<String> benefits;
  final List<String> outline;
  final List<String> types;
  final List<CourseUnit> units;
  final List<String> focusTags;
  final int lessons;
}

enum CourseUnitStatus {
  locked,
  active,
  completed,
}

class CourseUnit {
  const CourseUnit({
    required this.title,
    required this.type,
    required this.detail,
    required this.status,
    this.progress,
    this.estimatedMinutes = 0,
  });

  final String title;
  final String type;
  final String detail;
  final CourseUnitStatus status;
  final double? progress;
  final int estimatedMinutes;
}

const List<Course> kSampleCourses = [
  Course(
    id: 'course-core-001',
    title: '통합 마스터리 코스',
    description:
        '복습, 문제풀이, 교재 학습, 약점 점검, 빈출 드릴을 통합한 커리큘럼입니다.',
    level: '중급',
    duration: '4주',
    progress: 0.38,
    lessons: 18,
    focusTags: ['복습', '문제풀이', '교재', '약점', '빈출'],
    benefits: [
      '주간 체크포인트로 속도를 유연하게 조절합니다.',
      '매 회차 이론과 실습을 균형 있게 구성합니다.',
      '약점 추적으로 보완 루프를 제공합니다.',
    ],
    outline: [
      '오리엔테이션 및 베이스라인 점검.',
      '개념 복습 스프린트.',
      '가이드 문제 풀이 블록.',
      '교재 심화 학습 및 주석 정리.',
      '약점 클리닉 및 타깃 드릴.',
      '빈출 패턴 훈련.',
      '모의고사 및 보완 계획.',
    ],
    types: [
      '하이브리드(복습+연습)',
      '적응형 속도 조절',
      '주간 피드백 루프',
    ],
    units: [
      CourseUnit(
        title: '베이스라인 점검',
        type: '복습',
        detail: '회상 점검 + 요약 노트.',
        status: CourseUnitStatus.completed,
        estimatedMinutes: 40,
      ),
      CourseUnit(
        title: '개념 정리',
        type: '강의',
        detail: '핵심 개념과 예시.',
        status: CourseUnitStatus.completed,
        estimatedMinutes: 55,
      ),
      CourseUnit(
        title: '가이드 문제 풀이',
        type: '문제 풀이',
        detail: '핵심 패턴과 힌트.',
        status: CourseUnitStatus.active,
        progress: 0.6,
        estimatedMinutes: 50,
      ),
      CourseUnit(
        title: '교재 심화 학습',
        type: '교재',
        detail: '풀이 예제와 노트 정리.',
        status: CourseUnitStatus.locked,
        estimatedMinutes: 45,
      ),
      CourseUnit(
        title: '약점 점검',
        type: '진단',
        detail: '취약 지점 점검 + 보완 과제.',
        status: CourseUnitStatus.locked,
        estimatedMinutes: 35,
      ),
      CourseUnit(
        title: '빈출 드릴',
        type: '연습',
        detail: '속도를 위한 반복 패턴.',
        status: CourseUnitStatus.locked,
        estimatedMinutes: 40,
      ),
      CourseUnit(
        title: '모의고사',
        type: '시험',
        detail: '시간 측정 풀이 + 해설.',
        status: CourseUnitStatus.locked,
        estimatedMinutes: 60,
      ),
    ],
  ),
];
