import 'package:flutter/material.dart';

import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

enum StudentTopDestination {
  home,
  learning,
  courses,
  bookbag,
  social,
  marketplace,
  more,
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
          label: '홈',
          route: '/student/dashboard',
        ),
        (
          destination: StudentTopDestination.courses,
          label: '코스',
          route: '/courses',
        ),
        (
          destination: StudentTopDestination.bookbag,
          label: '자료실',
          route: '/marketplace',
        ),
        (destination: StudentTopDestination.more, label: '더보기', route: ''),
      ];
  return destinations
      .map((item) {
        final itemActive = switch (item.destination) {
          StudentTopDestination.home =>
            active == StudentTopDestination.home ||
                active == StudentTopDestination.learning,
          StudentTopDestination.bookbag =>
            active == StudentTopDestination.bookbag ||
                active == StudentTopDestination.marketplace,
          StudentTopDestination.more =>
            active == StudentTopDestination.more ||
                active == StudentTopDestination.social,
          _ => item.destination == active,
        };
        return Ios26NavItem(
          label: item.label,
          active: itemActive,
          onTap: itemActive
              ? null
              : item.destination == StudentTopDestination.more
              ? () => toggleAppDrawer(context)
              : () => Navigator.of(context).pushNamed(item.route),
        );
      })
      .toList(growable: false);
}
