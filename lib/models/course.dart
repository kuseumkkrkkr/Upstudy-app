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

enum CourseUnitStatus { locked, active, completed }

class CourseUnit {
  const CourseUnit({
    required this.title,
    required this.type,
    required this.detail,
    required this.status,
    this.progress,
    this.estimatedMinutes = 0,
    this.missions = const [],
  });

  final String title;
  final String type;
  final String detail;
  final CourseUnitStatus status;
  final double? progress;
  final int estimatedMinutes;
  final List<CourseUnitMission> missions;
}

class CourseUnitMission {
  const CourseUnitMission({
    required this.title,
    required this.detail,
    this.actionLabel = 'Start',
  });

  final String title;
  final String detail;
  final String actionLabel;
}

const List<Course> kSampleCourses = [
  Course(
    id: 'course-core-001',
    title: '수학 핵심 개념 완성',
    description:
        '개념 정리부터 대표 유형 풀이까지, 기초를 탄탄히 다지는 코어 과정입니다.',
    level: '중급',
    duration: '4주',
    progress: 0.38,
    lessons: 18,
    focusTags: ['수학', '핵심개념', '유형풀이', '오답정리', '실전대비'],
    benefits: [
      '핵심 개념을 짧게 요약해 빠르게 정리합니다.',
      '개념-유형-실전 문제까지 단계별로 학습합니다.',
      '오답 패턴을 분석해 약점을 보완합니다.',
    ],
    outline: [
      '개념 훑기 및 핵심 정의',
      '대표 유형 풀이',
      '필수 공식 정리',
      '실전 난이도 문제',
      '오답 노트 작성',
      '주간 미니 테스트',
      '모의고사 1회 풀이',
    ],
    types: ['개념+유형 통합', '단원별 문제 풀이', '실전 모의 테스트'],
    units: [
      CourseUnit(
        title: '기초 개념 정리',
        type: '개념',
        detail: '핵심 정의와 기호를 빠르게 복습합니다.',
        status: CourseUnitStatus.completed,
        estimatedMinutes: 40,
        missions: [
          CourseUnitMission(
            title: '핵심 용어',
            detail: '필수 용어를 카드로 정리해 확인합니다.',
          ),
          CourseUnitMission(title: '개념 요약', detail: '핵심 개념 5줄 요약 작성.'),
          CourseUnitMission(title: '간단 문제', detail: '기본 문제 5문항 풀이.'),
        ],
      ),
      CourseUnit(
        title: '대표 유형 익히기',
        type: '유형',
        detail: '출제 빈도가 높은 유형을 정리합니다.',
        status: CourseUnitStatus.completed,
        estimatedMinutes: 55,
        missions: [
          CourseUnitMission(
            title: '유형 분석',
            detail: '대표 유형 3가지를 분류해 봅니다.',
          ),
          CourseUnitMission(title: '유형 문제', detail: '각 유형별 문제 1세트 풀이.'),
          CourseUnitMission(title: '3분 풀이', detail: '3분 안에 문제 풀이 연습.'),
        ],
      ),
      CourseUnit(
        title: '중요 공식 적용',
        type: '실전',
        detail: '핵심 공식을 실제 문제에 적용합니다.',
        status: CourseUnitStatus.active,
        progress: 0.6,
        estimatedMinutes: 50,
        missions: [
          CourseUnitMission(title: '공식 A', detail: '공식 A 적용 문제 10문항 풀이.'),
          CourseUnitMission(title: '공식 B', detail: '공식 B 적용 문제 6문항 풀이.'),
          CourseUnitMission(title: '응용 문제', detail: '응용 난이도 문제 풀이.'),
        ],
      ),
      CourseUnit(
        title: '오답 패턴 분석',
        type: '복습',
        detail: '틀린 문제의 원인을 점검합니다.',
        status: CourseUnitStatus.locked,
        estimatedMinutes: 45,
        missions: [
          CourseUnitMission(title: '오답 기록', detail: '틀린 문제를 오답 노트에 정리합니다.'),
          CourseUnitMission(title: '오답 복기', detail: '풀이 과정을 다시 작성합니다.'),
          CourseUnitMission(title: '오답 퀴즈', detail: '오답 문제 2세트 재풀이.'),
        ],
      ),
      CourseUnit(
        title: '속도 향상 훈련',
        type: '훈련',
        detail: '풀이 속도를 끌어올리는 연습입니다.',
        status: CourseUnitStatus.locked,
        estimatedMinutes: 35,
        missions: [
          CourseUnitMission(
            title: '시간 측정',
            detail: '문제 12문항 시간 재기.',
          ),
          CourseUnitMission(title: '풀이 전략', detail: '풀이 순서와 전략을 정리.'),
          CourseUnitMission(title: '실전 속도', detail: '실전 속도에 맞춰 재풀이.'),
        ],
      ),
      CourseUnit(
        title: '단원 미니 테스트',
        type: '테스트',
        detail: '단원별 실력을 점검합니다.',
        status: CourseUnitStatus.locked,
        estimatedMinutes: 40,
        missions: [
          CourseUnitMission(
            title: '테스트 1',
            detail: '문항 8개 미니 테스트.',
          ),
          CourseUnitMission(
            title: '테스트 2',
            detail: '문항 6개 미니 테스트.',
          ),
          CourseUnitMission(title: '결과 분석', detail: '정답/오답 비율 분석.'),
        ],
      ),
      CourseUnit(
        title: '모의고사 실전',
        type: '모의고사',
        detail: '실전 환경으로 마무리합니다.',
        status: CourseUnitStatus.locked,
        estimatedMinutes: 60,
        missions: [
          CourseUnitMission(title: '모의고사 1회', detail: '모의고사 1회분 풀이.'),
          CourseUnitMission(title: '오답 정리', detail: '모의고사 오답 정리.'),
          CourseUnitMission(title: '약점 보완', detail: '취약 단원 재학습.'),
        ],
      ),
    ],
  ),
];

