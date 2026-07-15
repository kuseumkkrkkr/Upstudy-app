import 'package:flutter/material.dart';

import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

enum StudentTopDestination { learning, courses, bookbag, social, marketplace }

/// 필요한 변수는 현재 화면 문맥과 활성 학생 메뉴다.
/// 모든 학생 화면이 동일한 명명 라우트를 사용하도록 PC 상단 메뉴 항목과 활성 상태를 생성한다.
List<Ios26NavItem> studentTopNavItems(
  BuildContext context, {
  required StudentTopDestination active,
}) {
  const destinations =
      <({StudentTopDestination destination, String label, String route})>[
        (
          destination: StudentTopDestination.learning,
          label: '학습터',
          route: '/student/dashboard',
        ),
        (
          destination: StudentTopDestination.courses,
          label: '코스',
          route: '/courses',
        ),
        (
          destination: StudentTopDestination.bookbag,
          label: '책가방',
          route: '/bookbag',
        ),
        (
          destination: StudentTopDestination.social,
          label: '친구/소셜',
          route: '/social',
        ),
        (
          destination: StudentTopDestination.marketplace,
          label: '마켓플레이스',
          route: '/marketplace',
        ),
      ];
  return destinations
      .map(
        (item) => Ios26NavItem(
          label: item.label,
          active: item.destination == active,
          onTap: item.destination == active
              ? null
              : () => Navigator.of(context).pushNamed(item.route),
        ),
      )
      .toList(growable: false);
}
