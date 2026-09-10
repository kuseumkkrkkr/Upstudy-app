import 'package:flutter/foundation.dart';

/// HTML 화면을 코드에서 식별하기 위한 불변 목적지 값이다.
@immutable
class StudentDestination {
  const StudentDestination(
    this.screenId, {
    this.routeName = '',
    this.requiresAuth = true,
    this.demoOnly = false,
  });

  final String screenId;
  final String routeName;
  final bool requiresAuth;
  final bool demoOnly;

  @override
  bool operator ==(Object other) =>
      other is StudentDestination &&
      other.screenId == screenId &&
      other.routeName == routeName &&
      other.requiresAuth == requiresAuth &&
      other.demoOnly == demoOnly;

  @override
  int get hashCode => Object.hash(screenId, routeName, requiresAuth, demoOnly);
}

/// 화면을 감싸는 HTML 셸의 책임을 구분한다.
enum StudentShellKind { standard, immersive, auth, reader, tools }

/// 레일·하단 탭에서 강조할 정보 구조 영역이다.
enum StudentNavSection {
  home,
  courses,
  library,
  social,
  services,
  arena,
  tools,
}

/// The reference HTML is state-oriented, while Flutter routes are feature-
/// oriented. This registry keeps the one-to-one audit identifiers stable and
/// prevents navigation/search code from inventing string destinations.
@immutable
class StudentRouteSpec {
  const StudentRouteSpec({
    required this.id,
    required this.category,
    required this.route,
    this.requiresAuth = true,
    this.demoOnly = false,
  });

  final String id;
  final String category;
  final String route;
  final bool requiresAuth;
  final bool demoOnly;

  /// The typed destination used by menus, search, and audit tooling.
  StudentDestination get destination => StudentDestination(
    id,
    routeName: route,
    requiresAuth: requiresAuth,
    demoOnly: demoOnly,
  );

  /// HTML 셸은 화면 종류에서 계산해 한 곳에서 관리한다.
  StudentShellKind get shell {
    if (category == '시작' &&
        const {
          'login',
          'signup-profile',
          'signup-account',
          'signup-complete',
        }.contains(id)) {
      return StudentShellKind.auth;
    }
    if (const {
      'student-runtime',
      'solve-workspace',
      'flow-view',
      'shared-flow',
      'solution-view',
      'solve-analysis',
      'ox-quiz',
    }.contains(id)) {
      return StudentShellKind.immersive;
    }
    if (id == 'book-reader') return StudentShellKind.reader;
    if (const {
      'tutor',
      'tools-hub',
      'learning-tools-modal',
      'notepad',
      'timer',
      'focus',
      'graph',
    }.contains(id)) {
      return StudentShellKind.tools;
    }
    return StudentShellKind.standard;
  }

  /// 카테고리를 실제 공통 내비게이션 섹션으로 변환한다.
  StudentNavSection get activeNav {
    return switch (category) {
      '홈' => StudentNavSection.home,
      '코스' || '풀이' => StudentNavSection.courses,
      '교재' || '자료실' => StudentNavSection.library,
      '소셜' => StudentNavSection.social,
      '서비스' => StudentNavSection.services,
      '대결' => StudentNavSection.arena,
      '도구' => StudentNavSection.tools,
      _ => StudentNavSection.home,
    };
  }
}

abstract final class StudentRouteRegistry {
  static const _auth = <StudentRouteSpec>[
    StudentRouteSpec(
      id: 'login',
      category: '시작',
      route: '/login',
      requiresAuth: false,
    ),
    StudentRouteSpec(
      id: 'signup-profile',
      category: '시작',
      route: '/signup',
      requiresAuth: false,
    ),
    StudentRouteSpec(
      id: 'signup-account',
      category: '시작',
      route: '/signup',
      requiresAuth: false,
    ),
    StudentRouteSpec(
      id: 'signup-complete',
      category: '시작',
      route: '/signup',
      requiresAuth: false,
    ),
    StudentRouteSpec(id: 'profile', category: '시작', route: '/profile'),
    StudentRouteSpec(id: 'settings', category: '시작', route: '/settings'),
    StudentRouteSpec(
      id: 'about',
      category: '시작',
      route: '/landing/about',
      requiresAuth: false,
    ),
  ];

  static const _home = <StudentRouteSpec>[
    StudentRouteSpec(id: 'home', category: '홈', route: '/student/dashboard'),
    StudentRouteSpec(
      id: 'today-tasks',
      category: '홈',
      route: '/student/dashboard',
    ),
    StudentRouteSpec(id: 'course-select', category: '홈', route: '/courses'),
    StudentRouteSpec(
      id: 'rating-detail',
      category: '홈',
      route: '/student/dashboard',
    ),
    StudentRouteSpec(id: 'daily-test', category: '홈', route: '/level_test'),
    StudentRouteSpec(
      id: 'study-mode',
      category: '홈',
      route: '/student/dashboard',
    ),
    StudentRouteSpec(
      id: 'activity-history',
      category: '홈',
      route: '/student/dashboard',
    ),
    StudentRouteSpec(
      id: 'achievements',
      category: '홈',
      route: '/student/dashboard',
    ),
    StudentRouteSpec(id: 'schedule', category: '홈', route: '/schedule'),
    StudentRouteSpec(
      id: 'schedule-history',
      category: '홈',
      route: '/schedule/history',
    ),
  ];

  static const _courses = <StudentRouteSpec>[
    StudentRouteSpec(id: 'courses', category: '코스', route: '/courses'),
    StudentRouteSpec(id: 'course-detail', category: '코스', route: '/courses'),
    StudentRouteSpec(id: 'course-learning', category: '코스', route: '/courses'),
    StudentRouteSpec(
      id: 'course-runtime',
      category: '코스',
      route: '/course_runtime',
    ),
    StudentRouteSpec(
      id: 'review-course',
      category: '코스',
      route: '/wrong_answers',
    ),
    StudentRouteSpec(
      id: 'course-curriculum',
      category: '코스',
      route: '/courses',
    ),
    StudentRouteSpec(id: 'course-challenge', category: '코스', route: '/courses'),
    StudentRouteSpec(id: 'course-exam', category: '코스', route: '/courses'),
    StudentRouteSpec(
      id: 'course-review',
      category: '코스',
      route: '/wrong_answers',
    ),
    StudentRouteSpec(id: 'level-home', category: '코스', route: '/level_test'),
    StudentRouteSpec(id: 'level-solve', category: '코스', route: '/level_test'),
    StudentRouteSpec(
      id: 'level-result',
      category: '코스',
      route: '/level_test/result',
    ),
    StudentRouteSpec(id: 'wrong-list', category: '코스', route: '/wrong_answers'),
    StudentRouteSpec(
      id: 'wrong-solve',
      category: '코스',
      route: '/wrong_answer_solve',
    ),
  ];

  static const _solve = <StudentRouteSpec>[
    StudentRouteSpec(
      id: 'student-runtime',
      category: '풀이',
      route: '/student/runtime',
    ),
    StudentRouteSpec(
      id: 'solve-workspace',
      category: '풀이',
      route: '/student/runtime',
    ),
    StudentRouteSpec(
      id: 'flow-view',
      category: '풀이',
      route: '/student/runtime',
    ),
    StudentRouteSpec(
      id: 'shared-flow',
      category: '풀이',
      route: '/student/runtime',
    ),
    StudentRouteSpec(
      id: 'solution-view',
      category: '풀이',
      route: '/student/runtime',
    ),
    StudentRouteSpec(
      id: 'solve-analysis',
      category: '풀이',
      route: '/student/runtime',
    ),
    StudentRouteSpec(id: 'ox-quiz', category: '풀이', route: '/student/runtime'),
    StudentRouteSpec(
      id: 'weakness-review',
      category: '풀이',
      route: '/wrong_answers',
    ),
  ];

  static const _books = <StudentRouteSpec>[
    StudentRouteSpec(id: 'bookbag', category: '교재', route: '/bookbag'),
    StudentRouteSpec(id: 'bookbag-detail', category: '교재', route: '/bookbag'),
    StudentRouteSpec(id: 'book-library', category: '교재', route: '/bookbag'),
    StudentRouteSpec(id: 'book-reader', category: '교재', route: '/bookbag'),
    StudentRouteSpec(id: 'bookmarks', category: '교재', route: '/bookbag'),
    StudentRouteSpec(id: 'textbook-create', category: '교재', route: '/bookbag'),
    StudentRouteSpec(id: 'textbook-editor', category: '교재', route: '/bookbag'),
    StudentRouteSpec(id: 'concept-tags', category: '교재', route: '/bookbag'),
    StudentRouteSpec(id: 'exam-preview', category: '교재', route: '/bookbag'),
    StudentRouteSpec(id: 'exam-paper', category: '교재', route: '/bookbag'),
    StudentRouteSpec(id: 'exam-report', category: '교재', route: '/bookbag'),
  ];

  static const _market = <StudentRouteSpec>[
    StudentRouteSpec(id: 'marketplace', category: '자료실', route: '/marketplace'),
    StudentRouteSpec(
      id: 'store',
      category: '자료실',
      route: '/store',
      demoOnly: true,
    ),
    StudentRouteSpec(
      id: 'market-filter',
      category: '자료실',
      route: '/marketplace',
    ),
    StudentRouteSpec(
      id: 'market-preview',
      category: '자료실',
      route: '/marketplace',
    ),
  ];

  static const _social = <StudentRouteSpec>[
    StudentRouteSpec(id: 'social', category: '소셜', route: '/social'),
    StudentRouteSpec(id: 'social-friends', category: '소셜', route: '/social'),
    StudentRouteSpec(id: 'friend-requests', category: '소셜', route: '/social'),
    StudentRouteSpec(id: 'friend-add', category: '소셜', route: '/social'),
    StudentRouteSpec(id: 'direct-chat', category: '소셜', route: '/social'),
    StudentRouteSpec(id: 'groups', category: '소셜', route: '/groups'),
    StudentRouteSpec(id: 'group-find', category: '소셜', route: '/groups'),
    StudentRouteSpec(id: 'group-create', category: '소셜', route: '/groups'),
    StudentRouteSpec(id: 'group-join', category: '소셜', route: '/groups/join'),
    StudentRouteSpec(
      id: 'group-detail',
      category: '소셜',
      route: '/group/detail',
    ),
    StudentRouteSpec(id: 'group-chat', category: '소셜', route: '/group/detail'),
    StudentRouteSpec(id: 'group-share', category: '소셜', route: '/group/detail'),
    StudentRouteSpec(
      id: 'student-academy',
      category: '소셜',
      route: '/academy/dashboard',
    ),
    StudentRouteSpec(
      id: 'academy-details',
      category: '소셜',
      route: '/academy/dashboard',
    ),
  ];

  static const _services = <StudentRouteSpec>[
    StudentRouteSpec(
      id: 'academy-find',
      category: '서비스',
      route: '/student-services/academy',
      demoOnly: true,
    ),
    StudentRouteSpec(
      id: 'academy-profile',
      category: '서비스',
      route: '/student-services/academy/profile',
      demoOnly: true,
    ),
    StudentRouteSpec(
      id: 'private-tutor-find',
      category: '서비스',
      route: '/student-services/tutor',
      demoOnly: true,
    ),
    StudentRouteSpec(
      id: 'private-tutor-profile',
      category: '서비스',
      route: '/student-services/tutor/profile',
      demoOnly: true,
    ),
    StudentRouteSpec(
      id: 'service-requests',
      category: '서비스',
      route: '/student-services/requests',
      demoOnly: true,
    ),
    StudentRouteSpec(
      id: 'school-exam-prep',
      category: '서비스',
      route: '/school-exam-prep',
    ),
  ];

  static const _arena = <StudentRouteSpec>[
    StudentRouteSpec(id: 'arena-home', category: '대결', route: '/arena'),
    StudentRouteSpec(id: 'arena-ready', category: '대결', route: '/arena'),
    StudentRouteSpec(id: 'arena-match', category: '대결', route: '/arena'),
    StudentRouteSpec(id: 'arena-result', category: '대결', route: '/arena'),
    StudentRouteSpec(id: 'arena-ranking', category: '대결', route: '/arena'),
  ];

  static const _tools = <StudentRouteSpec>[
    StudentRouteSpec(id: 'tutor', category: '도구', route: '/tools'),
    StudentRouteSpec(id: 'tools-hub', category: '도구', route: '/learning-tools'),
    StudentRouteSpec(
      id: 'learning-tools-modal',
      category: '도구',
      route: '/learning-tools',
    ),
    StudentRouteSpec(id: 'notepad', category: '도구', route: '/learning-tools'),
    StudentRouteSpec(id: 'timer', category: '도구', route: '/learning-tools'),
    StudentRouteSpec(id: 'focus', category: '도구', route: '/learning-tools'),
    StudentRouteSpec(id: 'graph', category: '도구', route: '/graph'),
  ];

  static const all = <StudentRouteSpec>[
    ..._auth,
    ..._home,
    ..._courses,
    ..._solve,
    ..._books,
    ..._market,
    ..._social,
    ..._services,
    ..._arena,
    ..._tools,
  ];

  /// HTML QUICK FIND에 노출하는 31개 목적지다. 상태 화면은 검색 결과에서
  /// 중복 노출하지 않고, 같은 목적지의 진입 장면은 해당 화면 내부에서 연다.
  static const _searchIds = <String>{
    'home',
    'today-tasks',
    'courses',
    'course-learning',
    'level-home',
    'wrong-list',
    'solve-workspace',
    'bookbag',
    'book-reader',
    'textbook-create',
    'exam-preview',
    'marketplace',
    'store',
    'graph',
    'notepad',
    'timer',
    'focus',
    'tutor',
    'arena-home',
    'arena-ranking',
    'rating-detail',
    'activity-history',
    'achievements',
    'social',
    'groups',
    'school-exam-prep',
    'academy-find',
    'private-tutor-find',
    'profile',
    'settings',
    'about',
  };

  static Iterable<StudentRouteSpec> get searchable =>
      all.where((spec) => _searchIds.contains(spec.id));

  static StudentRouteSpec? byId(String id) {
    for (final spec in all) {
      if (spec.id == id) return spec;
    }
    return null;
  }
}
