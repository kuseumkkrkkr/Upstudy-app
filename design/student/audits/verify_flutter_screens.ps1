$ErrorActionPreference = 'Stop'

# 필요 변수: 25개 시안 ID, 실제 학생 Dart 파일, 화면을 증명하는 클래스·기능 표식.
# 작동 원리: 각 화면을 UTF-8로 엄격히 읽고 실제 구현 파일과 핵심 표식이 모두 존재하는지 확인한다.
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$screens = @(
  @{ Id = 'dashboard'; File = 'lib/sessions/student_dashboard/session/main_student_page.dart'; Marker = 'class MainStudentPage' },
  @{ Id = 'courses'; File = 'lib/sessions/course/ui/course_catalog_page.dart'; Marker = 'class CourseCatalogPage' },
  @{ Id = 'course-detail'; File = 'lib/sessions/course/ui/course_detail_page.dart'; Marker = 'class CourseDetailPage' },
  @{ Id = 'course-learning'; File = 'lib/sessions/course/session/course_learning_page.dart'; Marker = 'class CourseLearningPage' },
  @{ Id = 'solve'; File = 'lib/sessions/tryout_solve/session/build_page_widget.dart'; Marker = 'class BuildpageWidget' },
  @{ Id = 'exam-paper'; File = 'lib/sessions/exam_paper/session/exam_paper_page.dart'; Marker = 'class ExamPaperPage' },
  @{ Id = 'wrong-answers'; File = 'lib/features/wrong_answer/wrong_answer_list_page.dart'; Marker = 'class WrongAnswerListPage' },
  @{ Id = 'level-test'; File = 'lib/features/level_test/level_test_home_page.dart'; Marker = 'class LevelTestHomePage' },
  @{ Id = 'arena'; File = 'lib/features/arena/arena_page.dart'; Marker = 'class ArenaPage' },
  @{ Id = 'textbooks'; File = 'lib/sessions/textbook/ui/pages/docx_box.dart'; Marker = 'class BookWidget' },
  @{ Id = 'textbook-reader'; File = 'lib/sessions/course/session/teacher_course_textbook_reader_page.dart'; Marker = 'heartbeatCourseTextbookRuntime' },
  @{ Id = 'schedule'; File = 'lib/features/student_schedule/schedule_page.dart'; Marker = 'class SchedulePage' },
  @{ Id = 'groups'; File = 'lib/features/group_study/group_list_page.dart'; Marker = 'class GroupListPage' },
  @{ Id = 'group-detail'; File = 'lib/features/group_study/group_detail_page.dart'; Marker = 'class GroupDetailPage' },
  @{ Id = 'academy'; File = 'lib/features/group_study/student_academy_page.dart'; Marker = 'class StudentAcademyPage' },
  @{ Id = 'friends'; File = 'lib/sessions/friend/ui/friend_screen.dart'; Marker = 'class SoWidget' },
  @{ Id = 'chat'; File = 'lib/sessions/learning_tools/ui/pages/server_chat_page.dart'; Marker = 'class ServerChatPage' },
  @{ Id = 'marketplace'; File = 'lib/sessions/marketplace/ui/pages/marketplace_page.dart'; Marker = 'class MarketplacePage' },
  @{ Id = 'tools'; File = 'lib/sessions/learning_tools/ui/pages/notepad_page.dart'; Marker = 'class NotepadPage' },
  @{ Id = 'graph'; File = 'lib/sessions/graph_tools/session/jsx_graph_page.dart'; Marker = 'class JsxGraphPage' },
  @{ Id = 'flow'; File = 'lib/sessions/tryout_solve/ui/pages/flow_view_page.dart'; Marker = 'class FlowViewPage' },
  @{ Id = 'profile'; File = 'lib/sessions/auth/ui/pages/profile_page.dart'; Marker = 'class ProfilePage' },
  @{ Id = 'settings'; File = 'lib/sessions/settings/ui/pages/settings_page.dart'; Marker = 'class SettingsPage' },
  @{ Id = 'auth'; File = 'lib/sessions/auth/ui/pages/login_page.dart'; Marker = 'class LoginPage' },
  @{ Id = 'signup'; File = 'lib/sessions/auth/ui/pages/signup_page.dart'; Marker = 'class SignupPage' }
)

foreach ($screen in $screens) {
  $path = Join-Path $root $screen.File
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing Flutter screen file: $($screen.Id) -> $($screen.File)"
  }
  $source = $utf8.GetString([System.IO.File]::ReadAllBytes($path))
  if ($source -notmatch [regex]::Escape($screen.Marker)) {
    throw "Missing Flutter screen marker: $($screen.Id) -> $($screen.Marker)"
  }
  if ($source -match 'data-screen-contract|FEATURE_LEDGER|ENDPOINT_LEDGER') {
    throw "Development ledger leaked into Flutter screen: $($screen.Id)"
  }
}

# 필요 변수: 학생 라우터와 공용 상단 내비게이션 원문.
# 작동 원리: PC·모바일이 공유하는 다섯 목적지와 독립 챌린지 제거 상태를 정적으로 검증한다.
$router = $utf8.GetString([System.IO.File]::ReadAllBytes((Join-Path $root 'lib/app/router.dart')))
$navigation = $utf8.GetString([System.IO.File]::ReadAllBytes((Join-Path $root 'lib/shared/ui/student_density/student_top_navigation.dart')))
foreach ($route in '/study-center', '/courses', '/bookbag', '/social', '/marketplace') {
  if ($router -notmatch [regex]::Escape($route) -or $navigation -notmatch [regex]::Escape($route)) {
    throw "Missing shared student route: $route"
  }
}
if ($router -match '[''"]/challenge' -or (Test-Path (Join-Path $root 'lib/features/challenges/*.dart'))) {
  throw 'Independent challenge screen still exists.'
}

Write-Output "Verified Flutter implementation: $($screens.Count) screens / shared navigation / no ledger UI / UTF-8"
