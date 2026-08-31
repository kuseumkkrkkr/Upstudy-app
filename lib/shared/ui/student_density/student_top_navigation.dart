import 'package:flutter/material.dart';

import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

enum StudentTopDestination {
  home,
  learning,
  courses,
  bookbag,
  social,
  marketplace,
}

/// 필요한 변수는 현재 화면 문맥과 활성 학생 메뉴다.
/// 각 학습 기능의 명명 라우트를 PC 상단 메뉴 항목과 활성 상태로 생성한다.
List<Ios26NavItem> studentTopNavItems(
  BuildContext context, {
  required StudentTopDestination active,
}) {
  const destinations =
      <({StudentTopDestination destination, String label, String route})>[
        (
          destination: StudentTopDestination.home,
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
          active:
              item.destination == active ||
              (active == StudentTopDestination.learning &&
                  item.destination == StudentTopDestination.home),
          onTap:
              item.destination == active ||
                  (active == StudentTopDestination.learning &&
                      item.destination == StudentTopDestination.home)
              ? null
              : () => Navigator.of(context).pushNamed(item.route),
        ),
      )
      .toList(growable: false);
}
