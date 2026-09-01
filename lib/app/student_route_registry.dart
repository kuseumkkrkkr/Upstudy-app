import 'package:flutter/foundation.dart';

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
    StudentRouteSpec(id: 'study-mode', category: '홈', route: '/learning-tools'),
    StudentRouteSpec(id: 'activity-history', category: '홈', route: '/schedule'),
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

  static StudentRouteSpec? byId(String id) {
    for (final spec in all) {
      if (spec.id == id) return spec;
    }
    return null;
  }
}
