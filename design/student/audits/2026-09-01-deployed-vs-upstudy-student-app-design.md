# AIFlow S11 배포본 ↔ Upstudy Student App Design UI/UX 일대일 감사

감사 기준일: 2026-09-01  
대상 브랜치: `hotfix`  
기준 커밋: `93595dbb55f7abe5a9d8fab33aaa99965dbb8568`  
배포 alias: [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/student/dashboard)  
기준 HTML: `C:\Users\user\Downloads\Upstudy-student-app-design\upstudy-student-app-design.html`  
기준 HTML SHA-256: `EF8F6E40D01B099631C1940628E623A6113E1ADA68CFF3DEC0F1F89DEFCD0868`

> 이 문서는 기존 25화면 비교 문서를 대체한다. 기존 문서는 과거 밀도 리디자인·검증 기록으로 보존하되, 86개 화면 일치 여부와 hotfix 구현 판단의 기준으로 사용하지 않는다.

## 1. 비교 방법과 완전성 기준

1. HTML의 `defineScreen` 86개 상태를 기준으로 실제 Flutter 라우트·위젯·배포 진입 경로를 매핑한다.
2. 코드를 먼저 비교한다: 토큰, CSS cascade, DOM/위젯 구조, route/action target, 상태 저장, 모달·시트, 접근성 속성을 검사한다.
3. 코드로 결론을 낼 수 없는 항목만 같은 상태·같은 크기의 브라우저 캡처로 확인한다. 캡처는 `evidence/2026-09-01-deployed-vs-design/`에 저장한다.
4. 모든 차이는 아래 ID와 심각도로 남긴다.
   - `G-*`: 공통 토큰·셸·반응형·내비게이션
   - `S-<screen>-*`: 화면 구조·시각 차이
   - `A-<screen>-*`: 동작·라우팅·상태·접근성 차이
   - `P0`: 데이터 손실·보안·결제/권한 오류·도달 불가 핵심 동선
   - `P1`: 주요 기능 오동작·큰 정보구조 불일치
   - `P2`: 화면 구성·반응형·상태 표현 불일치
   - `P3`: 색·폰트·간격·반경·문구·아이콘 등 경미한 차이
5. 사용자명·진도·과제·코스 등 동적 값이 다른 것은 UI 결함으로 바꾸지 않고 `데이터 변동`으로 표기한다.
6. 완료 조건은 86개 ID가 모두 매핑되고, 각 차이 행에 코드 또는 캡처 근거와 수정 결정을 가진 상태다.

### 캡처 뷰포트

| 목적 | 크기 |
| --- | --- |
| 휴대폰 | 390×844 |
| 모바일 경계 | 720×900, 721×900 |
| Flutter/HTML 경계 교차 | 779×900, 780×900 |
| 데스크톱 셸 경계 | 1040×900, 1041×900 |
| PC | 1280×900 |
| 짧은 가로 | 844×390 |

## 2. 공통 차이 원장

| ID | 기준 HTML | 배포/현재 코드 | 심각도 | 결정 |
| --- | --- | --- | --- | --- |
| G-TOKEN-001 | canvas `#f0f0f2`, surface `#fdfdfe`, muted `#f3f3f5`, ink `#09090b`, dark `#111113` | `StudentDensityTokens`가 해당 값과 공통 breakpoint를 사용한다(`lib/shared/ui/student_density/student_density.dart:4-28`) | P3 | 공통 토큰 반영 완료; 화면별 legacy 색 선언만 잔여 감사 |
| G-SHELL-001 | PC 84px rail + main + 244px context aside | 상단 메뉴 중심 셸, 화면별 drawer 혼용 | P1 | 공통 StudentShell로 통합 |
| G-SHELL-002 | tablet 72px rail, aside 숨김 | 화면별 breakpoint가 720/780/900/980/1000으로 분산 | P2 | 공통 720/1040, 작업공간 예외만 유지 |
| G-SHELL-003 | mobile 66px bottom nav | 일부 화면만 bottom nav를 표시 | P1 | shell-backed 학생 화면에 일관 적용 |
| G-NAV-001 | mobile 활성 셀은 흰색 + 상단 3px 선 | `MobileStudentBottomAppBar`가 흰색 셀·활성 상단 3px 선을 사용한다(`lib/shared/ui/drawer/app_drawer.dart:192-237`) | P3 | 공통 하단탭 반영 완료; 화면별 activeRoute 매핑을 계속 감사 |
| G-NAV-002 | PC Home/Courses/자료실/More와 context rail | PC top nav와 mobile 자료실이 서로 다른 목적지 | P1 | typed route registry로 목적지 통일 |
| G-OVERLAY-001 | mobile sheet, PC dialog, home/more sheet 예외 | `showDialog`, drawer, bottom sheet가 화면별 상이 | P1 | overlay host·Escape·focus 반환 공통화 |
| G-TYPE-001 | Malgun/Noto 계열, 30–46px 최종 heading cascade | 화면별 32/52px 등 별도 선언 | P2 | 화면 예외를 제외하고 기준 type scale 적용 |
| G-A11Y-001 | aria label/role/modal/live/expanded/pressed/selected와 focus return | Flutter semantics 및 focus return이 화면별 불완전 | P1 | 모든 interactive target에 Semantics·focus contract 추가 |
| G-DATA-001 | HTML fixture 값은 디자인 상태 | 현재 API 값과 fixture 값 혼용 위험 | P1 | 실제 API 우선, fixture 복제 금지 |
| G-ROUTE-001 | 전역 검색 31개 목적지와 86개 상태 | 검색·drawer·딥링크가 일부만 연결 | P1 | 모든 CTA를 registry에 연결 |

## 3. 86개 화면 일대일 매핑 기준선

상태: `partial`은 라우트 또는 유사 위젯이 있으나 구조·동작 차이가 있는 상태, `missing`은 실제 학생 흐름에서 구현·도달할 수 없는 상태, `data-only`는 UI는 있으나 서버 데이터 계약이 없는 상태다.

### 시작 (7)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| login | `/login` · `LoginPage` | partial | HTML 단일 패널/모바일 fullscreen과 Flutter desktop split story/form, 버튼 활성·비밀번호 토글 차이 |
| signup-profile | `/signup` · `SignupPage` | partial | 3단계는 있으나 필드 순서·검증·disabled 상태·학교 선택 동작 차이 |
| signup-account | `/signup` · `SignupPage` | partial | 아이디 중복 검사·계정 단계 상태가 HTML 계약과 다름 |
| signup-complete | `/signup` · `SignupPage` | partial | 확인 화면 CTA·가입 완료 후 이동·오류 재진입 차이 |
| profile | `/profile` · `ProfilePage` | partial | HTML 계정 히어로·정보/보안 섹션은 이식됨. 인증 만료/로딩도 HTML 셸 재시도 카드로 렌더링하며, 실제 계정 연동·삭제/재인증 상태는 추가 확인 필요 |
| settings | `/settings` · `SettingsPage` | partial | HTML 직각 단일 패널·5개 행(교재/간편풀이/알림/계정 연동/라이선스)과 토글·액션 순서를 이식함. 계정 연동은 서버 계약 부재를 안내하는 시트로 제한 |
| about | `/landing/about` · `LandingAboutPage` | partial | HTML 5단계 제품 튜토리얼과 marketing/about 페이지 불일치 |

### 홈 (10)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| home | `/student/dashboard` · `MainStudentPage` + `HtmlHomeDashboard` | partial | HTML A rail·상단바·현재 코스/이어하기·6 action·마이 대시보드 구조는 이식됨. 실제 API 데이터·일부 카드 상태·상호작용은 추가 일치화 필요 |
| today-tasks | 홈 modal · `today_tasks_modal.dart` | partial | 시간순 task·완료/추가 상태와 현재 modal 구성 차이 |
| course-select | 홈 modal · `curriculum_modal.dart` | partial | 코스 선택 sheet 높이·행·완료/미등록 이동 차이 |
| rating-detail | 홈 modal · `rating_detail_modal.dart` | partial | OVR graph/개념·활동 상세 구조 차이 |
| daily-test | `/level_test` · `LevelTestHomePage` | partial | HTML 홈 quick action과 실제 진입·라벨 차이 |
| study-mode | 제한 모드 route/modal | partial | HTML sheet와 drawer의 모드 선택·복귀 차이 |
| activity-history | `/schedule`·활동 보고서 | partial | 56일 타임라인·활동 지표와 현재 일정/이력 분리 |
| achievements | 활동 배지 위젯 | partial | 탭·상세 sheet·진행률 상태가 HTML 구조와 다름 |
| schedule | `/schedule` · `SchedulePage` | partial | 실제 일정·개인 일정 API와 일간/월간 전환을 유지하면서 `StudentHtmlShell` 레일·상단바·모바일 하단탭·1040px 컨텍스트 분기를 이식함(`lib/features/student_schedule/schedule_page.dart:430-560`). 상세 타임라인 cascade와 코스 ID가 없는 오류 상태는 추가 일치화 필요 |
| schedule-history | `/schedule/history` · `CurriculumHistoryPage` | partial | 실제 이력 필터·성공/실패/재분배 상태를 유지하면서 `StudentHtmlShell` 레일/상단바/모바일 하단탭을 적용함. 샘플 이력은 현재 fixture 계약 범위로 남음 |

### 코스 (14)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| courses | `/courses` · `CourseCatalogPage` | partial | HTML library shell·filter·카드 밀도 차이 |
| course-detail | 코스 상세 위젯 | partial | HTML 진행 hero·5단계·직각 curriculum·모바일 이어하기 CTA를 이식함. 실제 코스 유닛·등록 API 상태와 완전한 행별 결과는 데이터/인증 상태에 따라 추가 확인 필요 |
| course-learning | 코스 학습 위젯 | partial | mission dispatcher·다음 문제·runtime 상태 차이 |
| course-runtime | `/course_runtime` · `CourseRuntimePage` | partial | `courseId` 딥링크는 실제 코스 조회 후 `CourseLearningPage`로 연결하고, 인자 없는 레거시 경로만 코스 목록으로 위임 |
| review-course | 복습 course 위젯 | partial | review 상태·완료 후 복귀 차이 |
| course-curriculum | 코스 curriculum 위젯 | partial | 현재 단원 자동 펼침·선행 상태 차이 |
| course-challenge | challenge 위젯 | partial | challenge 묶음·제한 시간·재시도 차이 |
| course-exam | exam 위젯 | partial | 시험 전 preview/submit/result 연결 차이 |
| course-review | review 위젯 | partial | 코스 review CTA·완료 갱신 차이 |
| level-home | `/level_test` · `LevelTestHomePage` | partial | 실제 25문항 시작/제출/결과 API는 유지하면서 `StudentHtmlShell` 레일·상단바·모바일 하단탭·1040px 컨텍스트 분기를 이식함(`lib/features/level_test/level_test_home_page.dart:170-240`). 진단 overview의 세부 cascade와 인증/완료 상태는 추가 확인 필요 |
| level-solve | level test runtime | partial | 25문항·시간·뒤로가기 상태 검증 필요 |
| level-result | `/level_test/result` | partial | 결과·재시도·코스 추천 상태 차이 |
| wrong-list | `/wrong_answers` · `WrongAnswerListPage` | partial | 실제 오답 이력·약점 태그·복습 계획·재풀이 CTA를 유지하면서 `StudentHtmlShell` 레일/상단바/모바일 하단탭을 적용함. 인증 없는 canary는 계획 수치가 0인 정상 빈 상태로 표시됨 |
| wrong-solve | `/wrong_answer_solve` · `WrongAnswerSolvePage` + `WrongAnswerReviewWidget` | partial | 실제 약점/습관 조회와 BuildpageWidget 진입을 연결함. 인증·데이터가 없으면 HTML 셸 안에서 오류/재시도 상태를 표시 |

### 풀이 (8)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| student-runtime | `/student/runtime` · `StudentRuntimePage` | partial | 실제 런타임 코스·모듈·시작 API 계약을 유지하면서 `StudentHtmlShell` 레일/상단바/모바일 하단탭, ACTIVE COURSE·진행률·현재 학습·COURSE ROUTE 구조를 이식함. 인증 없는 canary에서는 fixture를 삽입하지 않아 실제 코스 상태는 빈/오류 경계로 남음 |
| solve-workspace | 학생 풀이 workspace | partial | HTML Flow 진입·toolbar·state overlay 차이 |
| flow-view | Flow 분석 위젯 | partial | 단계별 정오답·AI 의견·그래프 표현 차이 |
| shared-flow | 공유 Flow 위젯 | partial | 공유자·기간·취소·필터 계약 차이 |
| solution-view | 풀이 해설 위젯 | partial | 이전/다음·다시 풀기·수식 표시 차이 |
| solve-analysis | 풀이 분석 위젯 | partial | intermediate trace·상태 전이 차이 |
| ox-quiz | OX runtime | partial | 500ms progression·결과 pop·뒤로가기 확인 필요 |
| weakness-review | 약점 복습 위젯 | partial | 변형 문제·약점 연결·완료 상태 차이 |

### 교재 (11)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| bookbag | `/bookbag` · `BookWidget` | partial | HTML 3 material sheet와 현재 책가방 구조 차이 |
| bookbag-detail | bookbag detail | partial | square mobile detail sheet·삭제 확인 차이 |
| book-library | library 위젯 | partial | 교재/시험지/북마크 탭·빈 상태 차이 |
| book-reader | `BookPage`/`DocxBox` | partial | 기능은 가장 근접하나 TOC·toolbar·모바일 rail 차이 |
| bookmarks | bookmarks sheet | partial | 최근 저장 목록·복귀 상태 차이 |
| textbook-create | 교재 만들기 | P1 | 실제 caller/API가 없어 production unreachable |
| textbook-editor | 교재 editor | P1 | `createTextbook()`가 빈 응답이며 fake route 금지 상태 |
| concept-tags | 개념 tag sheet | partial | tag 연결·reader 복귀 차이 |
| exam-preview | 시험지 preview | partial | A4 preview·시작/편집 이동 차이 |
| exam-paper | 시험지 풀이 | partial | canvas/page/stroke/autosave UI와 HTML 배치 차이 |
| exam-report | 시험 결과 | partial | heatmap·오답·재시도 연결 차이 |

### 자료실·상점 (4)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| marketplace | `/marketplace` · `MarketplacePage` | partial | HTML resource grid/filter와 실제 API·구매 상태는 유지하면서 `StudentHtmlShell` 레일/상단바/하단탭 및 검색 포커스·알림 액션을 이식함(`lib/sessions/marketplace/ui/pages/marketplace_page.dart:390-457`). 카드·필터의 세부 cascade와 데이터 상태는 추가 일치화 필요 |
| store | 상점 route | partial | 포인트/구독 탭·wallet·확인 sheet·실구매 계약 차이 |
| market-filter | marketplace filter sheet | partial | filter field 수·적용/닫기 상태 차이 |
| market-preview | market preview sheet | partial | preview tab·무료/유료/owned CTA 차이 |

### 소셜 (14)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| social | `/social` · `SoWidget` | partial | HTML neutral/blue/green social hub와 legacy green/Inter 차이 |
| social-friends | friend tab | partial | 친구 OVR·검색·탭 상태 차이 |
| friend-requests | friend requests | partial | pending/accepted/declined/cancelled 상태 차이 |
| friend-add | friend search/add | partial | 검색·요청 결과와 실제 API 오류 상태 차이 |
| direct-chat | direct chat | partial | 최근 30개·삭제·WebSocket 상태 차이 |
| groups | `/groups` | partial | 검색/생성/참여 sheet와 현재 페이지 차이 |
| group-find | group search | partial | 공개/잠금 필터·비밀번호 검증 차이 |
| group-create | group create | partial | max/group limit·password validation 차이 |
| group-join | `/groups/join?code=...` · `GroupJoinPage` | partial | 실제 초대 메타·참가 API와 실패/재시도 상태를 유지하면서 `StudentHtmlShell` 상단바·하단탭을 적용함. 잠금/공개 성공 상태는 인증 세션 필요 |
| group-detail | `/group/detail?id=...` · `GroupDetailPage` | partial | 실제 그룹·멤버·일정·공유·채팅 3탭 계약을 유지하면서 모바일/PC `StudentHtmlShell`로 전환함. 브라우저 딥링크는 `id`/`groupId`를 지원하며 인증 데이터는 별도 검증 필요 |
| group-chat | group chat | partial | 메시지·권한·공유 상태 차이 |
| group-share | group share | partial | 최근 60일·최대 5개·학생 답안 제외 계약 차이 |
| student-academy | `/academy/dashboard?id=...` · `StudentAcademyPage` | partial | 실제 학원·과제·출석·시간표 API를 유지하면서 `StudentHtmlShell` 레일/상단바/하단탭을 적용함. `id`/`academyId` 딥링크를 지원하고 인증 없는 canary는 재시도 상태를 표시 |
| academy-details | academy detail | partial | 실제 academy 정보·권한·수납 데이터와 HTML student detail 차이 |

### 학생서비스·내신 (6)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| academy-find | `/student-services/academy` · `StudentServicesDemoPage(academy)` | demo | 지도/목록/검색/샘플 학원 finder, `STUDENT_SERVICES_DEMO` flag |
| academy-profile | `/student-services/academy/profile` · `StudentServiceProfilePage` | demo | 학원 소개·상담 신청 sheet, 실제 전송 없음 |
| private-tutor-find | `/student-services/tutor` · `StudentServicesDemoPage(tutor)` | demo | 지도/목록/선생님 finder, `STUDENT_SERVICES_DEMO` flag |
| private-tutor-profile | `/student-services/tutor/profile` · `StudentServiceProfilePage` | demo | 선생님 소개·수업 문의, 실제 전송 없음 |
| service-requests | `/student-services/requests` · `StudentServiceRequestsPage` | demo | 샘플 문의 history·취소 상태, 프로세스 로컬 |
| school-exam-prep | `/school-exam-prep` · `SchoolExamPrepPage` | partial | 수학 계획 API·빈 상태·버전 저장 반영, 연결된 실제 시험이 없으면 문제 CTA 비활성 |

### 아레나 (5)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| arena-home | `/arena` · `ArenaPage` | partial | lobby·rank·매칭 CTA 구조 차이 |
| arena-ready | Arena ready state | partial | 준비·제한 시간·취소 상태 차이 |
| arena-match | Arena match state | partial | 1v1/2v2 timer·chat·submit 차이 |
| arena-result | Arena result state | partial | tier·재시도·랭킹 이동 차이 |
| arena-ranking | ranking state | partial | 필터·친구·페이지 상태 차이 |

### 도구 (7)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| tutor | `/tools` · `ServerChatPage` | partial | HTML tutor CTA/context와 standalone chat 차이 |
| tools-hub | `/learning-tools` · `StudentLearningToolsPage` | partial | 실제 노트·타이머·집중·AI 튜터 진입을 유지하면서 `StudentHtmlShell` 레일/상단바/모바일 하단탭과 HTML 카드 그리드를 적용함 |
| learning-tools-modal | learning tools modal | partial | six destination·nested return 상태 차이 |
| notepad | `NotepadPage` | partial | 저장·모바일 toolbar·복귀 차이 |
| timer | `TimerPage` | partial | 기존 스톱워치·타이머·랩 상태를 유지하면서 도구 모달 내부에도 `StudentHtmlShell` 반응형 셸을 적용함 |
| focus | `FocusModePage` | partial | hub 경유만 가능, 독립 접근 경로 차이 |
| graph | `JsxGraphPage` | partial | canvas/식 오류/drag tray·모바일 경계 차이 |

## 4. 신규 기능 계약과 구현 결정

### 학생서비스 데모

- `STUDENT_SERVICES_DEMO`를 canary에서만 켠다. 화면과 접수 결과에 `샘플 데이터 · 실제 문의 전송 없음`을 표시한다.
- 학원·과외 fixture는 앱 내부에 두고 `aiflow.student.services.demo.v1`에 선택 상태만 저장한다. 전화번호·이메일·실제 위치 권한은 수집하지 않는다.
- OSM은 `flutter_map` TileLayer와 고정 샘플 좌표를 사용한다. 지도/목록 전환, 지역·학년·거리 필터, 프로필, 문의 sheet, 취소 상태를 동일하게 구현한다.
- tile URL은 `OSM_TILE_URL`로 교체 가능하게 하고 attribution, HTTPS, 브라우저 캐시, no-prefetch/no-offline를 준수한다. 공개 OSM tile은 canary 데모에만 사용한다.

### 수학 전용 내신 대비

- 영어·과학 화면과 엔진은 만들지 않는다.
- `student_school_exam_plan`, `student_school_exam_task`를 추가한다.
- `GET/PUT /student/school-exam-plan/active`, `PATCH /student/school-exam-plan/tasks/{taskId}`를 제공한다.
- 시험 범위·문항·할 일은 기존 수학 시험/과제에 연결된 실제 데이터만 사용한다. 데이터가 없으면 빈 상태를 표시하고 fake 문제를 만들지 않는다.
- `version` 기반 충돌을 `409`로 반환하며, 문제 시작 CTA는 유효한 기존 시험 ID가 있을 때만 활성화한다.

### 더미 포인트 상점과 구독 UI

- 포인트 상품은 더미 상품이지만 `demo_student_wallet`, `demo_store_item`, `demo_store_order`, `demo_store_entitlement`를 서버 권위로 처리한다.
- 초기 데모 잔액은 사용자당 한 번만 `12,840P`로 만든다. 상품 가격은 HTML 기준을 유지한다.
- `GET /demo/student-store`, `POST /demo/student-store/orders`를 추가한다.
- `X-Idempotency-Key`가 필수이며 같은 key+body는 기존 결과 재전달, 같은 key+다른 body는 `409`, 잔액 부족은 차감 없이 실패한다.
- 주문·잔액 잠금·차감 원장·더미 entitlement는 한 트랜잭션으로 처리한다. 동시에 같은 상품을 요청해도 이중 차감하지 않는다.
- 1개월·6개월 구독은 선택·확인 UI만 제공한다. PG 호출, 카드 입력, 실제 주문·구독 entitlement는 구현하지 않는다.

## 5. 검증과 배포 게이트

- 86개 화면, 모든 route/action target, overlay, 뒤로가기, Escape, focus return을 자동 검증한다.
- 기존 `18 passed / 7 failed` drawer 테스트는 새 route registry 기준으로 갱신해 0 failures로 만든다.
- 뷰포트 경계별 golden/layout test와 브라우저 캡처를 수행한다. 코드로 확정되지 않은 모든 행에는 배포/HTML 이미지 쌍이 있어야 한다.
- API는 인증 없는 요청 401, 타 사용자 조회·수정 거부, 가격 변조 거부, stale version 409, idempotency replay를 검사한다.
- 동일 포인트 주문 200 concurrent 테스트에서 주문·차감·원장이 각각 1회만 생성되는지 확인한다.
- OSM attribution 노출, 타일 URL CSP allowlist, prefetch 없음, 샘플 플래그 off 시 메뉴·검색·딥링크 비노출을 검사한다.
- Flutter analyze/test, Vercel bundle 내 `localhost` 부재, `/health`, CORS, invalid-login 401을 확인한다.
- 최종 검증 후 `origin/hotfix`에 커밋·push하고 `aiflow-web-canary`에 배포한다. alias·SHA·브라우저 모바일/PC 캡처를 문서 마지막에 갱신한다.

## 6. 허용되는 의도적 차이

1. 실시간 사용자 데이터와 HTML fixture 값의 차이.
2. 학생서비스가 데모임을 명확히 하기 위한 안내 문구와 실제 전송 차단.
3. AIFlow가 수학 전용이므로 영어·과학 내신 콘텐츠를 제공하지 않는 차이.
4. 원화 구독을 실제 결제로 오인하지 않게 하는 UI 전용 완료 문구.

그 외 P0–P3 차이는 모두 구현하거나, 최종 검증 시 이 문서에 구체적인 사유와 이미지 근거를 추가한다.

## 7. hotfix 구현 반영 및 검증 상태 (2026-09-01)

| 영역 | 반영 내용 | 근거 | 상태 |
| --- | --- | --- | --- |
| 공통 토큰 | `#f0f0f2/#f3f3f5/#111113`, 720/1040 breakpoint, 모바일 활성 상단선 | `lib/shared/ui/student_density/student_density.dart`, `lib/shared/ui/drawer/app_drawer.dart` | 반영 |
| 라우팅 | 86개 ID typed registry, academy/tutor/profile/requests, 내신, store route | `lib/app/student_route_registry.dart`, `lib/app/router.dart` | 반영 |
| 데모 서비스 | OSM HTTPS 타일·attribution, 로컬 fixture·검색·필터·문의 상태, flag off 메뉴 숨김 | `lib/features/student_services/student_services_demo_page.dart`, `lib/app/student_feature_flags.dart` | 반영 |
| 수학 내신 | `GET/PUT /student/school-exam-plan/active`, task PATCH, version conflict, 연결 데이터 없을 때 빈 상태 | `api/index.py`, `omj/migrations/postgres/010_student_demo_services_store.sql` | 반영 |
| 포인트 상점 | 4개 더미 상품, 서버 RPC 지갑 잠금·원장·중복/멱등 키·잔액 부족 분기, UI-only 구독 | `api/index.py`, `omj/migrations/postgres/010_student_demo_services_store.sql`, `lib/shared/services/api/api_client.dart` | 반영(마이그레이션 적용 필요) |
| 캡처 근거 | 기준 HTML, 배포 canary, 로컬 hotfix의 동일 상태·뷰포트 캡처를 evidence 폴더에 저장 | 홈: `design-home-390x844.png`, `design-home-1280x900.png`, `deployed-725cf16-home-390x844.png`, `deployed-725cf16-home-1280x900.png`; 설정: `design-settings-390x844.png`, `design-settings-1280x900.png`, `deployed-725cf16-settings-390x844.png`, `deployed-725cf16-settings-1280x900.png`; 프로필: `design-profile-390x844.png`, `design-profile-1280x900.png`, `deployed-725cf16-profile-390x844.png`, `deployed-725cf16-profile-1280x900.png`; 코스 목록 정식 경로(`/courses`): `design-courses-390x844.png`, `design-courses-1280x900.png`, `deployed-725cf16-courses-canonical-390x844.png`, `deployed-725cf16-courses-canonical-1280x900.png`; 코스 상세 기준: `design-course-detail-390x844.png`, `design-course-detail-1280x900.png`; 로컬 재현: `local-profile-shell-error-390x844.png`, `local-profile-shell-error-1280x900.png`, `local-settings-html-390x844.png`, `local-settings-html-1280x900.png` | 홈·설정·프로필·코스 목록 최종 캡처는 `725cf16` production alias 기준이며 각 상태에서 브라우저 error/warn 0건을 새 탭·5초 대기 후 확인한다. 코스 목록은 정식 `/courses` 경로의 인증 없는 API 빈 상태를 데이터 변동으로 그대로 기록하며, 상세는 기준 HTML 구조와 코드로 검증한다. `/student/courses`는 등록되지 않은 별칭으로 별도 라우팅 차이를 기록한다 |

### 2026-09-02 HTML 구조 이식 추가분

| 화면 | 실제 Flutter 반영 | 이미지·코드 근거 | 남은 차이 |
| --- | --- | --- | --- |
| 설정 | `StudentHtmlShell` + `_HtmlSettingsRow`/`_HtmlSettingsActionRow`로 HTML의 단일 직각 패널, 5개 행, 블랙/화이트 토글을 사용. 기존 로컬 설정 저장과 라이선스·계정 연동 안내 동작은 유지 | `lib/sessions/settings/ui/pages/settings_page.dart`; `local-settings-html-390x844.png`, `local-settings-html-1280x900.png`; 기준 `design-settings-390x844.png`, `design-settings-1280x900.png` | 계정 연동은 실제 서버 계약이 없어 안내 시트만 제공. 인증 계정에서 저장/라이선스 포커스 복귀는 별도 검증 필요 |
| 프로필 | 로딩·인증 만료 상태를 `StudentHtmlShell`의 A 레일·HTML 상단바·모바일 탭과 재시도 카드로 감쌈. 정상 데이터 경로는 기존 `_ProfileHero`/폼/API 계약을 유지 | `lib/sessions/auth/ui/pages/profile_page.dart`; `local-profile-shell-error-390x844.png`, `local-profile-shell-error-1280x900.png`; 기준 `design-profile-390x844.png`, `design-profile-1280x900.png` | 실제 계정 데이터에서 HTML 정보/보안 행·삭제 확인 모달의 일대일 캡처는 인증 세션 없이는 완료할 수 없음 |
| 코스 상세 | `_HtmlCourseProgressHero`와 `_HtmlCourseCurriculum`으로 진행 hero·단계·유닛 상태·모바일 하단 CTA를 실제 `Course` 객체에 연결. 등록·이어하기·미리보기 API/동작은 기존 계약을 호출 | `lib/sessions/course/ui/course_detail_page.dart`; 기준 `design-course-detail-390x844.png`, `design-course-detail-1280x900.png` | 인증 없는 canary에서는 코스 상세로 진입할 코스가 없어 production 이미지 캡처는 보류. 유닛이 없을 때 샘플 코스를 만들지 않고 빈 상태로 표시 |
| 오답 재풀이 | `/wrong_answer_solve`가 `WrongAnswerReviewWidget`의 약점/습관 조회로 진입하고 `BuildpageWidget`으로 실제 풀이를 교체 연결. HTML 상단 셸·모바일 하단탭·오류/재시도 상태를 사용 | `lib/features/wrong_answer/wrong_answer_solve_page.dart`, `lib/features/wrong_answer/wrong_answer_list_page.dart`, `lib/app/router.dart`, `lib/sessions/course/ui/widgets/wrong_answer_review_widget.dart`; `test/wrong_answer_legacy_route_test.dart`, `test/secondary_route_shell_test.dart`; 배포 `deployed-98b2b26-wrong-solve-390x844.png`, `deployed-98b2b26-wrong-solve-1280x900.png` | 화면·전환은 검증했으나 canary의 실제 인증/OMJ secret 미설정으로 문제 목록은 503 오류/재시도 상태다. 샘플 문제를 삽입하지 않는다 |
| 코스 런타임 | `/course_runtime?courseId=...`를 실제 `CourseService.fetchCourse`와 `CourseLearningPage`로 연결하고, 식별자 없는 레거시 경로는 코스 탐색으로만 위임 | `lib/features/course_runtime/course_runtime_page.dart`, `lib/app/router.dart`; `test/student_route_registry_test.dart`; 배포 `deployed-d1cd127-course-runtime-390x844.png`, `deployed-d1cd127-course-runtime-1280x900.png` | 인증/코스 ID가 없는 canary에서는 조회 오류 상태만 가능하며, 임의 코스·샘플 진행을 생성하지 않는다 |
| 자료실·마켓 | `MarketplacePage`를 `StudentHtmlShell` 안으로 이동해 PC 84px 레일·1280px 컨텍스트·상단바, 모바일 상단바·66px 하단탭을 실제 검색/필터/구매 본문과 결합. 상단 검색 액션은 검색 필드 포커스로 연결 | `lib/sessions/marketplace/ui/pages/marketplace_page.dart:390-457`, `lib/shared/ui/student_density/student_html_shell.dart`; `test/marketplace_page_test.dart`; 배포 `deployed-663fd3d-marketplace-390x844.png`, `deployed-663fd3d-marketplace-1280x900.png` | 실제 canary 인증 없이 자료 목록은 API 오류/빈 상태이며, 카드·필터의 HTML 세부 cascade와 구매 성공 데이터는 인증 세션에서 추가 확인 필요 |
| 학습 일정 | `SchedulePage`를 `StudentHtmlShell` 안으로 이동해 실제 일정 조회·개인 일정 저장/삭제·일간/월간 전환을 보존하고, HTML의 모바일 세로 카드/PC 2열 컨텍스트 구조를 적용 | `lib/features/student_schedule/schedule_page.dart:430-560`, `test/personal_schedule_mobile_test.dart`; 배포 `deployed-Cua58vQ-schedule-390x844.png`, `deployed-Cua58vQ-schedule-1280x900.png` | canary 인증·코스 ID가 없으면 일정 오류/빈 상태만 표시되며, 실제 일정 데이터와 월간 타임라인의 세부 cascade는 인증 세션에서 추가 확인 필요 |
| 레벨 테스트 | `LevelTestHomePage`를 `StudentHtmlShell` 안으로 이동해 실제 배치 세션·25문항 시간 계약·결과 전환을 보존 | `lib/features/level_test/level_test_home_page.dart:170-240`, `test/level_test_home_page_test.dart`, `test/placement_exam_flow_test.dart`; 배포 `deployed-GfznG3G-level-test-390x844.png`, `deployed-GfznG3G-level-test-1280x900.png` | canary 인증 없이 시작 API를 검증할 수 없어 시작 전 overview 상태만 확인 가능. HTML 진단 overview의 완전한 데이터 매핑은 인증 세션 필요 |
| 학생 런타임 | `/student/runtime`를 `StudentHtmlShell`로 전환하고 실제 `StudentRuntimeService` 코스·모듈·세션 시작 동작을 유지. 모바일은 HTML 상단바/하단탭, PC는 84px 레일·메인·컨텍스트 분기를 사용 | `lib/features/student_runtime/student_runtime_page.dart`, `test/secondary_route_shell_test.dart`; 배포 `deployed-Dd8WwK-student-runtime-390x844.png`, `deployed-Dd8WwK-student-runtime-1280x900.png` | 최신 production에서 두 뷰포트와 콘솔 error/warn 0건을 확인. 인증 없는 canary는 실제 코스 API 경계를 사용하므로 샘플 데이터로 덮지 않음 |
| 오답 목록 | `/wrong_answers`를 `StudentHtmlShell`로 전환하고 실제 풀이 이력·약점 태그·복습 계획·필터/정렬 동작을 유지 | `lib/features/wrong_answer/wrong_answer_list_page.dart`, `test/wrong_answer_legacy_route_test.dart`, `test/secondary_route_shell_test.dart`; 배포 `deployed-6kkHdc-ou-wrong-list-390x844.png`, `deployed-6kkHdc-ou-wrong-list-1280x900.png` | 최신 production에서 HTML 모바일/PC 셸과 콘솔 error/warn 0건을 확인. 인증 없는 canary는 샘플 문제를 생성하지 않고 0건 빈 계획을 표시 |
| 커리큘럼 이력 | `/schedule/history`를 `StudentHtmlShell`로 전환하고 전체/성공/실패/재분배 필터 동작을 유지 | `lib/features/student_schedule/curriculum_history_page.dart`, `test/secondary_route_shell_test.dart`; 배포 `deployed-44FnEFg-schedule-history-390x844.png`, `deployed-44FnEFg-schedule-history-1280x900.png` | 최신 production에서 HTML 모바일/PC 셸과 필터 상태를 확인 |
| 학습 도구 허브 | `/learning-tools`를 `StudentHtmlShell`로 전환하고 노트·타이머·집중·AI 튜터 카드/모달 동작을 유지 | `lib/sessions/learning_tools/ui/pages/student_learning_tools_page.dart`, `test/student_learning_tools_route_test.dart`; 배포 `deployed-44FnEFg-learning-tools-390x844.png`, `deployed-44FnEFg-learning-tools-1280x900.png` | 최신 production에서 HTML 모바일/PC 셸과 콘솔 error/warn 0건을 확인 |
| 학원 대시보드 | `/academy/dashboard?id=a1`을 `StudentHtmlShell`로 전환하고 학원 정보·오늘 할 일·출석·시간표 API 계약을 보존 | `lib/features/group_study/student_academy_page.dart`, `lib/app/router.dart`; 배포 `deployed-54fDiww-academy-390x844.png`, `deployed-54fDiww-academy-1280x900.png` | 최신 production에서 HTML 모바일/PC 셸과 콘솔 error/warn 0건을 확인. 인증 없는 canary는 샘플 학원 데이터를 만들지 않고 재시도 상태를 표시 |
| 그룹 초대 | `/groups/join?code=ABC123`를 `StudentHtmlShell`로 전환하고 실제 초대 메타 조회·참가·복귀 동작을 유지 | `lib/features/group_study/group_join_page.dart`, `test/secondary_route_shell_test.dart`; 배포 `deployed-54fDiww-group-join-390x844.png`, `deployed-54fDiww-group-join-1280x900.png` | 최신 production에서 HTML 모바일/PC 셸과 콘솔 error/warn 0건을 확인. 인증/코드가 없으면 실제 404 오류·재시도 상태를 표시 |
| 그룹 상세 | `/group/detail?id=group-1`을 `StudentHtmlShell`로 전환하고 그룹·멤버·일정·공유·채팅 동작을 유지 | `lib/features/group_study/group_detail_page.dart`, `lib/app/router.dart`, `test/group_detail_mobile_test.dart`; 배포 `deployed-54fDiww-group-detail-390x844.png`, `deployed-54fDiww-group-detail-1280x900.png` | 최신 production에서 HTML 모바일/PC 셸과 콘솔 error/warn 0건을 확인. 인증 없는 canary는 그룹 정보 오류 상태를 표시하며 임의 그룹을 삽입하지 않음 |

### 2026-09-02 추가 이식분 — hotfix 작업 트리

아래 항목은 지정 HTML의 구조·셸·상태 순서를 실제 Flutter 화면에 연결한 변경분이다. 배포 캡처가 생성되기 전까지 이미지 근거는 `pending`으로 남기며, 코드/테스트 근거만으로 시각적 일치를 확정하지 않는다.

| HTML ID | Flutter 반영 | 코드·테스트 근거 | 이미지 근거 / 잔여 확인 |
| --- | --- | --- | --- |
| courses | 코스 목록을 `StudentHtmlShell`에 연결하고 HTML 순서(현재 코스 → 추천 → 전체 코스), 필터·검색·카드 CTA를 유지 | `lib/sessions/course/ui/course_catalog_page.dart`; `test/course_catalog_opendesign_recovery_test.dart`, `test/student_home_course_catalog_responsive_test.dart`, `test/student_learning_widget_test.dart` | `pending` — 390×844·1280×900 재배포 캡처 필요 |
| course-detail | 완료 코스는 학습 CTA 대신 `미리보기 →`를 노출하고 잠금/단원 CTA도 미리보기로 연결 | `lib/sessions/course/ui/course_detail_page.dart`; `test/student_learning_widget_test.dart` | `pending` — 완료/빈 유닛 상태 이미지 필요 |
| course-learning | 모바일/PC를 공통 셸로 전환하고 좁은 데스크톱 학습 패널의 고정 높이를 HTML 리듬(252px)에 맞춤 | `lib/sessions/course/session/course_learning_page.dart`; `test/course_learning_mobile_redesign_test.dart`, `test/student_learning_widget_test.dart` | `pending` — 390×844·1280×900 및 경계 폭 캡처 필요 |
| social / friend / direct-chat | 친구·요청·추가·직접 채팅을 상단바·모바일 하단탭·소셜 활성 섹션으로 통일 | `lib/sessions/friend/friend.dart`, `lib/sessions/friend/ui/friend_screen.dart`, `lib/sessions/friend/ui/student_direct_chat_page.dart`; `test/friend_request_mobile_test.dart`, `test/mobile_secondary_shell_test.dart` | `pending` — 친구 목록/요청/채팅 상태별 이미지 필요 |
| groups / arena | 그룹 목록과 대결장을 `StudentHtmlShell`로 감싸고 기존 생성·참여·매칭 API/상태를 보존 | `lib/features/group_study/group_list_page.dart`, `lib/features/arena/arena_page.dart`; `test/mobile_secondary_shell_test.dart`, `test/arena_mobile_join_test.dart` | `pending` — 390×844·1280×900 캡처 필요 |
| graph / flow-view | 그래프 탐색기와 풀이 흐름 분석을 공통 셸로 연결하되 몰입형 전체화면·드래그 모달은 유지 | `lib/sessions/graph_tools/session/jsx_graph_page.dart`, `lib/sessions/tryout_solve/ui/pages/flow_view_page.dart`; `test/jsx_graph_page_test.dart`, `test/student_learning_widget_test.dart` | `pending` — Canvas/수식/오버레이 이미지 비교 필수 |
| bookbag / book-library / book-reader | 책가방·교재 라이브러리·자료실을 PC 레일/컨텍스트·모바일 상단바/하단탭으로 통일하고 제목·부제 overflow를 제한 | `lib/sessions/textbook/ui/pages/book_page.dart`, `lib/sessions/textbook/ui/pages/docx_box.dart`; `test/bookbag_mobile_redesign_test.dart` | `pending` — 390×844·1280×900 및 수식 줄바꿈 캡처 필요 |
| academy-find / tutor-find / service-requests / school-exam-prep / store | 학생서비스·내신·데모 상점 화면을 HTML 셸로 감싸고 기존 demo flag/로컬 상태/인증 경계를 유지 | `lib/features/student_services/student_services_demo_page.dart`; API 계약은 `api/index.py` 및 migration 참조 | `pending` — demo flag on/off, OSM attribution, 빈/오류 상태 이미지 필요 |
| level-result | 레벨 결과 화면을 공통 셸로 통일하고 852px 이하 렌더링을 모바일 레이아웃으로 검증 | `lib/features/level_test/level_test_result_page.dart`; `test/level_test_result_page_test.dart` | `pending` — 결과/재시도/추천 상태 이미지 필요 |
| study-center | 학습터를 공통 셸로 전환하고 기존 카드·검색·실행 동작을 유지 | `lib/sessions/legacy_cleanup/session/study_center.dart` | `pending` — 390×844·1280×900 캡처 필요 |

초기 비교 캡처(`deployed-dashboard-390x844.png`)는 이전 `public/main.dart.js` 정적 번들이 배포된 상태라 흰 화면으로 기록되었다. 이후 `HtmlHomeDashboard`가 실제 Flutter 홈 본문을 대체하고 `_HtmlStudentRail`·`_HtmlStudentTopBar`·`_HtmlContextAside` 공통 셸을 추가했다. `725cf16` production 배포에서 HTML과 같은 390×844·1280×900 홈 구조(모바일 상단바/하단탭, 데스크톱 A 레일, 인사·코스·이어하기, 6개 액션, 마이 대시보드, 우측 컨텍스트)를 이미지로 재확인했고, 설정·프로필·코스 목록에도 같은 셸과 HTML 구조를 이식했다(`deployed-725cf16-*.png`). `663fd3d` production 배포에서는 자료실도 같은 셸로 전환해 `deployed-663fd3d-marketplace-390x844.png` 및 `deployed-663fd3d-marketplace-1280x900.png`로 확인했다. 새 탭에서 5초 대기 후 브라우저 콘솔 error/warn은 0건이었다(정보 로그에는 canary `OMJ_JWT_SECRET` 미설정 안내가 남는다). 브라우저 DOM 접근성 스냅샷은 CanvasKit 특성상 `Enable accessibility` 버튼만 노출되어, Semantics·키보드 포커스는 별도 Flutter 테스트 범위로 남긴다. 기준 HTML은 `?screen=home` 상태에서 같은 순서와 밀도로 표시됨을 확인했다. 이 반영은 홈·공통 셸·설정·프로필·코스 상세·자료실 구조에 한정되며, 나머지 화면은 아래 매핑 상태(`partial`/`missing`) 그대로 추가 구현 대상이다.

### 최종 배포 기록 (2026-09-02)

- 커밋: `ae6ec27` (`refactor(student): align tools and history shells`), `origin/hotfix` 반영. 학원·그룹·학습 도구·커리큘럼 이력 셸과 딥링크, 이전 화면 수정이 포함된다.
- Vercel: [`dpl_44FnEFgoDpiFXHiAEfGojQzANQpQ`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/44FnEFgoDpiFXHiAEfGojQzANQpQ), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/student/dashboard). 새 release bundle에 학습 도구·커리큘럼 이력 HTML 셸 변경을 포함한다.
- 환경: release bundle에 `API_BASE_URL=https://aiflow-web-canary.vercel.app`, `STUDENT_SERVICES_DEMO=true`, `STUDENT_STORE_DEMO=true`, HTTPS `OSM_TILE_URL`을 정의했다. 포인트 데모 API는 canary에서만 활성화된다.
- 런타임: `GET /health` 200, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active`는 401 JSON이며 release bundle에는 `localhost`가 없다.
- 브라우저: production alias의 390×844 모바일·1280×900 데스크톱 홈·설정·프로필·코스 목록·오답 재풀이·오답 목록·코스 런타임·자료실·학습 일정·레벨 테스트·학생 런타임·학원·그룹 초대·그룹 상세·학습 도구 허브·커리큘럼 이력을 새 탭에서 5초 대기 후 캡처했고, 각 최신 캡처의 콘솔 error/warn은 0건이다. 학원·그룹 초대·그룹 상세·학습 도구 허브·커리큘럼 이력은 최신 `44FnEFg` 배포에서 HTML 모바일 상단바/하단탭과 PC A 레일/메인 셸을 확인했다. 오답 재풀이 데이터 호출은 canary에서 `OMJ_JWT_SECRET is not configured` 503을 반환해 오류/재시도 상태로 캡처했다. 코스 런타임도 인증 없는 임의 ID에 대해 오류/목록 복귀 상태를 렌더링한다. 자료실·학습 일정·레벨 테스트는 API 인증/데이터 경계에서 HTML 셸의 빈/오류 또는 시작 상태를 렌더링한다. 실제 학생 계정 데이터와 Supabase migration 적용 여부는 이 캡처에 포함하지 않는다.

자동 검증:

- `flutter test --no-pub test/student_route_registry_test.dart test/wrong_answer_legacy_route_test.dart test/app_drawer_navigation_test.dart test/marketplace_page_test.dart test/student_learning_tools_route_test.dart` — 통과.
- 수정 파일 대상 `dart analyze --format machine` — 오류 없음(신규 demo file의 기존 API deprecated hint 3건).
- `python -m py_compile api/index.py`, `git diff --check` — 통과.
- 전체 `flutter analyze --no-pub`는 기존 teacher/textbook 누락·타입 오류 1,269건으로 저장소 기준선에서 실패했으며, 이번 변경 범위 밖이다.

기계 검수 원장은 `student-parity.json`으로 분리했다. 이 원장은 HTML 화면 ID 86개·라우트·데모 경계를 검사하는 분모이며, 레지스트리 개수만으로 시각·동작 일치를 완료 처리하지 않는다. 동일 상태·동일 뷰포트 캡처와 모든 action/overlay 결과가 채워질 때까지 장면 근거는 `pending`으로 유지한다.

### 2026-09-10 실행 후보 및 배포 확인

- 배포 소스 커밋: `832798b` (코드 변경 기준 `c763848`; 이후 `761f420`은 배포 ID를 맞춘 감사 문서만 변경), `origin/hotfix` push 완료.
- 변경 범위: 공통 HTML 셸·토큰·반응형 레일, 실제 사용 검색 레지스트리, 학생서비스 데모 사용자별 저장, 내신 task/version 오류 처리, 상점 서버 멱등 키 클라이언트, 소셜·그룹·그래프·일정·서버챗 API 복구, 86개 ID 기계 원장 및 함수·변수표.
- 후보 빌드: `flutter build web --release --dart-define=API_BASE_URL=https://aiflow-web-canary.vercel.app --dart-define=STUDENT_SERVICES_DEMO=true --dart-define=STUDENT_STORE_DEMO=true` 성공. `public/main.dart.js` SHA-256은 `82128F44E76E4BE197CA59C9A711C2BE1D811DCA57B8D40349E956C8763FC9E4`이며 번들에서 `localhost` 문자열을 확인하지 못했다.
- Vercel 배포: [`dpl_5G29vqh4QU4nSFf7GjaG9EMGnGfT`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/5G29vqh4QU4nSFf7GjaG9EMGnGfT), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/student/dashboard) 연결 확인.
- 라이브 확인: `/health` 200, `/main.dart.js` 200 및 로컬 SHA 일치, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active`는 401 JSON. 브라우저에서 새 alias의 학생 홈 데스크톱 렌더링(좌측 레일·메인·우측 컨텍스트)을 확인했다.
- 테스트: 집중 API 묶음 12 passed(경고 15). 집중 Flutter 테스트는 새 HTML 셸 계약을 포함해 대부분 통과했다. 전체 `flutter test --no-pub`는 기존 반응형 테스트의 구 명칭·셸 기대와 충돌한 23개 실패 뒤 장시간 정지하여 중단했으며, 이를 합격으로 처리하지 않는다. 저장소 전체 `dart analyze`에는 변경 범위 밖 teacher/textbook 기준선 오류가 남아 있다.
- 시각 근거: 기존 evidence 폴더의 이전 회차 캡처는 보존한다. 이번 배포에 대해 86개 화면·모든 장면의 동일 상태/동일 뷰포트 이미지 원장은 아직 `pending`이며, 따라서 본 기록은 **상용 준비 완료 판정이 아닌 배포 후보 확인**이다. 실제 인증 계정 데이터, DB migration 적용, 200 동시 주문·내신 충돌, 전체 접근성·반응형 캡처는 추가 검증이 필요하다.

### 2026-09-10 검색 장면 연결 후속 배포

- 코드 커밋: `88071a1` (`fix(student): open dashboard scenes from quick search`).
- 변경: 검색 결과의 `today-tasks`, `rating-detail`, `achievements`가 홈 기본 화면에 머물지 않고 `?scene=` 명명 라우트로 해당 시트를 연다. `마켓플레이스`는 HTML 표시명 `자료실`과 canary store 플래그를 구분하고, 테스트도 이 계약을 따른다.
- 번들: `public/main.dart.js` 및 alias 응답 SHA-256 `E98C185C1BCF8B9776D45A9EA29DECFF14B723363C37EE678262B2A64E91EE1B`.
- 최신 Vercel: [`dpl_8ve9avnvBict1k2AtwrCNfzsB17j`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/8ve9avnvBict1k2AtwrCNfzsB17j), production alias 연결 및 READY 상태 확인.
- 검증: `student_route_registry_test.dart`, `app_drawer_navigation_test.dart` 및 API 12개 테스트 통과. 전체 86화면 장면 이미지·실제 인증 데이터·DB 동시성 검증은 여전히 `pending`이다.

### 2026-09-10 반응형·동시성 후속 배포

- 코드 커밋: `b60b9e8` (`fix(student): close responsive overflow and exam race`).
- 변경: 아레나 PC 큐 카드 세로 overflow 제거, 모바일 드로어 마지막 메뉴 가림 방지, 라우트 세션 테스트용 비영속 토큰 주입, 내신 최초 생성 경쟁을 `INSERT ... DO NOTHING`과 행 잠금으로 방지.
- 배포: [`dpl_Bg27aE26pt3TCD3Jijyxb96dmXbo`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/Bg27aE26pt3TCD3Jijyxb96dmXbo), alias READY.
- 번들 SHA-256: `73022030A57EE39374591D35E1C2BFD24893D6F5CA679FB4F4A1034BF387418B` (로컬·alias 응답 일치).
- 검증: route registry 86개, drawer navigation 10개, API 12개, 아레나 overflow·세션 분기 테스트 통과. 전체 시각/장면 원장, 인증 계정, 실제 DB migration 적용·200 동시 요청은 아직 `pending`이다.

### 2026-09-10 학습 패널·자료실 반응형 후속 배포

- 코드 커밋: `89d1725` (`fix(student): match full-screen study panel and market controls`), 정적 번들 커밋 `84e050f`.
- 변경: 모바일 학습 메뉴를 HTML 기준 전체 화면 패널(하단 `닫기` 포함)로 전환하고, 자료실 검색·상세 필터·자료 유형 탭을 모바일 세로/PC 한 줄 구조로 분기했다. 검색·필터 부모에는 `market-mobile-search-panel`, `market-desktop-search-panel`, `market-mobile-filters`, `market-desktop-filters` 고정 키를 두었다.
- 라우팅 검증: `today-tasks`, `rating-detail`, `achievements` 대시보드 장면 딥링크가 `?scene=`를 보존하는 테스트를 추가하고 통과했다.
- 후보 빌드: Flutter Web release 빌드 성공. `public/main.dart.js` SHA-256 및 alias 응답 SHA-256은 `91B0D96A444573B662BE3ACF3D00ADD31D5EA0563D26C780FDD02B30DAA57820`이다. 번들 `localhost` 문자열은 확인되지 않았다.
- Vercel: [`dpl_6h8WybByhyWhRCrGaGBR8SwbWUVG`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/6h8WybByhyWhRCrGaGBR8SwbWUVG), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/student/dashboard) READY·연결 확인.
- 라이브 API: `/health` 200, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active`는 각각 401 JSON.
- 브라우저: 고정 in-app 브라우저 뷰포트(1280×720)에서 새 alias 홈의 A 레일·메인 코스/학습 동작·대시보드·우측 컨텍스트 셸을 6초 대기 후 캡처했다. 이 캡처는 390×844·1280×900 일대일 증거를 대체하지 않는다.
- 집중 검증: 학습 전체 화면 패널, 자료실 모바일/PC 검색 행, route registry·API 12개는 통과했다. 전체 반응형 검사는 구 명칭·구 셸을 기대하는 기존 테스트 19개가 남아 있고, 저장소 전체 analyze 기준선 오류와 함께 상용 준비 합격으로 처리하지 않는다.

### 2026-09-10 공통 셸 수치 보정 후속 배포

- 코드 커밋: `9f96e6f` (`fix(student): match desktop html shell spacing`), 정적 번들 커밋 `65debc3`.
- 변경: PC 상단바 62px/좌우 22px, 레일 84/72px·58px 메뉴·중앙 정렬·6px 간격, 컨텍스트 18/22px 패딩, 홈 데스크톱 외곽 여백 18px을 HTML 최종 cascade에 맞췄다. 모바일 값은 기존 64px 상단바·66px 하단탭을 유지했다.
- 대표 테스트: `student_density_responsive_test.dart` PC 셸, `group_detail_mobile_test.dart` 그룹 상세 PC 셸, route/drawer 테스트가 통과했다.
- 후보 빌드: `public/main.dart.js` SHA-256 및 alias 응답 SHA-256 `6959BF20C0B5B5CE24E8607A9523E0422AEDB2081B511B558B63465496366EAB`; 번들 `localhost` 없음.
- Vercel: [`dpl_B7vcZ5UKEvd4zDrSVc1yM4Rd5DoJ`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/B7vcZ5UKEvd4zDrSVc1yM4Rd5DoJ), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/student/dashboard) READY·연결 확인.
- 라이브 API: `/health` 200, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active`는 401 JSON.
- 이미지 비교: 동일한 1280×720 in-app 브라우저에서 기준 HTML과 alias를 각각 6초 대기 후 캡처했다. 레일 중앙 정렬과 상단/홈 좌측 여백은 일치하도록 보정됐고, 사용자 데이터가 빈 상태인 점은 데이터 변동으로 기록한다. 브라우저가 지정 390×844·1280×900 크기를 적용하지 않아 해당 증거는 별도로 `pending`이다.
- 합격 경계: 86개 전체 장면 이미지, 인증 데이터, 실제 migration 적용, 200 동시 요청, 전체 반응형 19개 기존 실패 및 저장소 analyze 기준선 오류는 여전히 미검증이다. 이 배포도 상용 준비 완료가 아닌 후보로 기록한다.

### 2026-09-10 typed route metadata·검색 연결 후속 배포

- 코드 커밋: `c7f7e37` (`refactor(student): type route shell metadata`), `2a318c3` (`refactor(student): route quick find through registry`).
- 변경: 86개 레지스트리 항목에 불변 `StudentDestination`, 화면 셸 종류(`standard/immersive/auth/reader/tools`), 활성 내비게이션 섹션 메타데이터를 추가했다. QUICK FIND 결과는 임의 문자열 대신 `StudentRouteSpec.destination`을 사용하며, 홈 내부 장면은 기존 `?scene=` 딥링크 계약을 보존한다.
- 검증: `test/student_route_registry_test.dart`의 86개 고유 ID·데모 플래그·셸/활성 영역·대시보드 장면 라우팅 검사가 통과했고, `dart analyze lib/app/student_route_registry.dart`, `dart analyze lib/shared/ui/ios26/ios26_chrome.dart`, `git diff --check`가 통과했다.
- 정적 번들: `fce5475` (`build(web): publish registry-backed quick find`)에 `public/main.dart.js`와 `public/flutter_bootstrap.js`를 반영했다. `public/main.dart.js` SHA-256 및 alias 응답 SHA-256은 `9F8CEA6D0226EAD62F127F365B3E6088B627E5FD30FB5C83E83AC70EEF238C8A`이며 `localhost` 문자열은 확인되지 않았다.
- Vercel: [`dpl_5hbSec8w9mTNUhEdxRprTbxQCvAX`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/5hbSec8w9mTNUhEdxRprTbxQCvAX), 고유 후보 [`aiflow-web-canary-hxc3wzhr1-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-hxc3wzhr1-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/student/dashboard) READY 연결을 확인했다.
- 라이브 경계: `/health` 200, 인증 없는 `/demo/student-store` 및 `/student/school-exam-plan/active` 401 JSON을 확인했다. 고정 in-app 브라우저 1280×720에서 기준 HTML과 alias 홈을 각각 6초 대기 후 캡처해 레일 중앙 정렬·상단/본문 여백을 재확인했다. 실제 사용자 11111 및 빈 학습 데이터는 HTML fixture와 다른 동적 데이터로 기록한다.
- 잔여: 86개 화면의 모든 장면·동작 이미지 원장, 인증된 실제 데이터, DB migration 적용, 200 동시성, 전체 접근성·반응형 검사와 저장소 기준선 analyze 오류는 아직 미검증이다. 따라서 이번 배포 역시 상용 준비 완료가 아닌 후보다.
- 후속 테스트 정정: `de1065e`에서 HTML 최종 cascade의 PC 상단바 62px에 맞춰 `marketplace_page_test.dart`의 데스크톱 기대값을 64→62로 정정했다. 모바일 64px 기대값은 유지했으며, 구 명칭·구 셸을 전제로 한 나머지 반응형 실패는 임의로 완화하지 않았다.
- 원장 무결성 검사: `student_route_registry_test.dart`가 감사 JSON의 `screenCount`·ID 집합·QUICK FIND 31개와 typed registry를 직접 대조한다. 문서만 갱신되거나 코드만 갱신되는 분리 상태를 테스트에서 검출한다.
- 도달성 검사: 같은 테스트가 86개 각 항목의 기본 route가 `appRoutes()`에 있거나 `onGenerateAppRoute`에서 오류 안내를 포함한 생성 경로를 반환하는지 확인한다. 인자 필수 화면도 조용한 홈 fallback 대신 명확한 잘못된 인수 경로를 갖는지 검증한다.

### 2026-09-10 API 중복 핸들러 정리 후속 배포

- 코드 커밋: `710b42d` (`fix(api): remove duplicated student handlers`). 일정 계약을 삽입할 때 후반에 중복으로 붙은 일일 과제·마켓·풀이 분석 핸들러 250줄을 제거하고, 단일 등록된 기존 핸들러와 새 일정·풀이 이력·소셜 핸들러를 보존했다.
- 검증: `python -m py_compile api/index.py` 및 학생 데모·소셜·그래프·서버챗 API 12개가 통과했고, 소스에서 해당 경로의 decorator가 한 번씩만 남았음을 확인했다.
- Vercel: [`dpl_E7afpXXmxc3wFw7Dw25aPcQ7bmmj`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/E7afpXXmxc3wFw7Dw25aPcQ7bmmj), 고유 URL [`aiflow-web-canary-j1nvsg7ik-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-j1nvsg7ik-cw20208021-9200s-projects.vercel.app), production alias READY 연결을 확인했다. 기존 정적 Flutter 번들 SHA-256 `9F8CEA6D0226EAD62F127F365B3E6088B627E5FD30FB5C83E83AC70EEF238C8A`도 alias 응답과 일치한다.
- 라이브 경계: `/health` 200, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active` 각각 401, 번들 `localhost` 없음.
- 소스 기준: 배포 뒤 `2862073`(원장·테스트 문서)와 이번 `710b42d`가 추가됐다. 이 둘은 정적 Flutter 런타임 코드를 바꾸지 않아 배포 번들의 실행 코드와 불일치하지 않으며, 현재 `HEAD`에는 배포된 API 정리 코드가 포함돼 있다.
- 잔여: 인증 실제 데이터·DB migration 적용·200 동시성·전체 86개 장면 이미지·접근성·반응형 남은 실패는 여전히 미검증이므로 상용 준비 완료로 판정하지 않는다.

### 2026-09-10 API 라우트 등록 회귀 검사

- `omj/tests/test_vercel_route_contract.py`를 추가해 FastAPI `APIRoute`의 `(path, HTTP method)` 조합이 한 번만 등록되는지 검사한다.
- 중복 등록은 마지막 핸들러가 앞선 계약을 가리는 위험이 있으므로 API 단위 테스트 묶음에 포함했다. 이번 실행에서 13개 테스트가 통과했다(환경 경고 15개).
- 이 검사는 라우트 등록 무결성만 확인하며, 실제 Supabase migration·인증 사용자 데이터·부하 환경의 동작을 대신하지 않는다.
- 데모 API 회귀 테스트는 플래그 off의 조회·주문 차단(404)과 동일 멱등 키의 본문 충돌(409)도 확인한다. 현재 테스트 묶음은 15개이며, 이 결과 역시 실제 운영 DB·동시 요청 검증을 대신하지 않는다.

### 2026-09-10 typed 목적지 메타데이터 후보 배포

- 코드 커밋: `1736f1c` (`refactor(student): carry typed route metadata`), `origin/hotfix` 반영.
- 변경: `StudentDestination`이 화면 ID뿐 아니라 `routeName`, `requiresAuth`, `demoOnly`를 보유하도록 확장했다. QUICK FIND는 이 typed 값에서 route를 가져오고, 홈의 세 장면만 기존 `?scene=` 딥링크로 변환한다. 레지스트리·드로어·검색 테스트를 다시 통과했다.
- 후보 빌드: `flutter build web --release` 성공. `public/main.dart.js` SHA-256 `714ACA4C98E0737A1C05D8F8D53CCBE7DDFC483A193E5820B85BE2A1C57D1AF6`, 번들 `localhost` 없음.
- Vercel: [`dpl_CN4MoD6CVWwe7ncj1KtbQP8bP6pq`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/CN4MoD6CVWwe7ncj1KtbQP8bP6pq), 고유 후보 [`aiflow-web-canary-6eec0hst4-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-6eec0hst4-cw20208021-9200s-projects.vercel.app), production alias 연결·READY 확인.
- 라이브 경계: alias `/health` 200, `/main.dart.js` 200 및 로컬 해시 일치, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active`는 각각 401 JSON.
- 이 배포는 목적지 타입 안전성과 검색 연결 회귀를 보강한 후보다. 인증된 실제 데이터, 86개 모든 장면의 동일 조건 이미지, 실제 DB migration, 200 동시성·접근성·전체 반응형 검증이 남아 있으므로 상용 준비 완료로 판정하지 않는다.

### 2026-09-10 typed 목적지 생성자 호환성 배포

- 코드 커밋: `94abcf5` (`refactor(student): preserve destination constructor compatibility`). 기존 positional `StudentDestination('id')` 호출을 보존하고 registry 생성 시 route·인증·데모 메타데이터를 채우도록 기본값을 추가했다.
- 후보 빌드: 동일 Flutter release 재빌드 성공. `public/main.dart.js` SHA-256 `714ACA4C98E0737A1C05D8F8D53CCBE7DDFC483A193E5820B85BE2A1C57D1AF6`; `flutter_bootstrap.js`도 갱신했으며 번들 `localhost` 없음.
- Vercel: [`dpl_BRVDWSmo74uYRSddt6XJW4UhuKCa`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/BRVDWSmo74uYRSddt6XJW4UhuKCa), 고유 후보 [`aiflow-web-canary-m6jef72zx-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-m6jef72zx-cw20208021-9200s-projects.vercel.app), production alias READY 연결.
- 검증: `student_route_registry_test.dart` 4개 및 Dart analyze 통과. alias `/health` 200, main bundle 로컬 해시 일치, 인증 없는 데모 상점·내신 계획 API는 각각 401 JSON.
- 이 배포도 상용 준비 완료가 아니다. 인증 사용자 데이터, 86개 장면별 동일 뷰포트 이미지, 실제 DB migration·동시성·접근성·전체 반응형 검증은 여전히 원장에 `pending`으로 남긴다.

### 2026-09-10 로그인 화면 HTML 패널 일치화 배포

- 코드 커밋: `d06e039` (`fix(auth): match html login submit state`).
- 변경: 기본 로그인 화면을 기준 HTML의 단일 패널 구조로 정리했다. PC는 좌측 28px/상단 72px에서 최대 460px 패널과 3px 검은 상단선을 사용하고, 모바일은 화면 폭 전체 패널을 사용한다. 아이디·비밀번호 라벨, 입력 높이, 보기 토글, 로그인·카카오·가입 순서를 HTML과 맞췄다.
- 유지 계약: 기존 `_submit`, Kakao 로그인, 입력 검증, 로딩 중 중복 제출 차단은 그대로 재사용했다. 다이얼로그·embedded 로그인 변형은 기존 호출 계약을 유지한다.
- 검증: `flutter test --no-pub test/student_density_responsive_test.dart --plain-name '500px 로그인은 HTML 단일 패널과 학생 폼을 유지한다'`, `... --plain-name '1280px 로그인은 HTML 좌측 460px 패널을 유지한다'`, `... --plain-name '320px 인증 화면은 사용자 상단바 없이 가로 오버플로를 만들지 않는다'`, `dart analyze lib/sessions/auth/ui/pages/login_page.dart`, `git diff --check` 통과.
- 이미지: 고정 CUA 브라우저에서 기준 HTML 로그인과 canary 로그인 패널의 좌측 배치·상단선·필드 순서를 확인했다. CUA 뷰포트는 1280×720이며 390×844/1280×900 일대일 증거로 주장하지 않는다.
- Vercel: [`dpl_DpmespAwVdcGK6xwMScGmG8en7de`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/DpmespAwVdcGK6xwMScGmG8en7de), 고유 후보 [`aiflow-web-canary-8byi05a7l-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-8byi05a7l-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/login) READY 연결.
- 정적 번들: `public/main.dart.js`와 alias 응답 SHA-256 `64CF61BE4BE4F6F999764B39C813A047984BD8DBA6DBC29CF81BA1E398563A5A`, `localhost` 문자열 없음.
- 라이브 경계: alias `/health` 200, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active` 각각 401 JSON 확인.
- 테스트 보강 커밋: `811160e` (`test(auth): cover html login submit state`). 빈 입력 비활성·두 필드 입력 후 활성화 상태를 위젯 테스트로 고정했다.
- 전체 `student_density_responsive_test.dart` 실행은 20개 중 15개가 과거 OpenDesign 영문 라벨·구 라우트·고정 샘플을 전제로 실패했다. 이 결과를 통과로 숨기지 않으며, HTML 86화면 검증기로 교체할 별도 작업으로 남긴다. 로그인 관련 4개 테스트는 모두 통과했다.
- 잔여: 이 배포는 로그인 구조 한 묶음의 후보 반영이다. 나머지 85개 화면·모든 장면/동작의 동일 조건 이미지, 인증된 실제 데이터, migration 적용, 200 동시성, 전체 접근성·반응형 및 저장소 기준선 오류는 미검증이다. 상용 준비 완료로 판정하지 않는다.

### 2026-09-10 86화면 정적·동작 감사 도구 통합

- `design_interaction_audit.py`와 실행 설명서 `design-interaction-audit.md`를 감사 폴더에 추가했다. 지정 HTML만 읽고 86개 화면, 대화상자 템플릿, `data-*` 조작 계약을 JSON으로 기록하며 `--runtime`에서는 화면별 새 브라우저 페이지에서 보이는 버튼·링크를 클릭한다.
- 정적 실행 결과: `design-inventory-2026-09-10.json`, 화면 86개, 대화상자 템플릿 43개, 원본 바이트 SHA-256 `EF8F6E40D01B099631C1940628E623A6113E1ADA68CFF3DEC0F1F89DEFCD0868`.
- 도구는 Flutter 성공·실제 API 저장·결제·권한 성공을 의미하지 않는다. 브라우저 런타임 전수 클릭 결과와 Flutter 동일 뷰포트 캡처는 별도 실행 대상으로 남긴다.

### 2026-09-10 HTML 기준 런타임 스모크 원장

- `runtime-86-first-action-390x844-2026-09-10.json`: 86개 화면을 기준으로 모바일 첫 조작을 확인했다. 실제 클릭 결과는 58개 화면, 오류 2건이며 28개 항목은 기본 장면에 보이는 조작 대상이 없어 별도 장면 진입 검수가 필요하다.
- `runtime-86-first-action-1280x900-2026-09-10.json`: 데스크톱 첫 조작은 80개 화면, 오류 3건, 조작 대상이 없는 화면 6개로 기록됐다.
- 오류는 HTML 프로토타입의 비활성 가입 완료 버튼과 오버레이가 뒤의 내비게이션을 가리는 상태다. 원장에 원문 오류를 보존하며 성공으로 바꾸지 않는다.
- 두 원장은 HTML 프로토타입의 첫 조작 근거다. Flutter와의 동일 상태·동일 뷰포트 이미지 일치, 중첩 모달·시트의 전체 동작, 실제 API 성공을 대신하지 않으며 잔여 검수로 유지한다.

### 2026-09-10 로그인·프로필 HTML 구조 후속 배포

- 프로필 코드 커밋 `b164bb6`와 정적 번들 커밋 `5a83f5c`를 반영했다. 프로필은 HTML의 76px 레일, 320px 검은 신원 패널, 우측 `프로필 관리`·`계정 관리` 패널, 모바일 세로 전환과 관리 시트를 사용한다.
- 검증: 로그인·프로필 집중 위젯 테스트와 변경 파일 `dart analyze`, `git diff --check` 통과. 감사 도구의 raw HTML SHA 고정 테스트(`33f5510`)와 86개 화면·43개 대화상자 정적 원장 검사가 통과했다.
- Vercel 후보: [`dpl_8dmYmbpdt3b8CpUFeZLB2E6ZwUXb`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/8dmYmbpdt3b8CpUFeZLB2E6ZwUXb), 고유 URL [`aiflow-web-canary-lqx9d34y8-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-lqx9d34y8-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/login) READY 연결.
- `public/main.dart.js`와 alias 응답 SHA-256은 `C04B3ED153E2395776DB71B0063DEF72A5334A605F1B2F124BFCD1D314527EED`로 일치하고, 번들에 `localhost`가 없다. `/health`는 200, 인증 없는 데모 상점·내신 계획 API는 각각 401 JSON이다.
- CUA 고정 브라우저에서 로그인 패널의 좌측 28px·상단 72px·460px 폭·3px 상단선·필드 순서를 기준 HTML과 확인했다. 고정 뷰포트가 1280×720이므로 390×844·1280×900 동일 조건 증거로 확대해석하지 않는다. 인증이 필요한 프로필 실제 데이터 캡처도 아직 보류한다.
- 이 배포는 로그인·프로필 묶음의 후보 반영이다. 나머지 화면·장면·동작의 런타임 이미지, 실제 인증 데이터, DB migration·동시성·접근성·전체 반응형 검증은 계속 `pending`이며 상용 준비 완료로 판정하지 않는다.

### 2026-09-10 가입 3단계 HTML 구조 이식 (로컬 후보)

- `lib/sessions/auth/ui/pages/signup_page.dart`의 기본 렌더 경로를 지정 HTML의 단일 가입 패널로 전환했다. 640px 데스크톱 중앙 패널, 720px 이하 전체 폭 패널, 3px 상단선, 52px 직각 입력, 과정 세그먼트, 단계별 진행선과 모바일 스크롤을 적용했다.
- 1단계는 `닉네임`·과정·학년·과목·선택 학교명 순서로 표시하며, 중학교에서는 과목 선택을 비활성화한다. 2단계는 아이디·비밀번호 보기·비밀번호 확인·선택 이메일, 3단계는 요약·동의·가입 버튼 순서를 유지한다.
- 기존 `AuthService.register` payload, 형식 검증, JWT 저장·홈 이동은 변경하지 않았다. 학교명은 HTML 기준 선택 입력으로 바꾸고, 최종 동의 기본값은 해제 상태로 맞췄다.
- 검증: `signup_stage_validation_test.dart` 4개, 회원가입 반응형 테스트 2개, `dart analyze lib/sessions/auth/ui/pages/signup_page.dart`, `git diff --check` 통과. 함수·변수표는 `function-variable-index.md`에 갱신했다.
- 이 변경은 아직 정적 번들·Vercel alias에 반영하지 않은 로컬 후보다. 가입 3단계의 HTML 기준 390×844·1280×900 이미지 비교와 실제 서버 가입 성공은 다음 빌드 게이트에서 수행한다.

### 2026-09-10 가입 3단계 HTML 구조 후보 배포

- 코드 커밋 `9f6b774`, 정적 번들 커밋 `8ed7085`를 canary에 반영했다. `public/main.dart.js` 및 alias 응답 SHA-256은 `88575F091CEF34065F2C01A68E8CFA0AF7C9B4EF3189AFAF4B0188B9160E76B5`로 일치한다.
- Vercel: [`dpl_6tfh7AuWNZTeHuvdc4t99LZJ3zS5`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/6tfh7AuWNZTeHuvdc4t99LZJ3zS5), 고유 URL [`aiflow-web-canary-ggzmn3wb1-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-ggzmn3wb1-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/signup) READY 연결.
- 라이브 경계: `/health` 200, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active`는 각각 401 JSON, 번들 `localhost` 없음. 고정 CUA 1280×720에서 HTML·canary 가입 1단계의 640px 패널·3px 상단선·필드/과정/학년/과목 순서를 시각 확인했다.
- 인증 없는 브라우저에서는 실제 회원가입 API 성공을 수행하지 않았다. 390×844·1280×900 동일 뷰포트 캡처 파일과 실제 서버 가입·중복 제출 검증은 `pending`이며, 전체 상용 준비 완료로 판정하지 않는다.

### 2026-09-10 가입 반응형 수치 보정 후속 배포

- 코드 커밋 `80bf273`의 가입 패널 보정을 정적 번들 커밋 `fc419de`로 반영했다. 모바일 제목을 26px로 고정하고, 데스크톱의 안정 스크롤바 여백을 반영했으며, 닉네임·학교 입력 안내 문구를 HTML과 맞췄다.
- 집중 검증: `flutter test --no-pub test/signup_stage_validation_test.dart test/auth_redesign_golden_test.dart` 11개 통과. Flutter release build도 성공했다.
- 정적 번들: `public/main.dart.js` SHA-256 `64719147094A43135669A884A0DE5F205021ABB83F38D3839F93D01CB20D7B34`, 번들 `localhost`·`127.0.0.1` 없음.
- Vercel: [`dpl_2UmMMaacKw8YveHjUqrY5594qqKH`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/2UmMMaacKw8YveHjUqrY5594qqKH), 고유 URL [`aiflow-web-canary-ocsi61rij-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-ocsi61rij-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/signup) READY 연결.
- 라이브 경계: alias `/health` 200, 라이브 `main.dart.js` SHA-256이 로컬 번들과 일치했다. 올바른 데모 경로 `/demo/student-store`·`/student/school-exam-plan/active`는 인증 없이 각각 401이며, `/api/app/...` 프록시 경로는 503으로 제품 서버 미연결 상태를 별도 기록한다. 배포된 정적 가입 화면의 브라우저 캡처를 후속으로 갱신한다.
- 이 배포는 가입 화면 한 묶음의 반응형 보정이다. 86개 전체 화면·장면·동작의 동일 조건 이미지, 인증된 실제 데이터, API 쓰기·DB migration·200 동시성·접근성·전체 반응형 검증은 여전히 `pending`이며 상용 준비 완료로 판정하지 않는다.

### 2026-09-10 가입 모바일 스크롤바 여백 후속 배포

- 코드·테스트·증거 커밋 `138df09`를 `origin/hotfix`에 반영했다. HTML이 390px 캡처에서 예약하는 15px 세로 스크롤바 여백을 모바일 패널에도 적용해 입력·버튼 우측 끝을 기준 이미지와 맞췄다.
- 검증: 가입 단계·로그인/가입 골든 테스트 11개 통과, 릴리스 빌드 성공. 기준 HTML과 배포 화면을 동일 Playwright Chromium 조건(`390×844`, `1280×900`, DPR 1, 5초 대기)으로 캡처했다. 증거는 `evidence/2026-09-01-deployed-vs-design/design-signup-390x844.png`, `design-signup-1280x900.png`, `deployed-signup-390x844.png`, `deployed-signup-1280x900.png`이다.
- 정적 번들: `public/main.dart.js` 및 라이브 응답 SHA-256 `2277F23A78ED18A300426D310EC4993DE613B017732C34643FDD46FA024AE237` 일치, `localhost`·`127.0.0.1` 없음.
- Vercel: [`dpl_3cAAjAHSe1Zyz3PhL6euaZGmqANs`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/3cAAjAHSe1Zyz3PhL6euaZGmqANs), 고유 URL [`aiflow-web-canary-2kytqt3jd-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-2kytqt3jd-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/signup) READY 연결. `/health` 200, 올바른 인증 없는 데모 경로 401.
- 이 배포도 가입 화면의 단일 묶음만 갱신한다. 86개 전체 화면·장면·동작 및 인증 사용자 데이터·쓰기 API·실제 DB migration·200 동시성·접근성·나머지 반응형은 `pending`이고 상용 준비 완료로 판정하지 않는다.

### 2026-09-10 홈 학습 시트·알림 패널 동작 보정 (로컬 후보)

- 홈의 작은 6개 학습 타일은 바로 라우팅하지 않고 `home-study-sheet-{resume|courses|review|problemsets|exams|textbooks}` 요약 시트를 연다. 시트의 단일 CTA만 기존 코스·오답·책가방 목적지로 이동하며, 영웅 영역의 큰 이어하기 버튼은 기존 활성 코스 직행을 유지한다.
- 홈 대시보드의 `ovr`는 레이팅 상세, `week`는 별도 주간 학습 안내 시트로 분리했다. 업적·약점·대결·튜터도 요약 시트에서 확인 후 실제 화면으로 이동한다. 실제 데이터가 없는 경우 문구만 표시하고 샘플 수치를 만들지 않는다.
- `showStudentNotifications`는 HTML 알림 패널처럼 모바일·데스크톱 모두 우측 전체 높이 390px 패널(폭이 작으면 화면 폭)을 사용한다. 검색은 기존 모바일 하단 시트/데스크톱 우측 패널을 유지한다. 닫기·배경 클릭·ESC와 알림 내부 친구 요청/그룹 초대 처리는 기존 API를 사용한다.
- 검증: `flutter test --no-pub test/mobile_home_modal_refactor_test.dart` 8개 통과, 홈 타일 시트 회귀 테스트 1개 통과, 변경 Flutter 파일 analyze는 오류 없이 통과했다(기존 style info 1건).
- 이 후보는 공통 오버레이와 홈 동작 묶음의 코드 변경만 기록한 상태이며, 정적 번들·Vercel 배포와 동일 조건 홈 390×844·1280×900 이미지 검수는 다음 빌드 게이트에서 수행한다.

### 2026-09-10 코스 탐색 목적지 보정 (로컬 후보)

- `CourseCatalogPage`의 새 코스 찾기·상단 검색 CTA를 별도 잘린 검색 시트 대신 기존 `AppRoutes.marketplace`로 연결했다. 코스 목록·필터·진도·오류/재시도 API 계약은 그대로 둔다.
- 코스 반응형 구조 회귀 테스트 `student_home_course_catalog_responsive_test.dart`의 1280·390·500 폭 케이스와 변경 파일 analyze를 실행했다. analyze는 기존 미사용 레거시 위젯·import 경고만 남기며 오류는 없다.
- 이 변경은 아직 정적 번들·Vercel에 반영하지 않은 로컬 후보다. 실제 자료실 화면의 카드·유형 매핑(subject/B1/B2)과 인증 데이터는 분류표·서버 계약 확인 전까지 `pending`으로 유지한다.

### 2026-09-10 홈·알림·코스 목적지 후보 배포

- 코드 커밋 `4756e03`(홈 학습 요약 시트·대시보드 장면·알림 우측 패널)와 `3a662f4`(코스 탐색→자료실)를 포함한 정적 번들 커밋 `51b204f`를 canary에 반영했다.
- 번들 SHA-256: `6F881F1BB5C66B59D68781814AC8EF2B6F3DB897DE069CAB4BF02F7AEE02324D`; 로컬 `public/main.dart.js`와 alias 응답 해시가 일치하고 `localhost` 문자열이 없다.
- Vercel: [`dpl_ATPcV7C3Tfd9x2FdfX3HyHjvmkjp`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/ATPcV7C3Tfd9x2FdfX3HyHjvmkjp), 고유 URL [`aiflow-web-canary-3p8j1jta1-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-3p8j1jta1-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/student/dashboard) READY. `/health` 200, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active` 각각 401.
- 코드 검증: 홈 학습 타일 시트 회귀 1개, 코스 반응형 1280·390·500 폭 회귀, 알림·학습 모달 8개가 통과했다. 변경 파일 analyze는 오류 없이 기존 미사용 레거시 경고만 남긴다.
- 이미지 경계: 가입 화면은 동일 Playwright 390×844·1280×900 기준/배포 캡처를 갱신했다. 인증이 필요한 홈 화면은 현재 독립 브라우저에 유효한 학생 세션이 없어 동일 조건 live 캡처를 수행하지 못했으며 `pending`으로 기록한다.
- 상용 준비 판정은 하지 않는다. 실제 인증 데이터·홈 86 장면·자료실 카드/분류(subject/B1/B2)·DB migration·200 동시성·접근성·전체 API 쓰기 검증이 남아 있다.

### 2026-09-10 그래프 입력·API 경로 및 알림 패널 후속 후보

- 그래프 화면은 HTML의 데스크톱 보드 여백·380px 편집 영역과 모바일 하단 입력 트레이(compact 310–350px, expanded 최대 590px, collapsed 76px)를 코드로 반영했다. 기존 JSXGraph 렌더러와 수식·좌표 데이터 계약은 유지한다.
- 수식 입력은 280ms 디바운스로 `/graphs/sample`을 자동 호출한다. 요청 revision이 최신이 아니면 응답을 폐기하고, 422 수식 오류·네트워크/서버 오류를 구분해 표시하며 마지막 정상 좌표를 지운 상태로 바꾸지 않는다.
- Vercel route 목록에 `/graphs`를 FastAPI 함수로 전달하도록 추가했다. API 응답 계약은 `{series:[{segments:[{x_values,y_values}]}]}`이며, Python route contract 2개와 그래프 위젯 테스트 10개가 통과했다.
- 알림 `sidePanel`은 모바일에서 화면 폭−56px(390px 기준 334px, 최대 360px) 우측 전체 높이 패널로 열리도록 수정했다. 홈 학습 타일 요약 시트·이번 주 학습 카드의 목적지는 최신 번들 재배포 뒤 브라우저에서 재확인한다.
- 현재 변경은 로컬 후보이며, Flutter release build·정적 번들·Vercel alias 반영과 동일 조건 이미지 캡처가 아직 남아 있다. 인증 사용자 데이터·DB migration·200 동시성·86개 전체 장면 시각 일치는 여전히 `pending`이다.

### 2026-09-10 그래프·알림·홈 선택 코스 후보 배포

- 코드 커밋 `458e13b`: 그래프 API 경로·모바일 트레이·280ms 자동 갱신·최신 요청 우선·오류 시 마지막 정상 좌표 유지, 알림 우측 패널 폭 보정.
- 후속 테스트 커밋 `a7412a6`: 6개 홈 학습 타일의 요약 시트 선행과 모바일 알림 패널의 334px×844px 기하를 회귀 테스트로 고정했다.
- 홈에서 코스를 선택하면 `student.active_course.v1` 사용자 저장소에 ID를 저장하고 다음 홈 진입 시 실제 수강 목록에서 해당 코스를 우선 복원한다. 저장소 실패 시 서버 코스 순서로만 fallback하며 샘플 코스를 만들지 않는다.
- 정적 번들 커밋 `24a9018`, `public/main.dart.js` SHA-256 `A995E4BDAEA61C3FD700A4B0312B1177064E3188B04A4E292366F86421DE98FF`; 라이브 alias 응답 해시가 동일하고 번들에 `localhost`·`127.0.0.1`이 없다.
- Vercel 배포 `dpl_4YPXkH51KZ9H5bWuEKCjREKsVYSr`, 고유 URL [`aiflow-web-canary-6fq3ex2ih-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-6fq3ex2ih-cw20208021-9200s-projects.vercel.app), production alias READY. `/health` 200, `/graphs/sample` GET 405(POST 전용 FastAPI 경로), 인증 없는 데모 상점·내신 계획은 각각 401, 유효한 그래프 POST는 200 좌표 응답이다.
- 집중 검증: 그래프 위젯 10개, 홈/알림/코스 집중 테스트 및 Vercel route contract 2개 통과, 변경 Dart analyze 오류 없음.
- 인증 세션이 없는 브라우저에서는 live 홈 타일·알림 클릭 결과와 사용자별 active-course 복원을 재현하지 못했다. 86개 전체 장면 이미지, 실제 인증 데이터·DB migration·200 동시성·접근성·상용 준비 판정은 `pending`이다.

### 2026-09-10 코스 모바일 오류 상태 보정 (다음 후보)

- `_MobileCourseCatalog`가 FutureBuilder의 `hasError`를 전달받도록 수정했다. 모바일에서도 코스 API 오류를 `코스를 불러오지 못했어요`와 `다시 시도` 행으로 표시하며, 빈 목록으로 위장하지 않는다.
- 실패 상태 회귀 테스트를 추가했고 `student_home_course_catalog_responsive_test.dart`의 해당 케이스가 통과했다. 실제 canary 인증 코스 데이터와 재시도 성공은 다음 번들에서 확인한다.

### 2026-09-10 코스 모바일 오류 상태 후보 배포

- 코드 커밋 `8910358`과 정적 번들 커밋 `e56c550`을 canary에 반영했다. 모바일 코스 API 오류는 빈 목록이 아니라 오류 안내와 `다시 시도` 동작으로 표시된다.
- 정적 번들 `public/main.dart.js`와 production alias 응답의 SHA-256은 `2980ED54060E87723CAAB31D342FEAD418808B22DA843489445C7E129F7DDF4C`로 일치한다. 번들에 `localhost`·`127.0.0.1`은 없다.
- Vercel 배포: [`dpl_6Cf9wCFX3Kn6qzzT63PyVMag1mhx`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/6Cf9wCFX3Kn6qzzT63PyVMag1mhx), 고유 URL [`aiflow-web-canary-mjodlzzgj-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-mjodlzzgj-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/student/dashboard) READY 연결.
- 라이브 경계: `/health` 200, `/graphs/sample` GET 405, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active` 각각 401이다. 인증 세션 발급은 현재 canary의 `OMJ_JWT_SECRET` 미설정으로 계속 불가능하다.
- 집중 검증: 코스 목록 반응형·오류 상태, 홈 학습 시트·알림 패널, 그래프 위젯·Vercel route contract 테스트가 통과했다. 인증된 실제 코스 데이터, 86개 전체 장면 이미지, DB migration·200 동시성·접근성·전체 API 쓰기는 여전히 `pending`이며 상용 준비 완료로 판정하지 않는다.

### 2026-09-10 학생 튜토리얼 5단계 HTML 구조 이식 (로컬 후보)

- HTML `about` 정의와 `tutorial-components.js`의 5단계(`home`, `course`, `solve`, `book`, `tutor`)를 기준으로 `StudentTutorialPage`를 추가했다. `/landing/about` 정적 라우트와 랜딩의 알아보기·모바일 더보기 진입이 같은 튜토리얼 위젯을 사용한다.
- 데스크톱은 230px 단계 레일·본문·70px 하단 액션, 모바일은 가로 단계 바·본문·64px 액션으로 분기한다. 단계 선택, 이전/다음, 강조 실습, 완료 후 홈 이동과 진행률 Semantics를 구현했다.
- `student.atlas.tutorial.v1` 아래 현재 단계·실습 완료 ID만 저장한다. 샘플 코스·문제·교재·튜터 문구는 안내 카드에만 사용하며 제품 API·사용자 데이터는 호출하지 않는다.
- 검증: `student_tutorial_page_test.dart` 모바일·데스크톱 2개 통과, 변경 파일 `dart analyze` 통과. 정적 번들·Vercel 후보 반영과 동일 조건 이미지 캡처는 다음 빌드 게이트에서 수행한다.

### 2026-09-10 코스 런타임 무인자 fallback 보정 (로컬 후보)

- `/course_runtime`에 실제 `courseId`가 없을 때 코스 목록으로 조용히 이동하던 fallback을 제거했다. 이제 `코스 ID가 필요해요` 오류 상태와 `코스 목록으로 돌아가기` CTA를 표시하고, ID가 있는 경우에만 실제 코스 조회·학습 화면으로 진입한다.
- `course_runtime_route_test.dart`와 변경 파일 `dart analyze`가 통과했다. 정적 번들·Vercel alias 반영은 튜토리얼 변경과 함께 다음 후보에서 수행한다.

### 2026-09-10 설정 계정 연동 장면 이식 (로컬 후보)

- 설정의 `다른 계정 연동` 행을 단일 안내 문구에서 HTML의 역할 선택 → 연동 방법 → ID 입력/QR 스캔/내 QR 코드 장면으로 확장했다. 각 단계의 뒤로가기·닫기·입력 오류/미연결 안내를 포함한다.
- 실제 계정 연동 API는 저장소에서 확인되지 않아 요청을 전송하지 않고 `연동 API가 준비되기 전까지 실제 요청을 보내지 않습니다.`라고 명시한다. 로컬 UI 상태만 변경하며 제품 계정·학습 데이터에는 접근하지 않는다.
- 500px 반응형 설정 테스트와 계정 연동 장면 테스트가 통과했다. 튜토리얼·코스 런타임 변경과 함께 다음 정적 번들 후보에서 배포한다.

### 2026-09-10 튜토리얼·설정·코스 런타임 후보 배포

- 소스 커밋 `40eea06`을 기준으로 release web을 다시 빌드하고 `public` 정적 산출물을 반영했다. 로컬 `public/main.dart.js`와 production alias 원시 응답 SHA-256은 `4A009A4C32DE3893B8EA40F5B981E0C37829A02022E5BE7E9FBA2787B2ABE856`로 일치하며, 번들에 `localhost`·`127.0.0.1`이 없다.
- Vercel 배포: [`dpl_DoQssteLBA2gR6GPqBdHCuN9Vxa7`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/DoQssteLBA2gR6GPqBdHCuN9Vxa7), 고유 URL [`aiflow-web-canary-daw6ii8fj-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-daw6ii8fj-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/landing/about) READY 연결.
- 라이브 경계: `/health` 200, `/graphs/sample` GET 405, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active` 각각 401이다. 현재 canary는 `OMJ_JWT_SECRET` 미설정으로 실제 학생 세션을 발급하지 못하므로 인증된 홈·설정 저장·코스 조회·알림 동작은 `pending`이다.
- 검증된 변경 범위는 HTML 튜토리얼 5단계·설정 계정 연동 장면·무인자 코스 런타임 오류 상태다. 86개 전체 장면 이미지, 실제 API 쓰기·DB migration·200 동시성·접근성·전체 반응형 검증은 남아 있어 상용 준비 완료로 판정하지 않는다.

### 2026-09-10 active-course 포함 최종 canary 후보

- 코드 기준: `origin/hotfix`의 `910f710` 및 이전 그래프·알림 변경, 최종 번들 기준 `1ae930e`.
- `flutter build web --release`를 지정 API/데모/OSM 환경값으로 재실행하고 `build/web`를 Vercel 업로드 대상 `public`에 반영했다. 최종 `public/main.dart.js` SHA-256과 alias 응답 원시 바이트 SHA-256은 `C72FDE26BE655E50005F8C42025973EF442E8224C6E6B74010B437858AE401BD`로 일치한다. `localhost`·`127.0.0.1`은 없다.
- Vercel 최종 alias 확인: `dpl_9RvQpfDaxXSpRzPxrMu4dFRwvBY4`, 고유 URL [`aiflow-web-canary-dll3b653q-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-dll3b653q-cw20208021-9200s-projects.vercel.app), production alias `https://aiflow-web-canary.vercel.app` READY. (직전 후보 `dpl_De2Ut8Lp99sj4mSEPcZMYLTfUTyR`도 READY였으나 alias가 최신 후보로 이동했다.)
- 서버 경계: `/health` 200, `/graphs/sample` GET 405·유효 POST 200, `/demo/student-store` 401, `/student/school-exam-plan/active` 401. `vercel inspect`에서 alias와 deployment ID를 재확인했다.
- 코드 검증: 그래프 위젯·홈 학습/알림·코스 반응형 집중 테스트, Vercel route contract 2개 통과. 홈 6개 타일과 알림 패널 기하(390×844 기준 334×844)를 테스트로 고정했다.
- 과거 친구 검색/요청 실패 기록은 현재 `tests/test_vercel_social.py` 재실행에서 6개 모두 통과(경고 13개)로 갱신됐다. 이는 테스트용 KV 모사 결과이며 운영 Supabase·실제 계정 쓰기 성공을 대신하지 않는다.
- 브라우저에서 인증 세션을 발급할 수 없는 현재 canary(`OMJ_JWT_SECRET` 미설정) 상태이므로 live 홈 타일·알림 실제 클릭과 사용자별 active-course 복원은 재현하지 못했다. 86개 전체 장면 이미지, 실제 인증 데이터·DB migration·200 동시성·접근성 및 상용 준비 판정은 `pending`이다.

### 2026-09-10 튜토리얼 진행률 레이아웃 최종 보정 및 canary 반영

- `StudentTutorialPage`의 HTML 하단 진행률 구조를 재검수했다. 데스크톱은 좌우 CTA 사이 중앙 240px 진행 영역, 모바일은 64px 이전 영역·1:1.4 진행/다음 그리드로 맞췄고, 막대와 `1 / 5` 표시는 가로로 배치했다.
- 코드·정적 번들 커밋 `2bcd8f5`를 `origin/hotfix`에 푸시하고, 지정 build-time 값(`API_BASE_URL`, `STUDENT_SERVICES_DEMO`, `STUDENT_STORE_DEMO`)으로 release web을 다시 빌드했다.
- `public/main.dart.js` SHA-256 및 production alias 원시 응답 SHA-256: `6E1EA3C056A27E43A709927A6F035CC24C42E2490FBABAAC6D1696955C80BB48`.
- Vercel 배포 `dpl_8XBG8uQJbQqdnUSRUtsAHVfpvK9d`, 고유 URL [`aiflow-web-canary-qc8tva4fg-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-qc8tva4fg-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/landing/about) READY. `vercel inspect`로 alias와 배포 ID를 확인했다.
- 동일 Playwright Chromium 조건(DPR 1, 5초 대기)으로 기준 HTML과 alias의 `390×844`, `1280×900` 튜토리얼을 다시 캡처했다. 증거: `evidence/2026-09-01-deployed-vs-design/design-tutorial-390x844.png`, `design-tutorial-1280x900.png`, `deployed-tutorial-390x844.png`, `deployed-tutorial-1280x900.png`.
- 캡처에서 셸·단계 레일/탭·본문 순서·카드 크기·footer 그리드가 일치함을 확인했다. 글꼴/아이콘 렌더러 차이와 데스크톱 본문 카드의 약 4px 위치 차이는 P3 시각 잔여로 기록하며, 전체 86개 화면의 합격 근거로 확대하지 않는다.
- 라이브 경계: `/health` 200, `/health/ready` 404(제품 readiness 엔드포인트 미노출), `/graphs/sample` GET 405, 인증 없는 `/demo/student-store`와 `/student/school-exam-plan/active` 각각 401. 현재 canary의 `OMJ_JWT_SECRET` 미설정으로 인증된 사용자 여정은 계속 `pending`이다.

### 2026-09-10 PC 상단 내비게이션 HTML 목적지 일치화 후보 배포

- `studentTopNavItems`를 지정 HTML `appNavigation()`의 `홈·코스·자료실·더보기` 4개 항목으로 정리했다. 자료실은 `/marketplace`, 더보기는 기존 메뉴 호스트, 보조 화면의 활성 상태는 typed enum으로 계산한다.
- 코드·테스트·정적 번들 커밋 `8356aee`를 `origin/hotfix`에 반영했다. release bundle `public/main.dart.js` SHA-256과 alias 원시 응답 SHA-256은 `452C72504C7C846D5E80B2C09965460C72B246CDBC173D6320A0CE2B07BBC97F`로 일치한다.
- Vercel 배포 `dpl_GPMBHsqHnVDLie2f2gjxcKVM7mUy`, 고유 URL [`aiflow-web-canary-jj1liavw5-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-jj1liavw5-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/student/dashboard) READY. `vercel inspect`로 alias·배포 ID를 확인했다.
- 회귀 검증: HTML 4개 목적지 상단 메뉴, 홈·코스 서로 다른 명명 라우트, 검색·알림 패널 테스트 통과. `/health` 200, `/graphs/sample` GET 405, 인증 없는 데모 상점 401.
- 이 후보는 공통 내비게이션 묶음만 반영한다. 인증된 live 사용자 데이터, 86개 전체 장면 이미지, 실제 DB migration·동시성·접근성·나머지 화면 검증은 `pending`이다.

### 2026-09-10 전체 정적 분석 재실행 경계

- `flutter analyze`를 현재 `a3618ae` 작업 트리에서 실행한 결과 `1273 issues found`로 종료됐다. 학생 변경 파일의 새 오류만으로 단정하지 않고, 교사 패키지·레거시 화면·임시 스크립트에 이미 존재하는 undefined type/URI와 경고가 함께 집계된 결과로 구분한다.
- 튜토리얼·PC 내비게이션 변경 파일은 개별 `dart analyze`에서 오류가 없고 관련 집중 테스트는 통과했다. 그러나 전체 analyze 0건 조건, 전체 학생 테스트 0건 실패, 교사·레거시 범위 정리는 완료되지 않았으므로 상용 준비 완료로 판정하지 않는다.

### 2026-09-10 PC 상단 내비게이션 HTML 목적지 일치화 (다음 후보)

- `studentTopNavItems`의 legacy 목록을 HTML `appNavigation()`과 같은 `홈·코스·자료실·더보기` 4개로 정리했다. 자료실은 기존 `/marketplace`, 더보기는 기존 메뉴 호스트를 사용하며 친구·소셜·책가방 화면에서는 해당 보조 섹션을 활성 표시한다.
- 기존 화면의 `StudentTopDestination` enum과 명명 라우트 호출은 보존했다. 새 임의 문자열 목적지나 샘플 데이터는 추가하지 않았다.
- 회귀 검증: `PC 공용 상단 메뉴는 HTML 네 목적지와 명명 라우트를 공유한다`, `PC 상단 홈과 코스는 서로 다른 경로로 이동한다` 통과. 새 정적 번들·canary 반영과 `1280×900` 캡처는 다음 빌드 게이트에서 수행한다.

### 2026-09-11 레벨 테스트 진입·결과 화면 HTML 구조 이식 (로컬 후보)

- `level-home`을 HTML의 실제 `level-test-entry` 구조로 맞췄다. 기존 OVR 영웅·추정 그래프·준비 카드의 중복 표시를 진입 화면에서 제거하고, `01` 제목·설명·문항/제한 시간/자동 저장 메타 행·시작 CTA 순서를 적용했다. 문항 수는 실제 통계 응답을 사용하고, 제한 시간은 서버 배치 계약(3600초=60분)과 일치시켰다.
- 레벨 셸은 HTML과 같이 76px 레일·우측 문맥 영역 없음으로 고정하고, 모바일에서는 720px 이하에서 패널 테두리·18px 좌우 여백·전체 폭 CTA로 전환한다. 기존 시작 API, 문제 세션, 완료 상태 조회는 변경하지 않았다.
- `level-result`는 HTML의 진단 결과·OVR/지표·신뢰도 안내·강점 태그·보완 태그·다음 학습 순서로 재구성했다. 배치 결과의 `strong_tags`·`weak_tags`를 더 이상 빈 목록으로 버리지 않고 서버 응답 그대로 막대 목록에 표시하며, 결과 CTA는 기존 `/courses` 및 문항 복귀 동작을 사용한다.
- 회귀 검증: `test/level_test_home_page_test.dart`, `test/level_test_result_page_test.dart` 전체 통과(각 1개·5개). 390·500·760·780·781·1280 폭에서 렌더 예외가 없음을 확인했다. 변경 파일 `dart analyze`는 새 오류 없이 기존 레거시 미사용 위젯 경고만 남긴다.
- 이 후보는 아직 release 번들·Vercel alias에 반영하지 않았다. 동일 조건 390×844·1280×900 이미지 캡처, 인증된 실제 결과 데이터, 86개 전체 장면, 전체 analyze/API·DB·동시성·접근성 검증은 `pending`이다.

### 2026-09-11 레벨 화면 이미지 대조 보정

- 동일 조건(DPR 1, Chromium, 390×844·1280×900)으로 기준 HTML `level-home`과 직전 canary를 좌우 캡처했다. 구조·메타 행·패널 폭·CTA 위치는 일치했지만 모바일 상단의 HTML 뒤로가기 화살표가 Flutter 햄버거로 남아 있는 차이를 확인했다.
- `StudentHtmlShell.mobileBackButton`을 추가해 화면별 모바일 상단 아이콘을 선택할 수 있게 하고, 레벨 홈·결과는 HTML처럼 뒤로가기 아이콘과 학생 홈 복귀 콜백을 사용한다. 모바일 진입 패널의 세로 테두리도 HTML의 하단 구분선만 남기는 규칙으로 맞췄다.
- 비교 이미지: `evidence/2026-09-01-deployed-vs-design/design-level-home-390x844-2026-09-11.png`, `design-level-home-1280x900-2026-09-11.png`, `deployed-level-home-390x844-2026-09-11.png`, `deployed-level-home-1280x900-2026-09-11.png`.
- 해당 소스는 다음 release 번들에 포함해야 하며, 인증 데이터·level-result 실제 제출 장면·86개 전체 이미지 검증은 계속 `pending`이다.

### 2026-09-11 코스 셸 상단 동작 이미지 보정

- 기준 HTML의 코스 화면 상단은 `뒤로가기 + 나의 코스 + 검색 + 알림`이다. `CourseCatalogPage`의 제목과 모바일 뒤로가기 아이콘을 이 순서로 맞추고, 뒤로가기는 `/student/dashboard` 명명 라우트로 복귀하게 했다.
- 코스 상단 검색은 코스 전용 마켓 이동을 사용하지 않고 공통 기능 검색 시트를 연다. `새 코스 찾기` 본문 CTA만 기존 `/marketplace`로 이동한다.
- 코스 API가 401/오류를 반환할 때는 기존 오류·재시도 상태를 유지하며 샘플 코스를 삽입하지 않는다. 관련 셸 테스트가 통과했다.

### 2026-09-11 레벨·코스 셸 후보 배포

- 소스 커밋 `23ce8fd`, 정적 번들 커밋 `8d70d97`을 현재 canary에 반영했다. `public/main.dart.js`와 alias 원시 응답 SHA-256은 `E215E64CCE5CF2C8DF51180796B9A7ACFAACEF69B15B495C119B050D96863092`로 일치한다.
- Vercel 배포 `dpl_2FF21EJp5GUM1cK2eRWaCuJnJemF`, 고유 URL [`aiflow-web-canary-pmvc09kxc-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-pmvc09kxc-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/level_test) READY. `/health` 200, `/graphs/sample` GET 405, 인증 없는 `/demo/student-store` 401을 확인했다.
- 이미지 증거: 레벨 홈과 코스 화면의 기준 HTML/배포판을 390×844·1280×900으로 캡처했다. 레벨 셸·뒤로가기·메타·CTA 구조는 일치한다. 코스는 인증 없는 라이브에서 실제 코스 목록 대신 오류·재시도를 표시하며, 이는 샘플 데이터 삽입 금지 계약에 따른 허용 데이터 상태 차이다. 이미지 파일은 `evidence/2026-09-01-deployed-vs-design/*2026-09-11.png`에 있다.
- 이 배포는 레벨·코스 셸 묶음만 검증한 후보다. 인증 세션 발급 불가(`OMJ_JWT_SECRET` 미설정), 실제 코스/레벨 결과 데이터, 86개 전체 장면, 전체 analyze/API·DB·동시성·접근성은 여전히 `pending`이다.

### 2026-09-11 책가방 화면 HTML 구조 이식 (로컬 후보)

- `BookWidget`의 실제 진입 화면을 HTML `bookbag` 구조로 교체했다. 기존 히어로·코스·네 자료 카드가 아닌 `자주 보는 교재`와 `내 자료`를 기본 순서로 표시하고, 데스크톱은 두 열·모바일은 한 열로 배치한다.
- 실제 `TextbookStore`, `ExamPaperStore`, `BookmarkStore`, `ProblemBookmarkStore` 개수와 최근 방문 저장소만 사용한다. 데이터가 없을 때 HTML의 빈 상태를 표시하며 기준 HTML의 샘플 교재를 운영 화면에 복제하지 않는다.
- 교재·시험지·북마크 행은 기존 상세 모달/리더 콜백을 사용하고, 상단 검색은 공통 기능 검색 시트로 연결했다. 셸 제목은 `책가방`, 레일은 `/bookbag` 활성, 모바일 상단은 뒤로가기 아이콘이다.
- 회귀 검증: `test/bookbag_mobile_redesign_test.dart` 8개 통과, 612·720·760·780·781·900·1280 폭에서 RenderFlex 예외가 없다. 변경 파일 analyze는 이전 대형 위젯의 미사용 경고만 남긴다.
- 아직 release 번들·Vercel alias에는 반영하지 않았다. 동일 조건 이미지 대조와 실제 인증 자료 데이터 검증은 다음 배포 게이트에서 수행한다.

### 2026-09-11 책가방 화면 HTML 구조 반영 및 canary 배포

- 소스 기준은 `8b2761e`, 정적 번들 반영 커밋은 `8e0fe16`이다. `BookWidget`은 HTML의 `자주 보는 교재`·`내 자료` 구조를 사용하고, 실제 교재·시험지·북마크 저장소의 값만 표시한다. 인증/자료 조회 실패를 샘플 데이터로 대체하지 않는다.
- release web을 지정 API·데모 플래그로 다시 빌드해 `public`에 반영했다. 로컬 `public/main.dart.js`와 production alias 원시 응답 SHA-256은 `1E25B9CBF34728A42936D1A2069838772084C36246929AA77E82342E3C5C7217`로 일치한다.
- Vercel 배포 `dpl_7bdoS4664Qk1s9pVC5QnmuaAHo7V`, 고유 URL [`aiflow-web-canary-8josv01gm-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-8josv01gm-cw20208021-9200s-projects.vercel.app), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/bookbag) READY. `/health` 200, 인증 없는 `/demo/student-store` 401을 확인했다.
- 기준 HTML과 alias를 동일 Chromium/DPR 1 조건으로 `390×844`, `1280×900` 캡처했다. 증거는 `evidence/2026-09-01-deployed-vs-design/design-bookbag-390x844-2026-09-11.png`, `design-bookbag-1280x900-2026-09-11.png`, `deployed-bookbag-390x844-2026-09-11.png`, `deployed-bookbag-1280x900-2026-09-11.png`이다. 모바일 뒤로가기·상단 검색/알림·하단 탭, 데스크톱 레일·두 열 본문·컨텍스트 영역과 빈 상태 구조를 확인했다.
- 인증 세션 발급 불가(`OMJ_JWT_SECRET` 미설정)로 실제 사용자별 최근 교재·자료 목록과 클릭 후 리더/상세 데이터는 `pending`이다. 이 배포는 책가방 묶음의 구조 후보일 뿐이며 86개 전체 장면, 전체 analyze/API·DB·동시성·접근성 검증 및 상용 준비 판정은 계속 `pending`이다.

### 2026-09-11 자료실 데스크톱·모바일 셸 및 카드 보정 canary 확인

- `MarketplacePage` 데스크톱 본문을 HTML의 검색 행·4개 유형 탭·맞춤 추천 헤더·3열 번호형 카드 구조로 정리했다. 모바일은 검색/필터·1열 결과 구조를 유지하고, 양쪽 모두 실제 마켓 API 결과·오류·빈 상태를 사용한다.
- 모바일 상단을 HTML과 같은 뒤로가기 아이콘으로 교체하고 홈 복귀 목적지를 명시했다. 검색·필터·카드 열기·구매 콜백과 기존 API 계약은 변경하지 않았다.
- 소스 커밋 `aca909f`, 정적 번들 커밋 `5278932`; 번들 및 alias 원시 응답 SHA-256은 `C70B7425DE35E42FAC1BCE646473763AE4ACA904A1E2311B9601F4353D6DAD21`로 일치한다.
- Vercel 배포 `dpl_HCF1sCFEUZVQFZpBLpMvssKv6TyC`, 고유 URL [`aiflow-web-canary-6ibv6uwxo-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-6ibv6uwxo-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/marketplace) READY. `/health` 200.
- 실제 브라우저에서 최신 alias `390×844`를 재로드해 뒤로가기·검색·필터·전체/코스/시험지/문제세트 탭·오류 재시도와 하단 자료실 활성 탭을 확인했다. 인증되지 않은 자료 조회는 “마켓 자료를 불러오지 못했어요” 상태이며 샘플 카드는 노출되지 않는다.
- `1280×900` 데스크톱 카드의 실제 자료 데이터·구매 후 열기와 인증 사용자별 목록은 세션 미발급으로 `pending`이다. 86개 전체 장면 및 전체 품질·상용 게이트도 `pending`이다.

### 2026-09-11 자료실 필터·빈 상태 최종 후보 배포

- 자료실 필터 시트를 HTML의 평면 선택 옵션과 상단 시트 구조로 보정하고, 인증 실패/빈 결과 패널의 둥근 카드 장식을 제거했다. 필터 선택·초기화·검색·유형 탭 동작은 기존 API 계약을 유지한다.
- 회귀 검증 `test/marketplace_page_test.dart`: 9개 통과. `dart analyze lib/sessions/marketplace/ui/pages/marketplace_page.dart`: 새 오류 없음.
- 번들 기준 커밋 `4e6e2d1`, `public/main.dart.js`와 alias 원시 응답 SHA-256 `710239A85B4E0D6D97B96E9E61A0D246ACC635B1142073A5257CDEFA0395F821` 일치.
- Vercel 배포 `dpl_145vy1FxfPybaawpgJL5LirkzENo`, 고유 URL [`aiflow-web-canary-ro5fsc3gv-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-ro5fsc3gv-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/marketplace) READY, `/health` 200.
- 브라우저에서 최신 alias 자료실을 재로드해 모바일 뒤로가기, 검색 행, 필터, 전체/코스/시험지/문제세트 탭, 오류 재시도, 하단 탭을 확인했다. 인증 세션·실제 카드 데이터·데스크톱 실데이터 구매 흐름은 `pending`이며 전체 86개 합격 조건도 미완료다.

### 2026-09-11 소셜 데스크톱 HTML 구조 이식 및 canary 배포

- `SoWidget` 데스크톱 화면을 HTML의 `함께 공부` 셸, 대화·친구·그룹 탭, 최근 대화 패널 순서로 정리했다. 모바일 기존 친구 검색·요청·쪽지 흐름과 실제 소셜 API/WebSocket 계약은 유지했다.
- 친구 탭에서 기존 친구 프로필·쪽지 동작으로 연결되는 실제 친구 행을 보존해 기능 회귀를 막았고, 1280px 친구 프로필 다이얼로그 테스트를 통과했다.
- 소스 커밋 `5021524`, 번들 커밋 `e819357`; `public/main.dart.js`와 alias 원시 응답 SHA-256은 `4924B2FB0E7769435B638CE3303C473347B3B8BC0BC16427E50B20CD65362A9D`로 일치한다.
- Vercel 배포 `dpl_4t9ZHzPZVyY44AN8iFvuVZkMVS8d`, 고유 URL [`aiflow-web-canary-2jsvj9knx-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-2jsvj9knx-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/social) READY, `/health` 200.
- 검증: `friend_request_mobile_test.dart`의 1280px 프로필 다이얼로그 집중 테스트 통과. 인증 세션·실제 친구/대화 데이터, 전체 86개 장면·접근성·DB 동시성 및 상용 완료 조건은 `pending`이다.

### 2026-09-11 소셜 모바일 뒤로가기 보정 배포

- 모바일 소셜 셸에도 HTML 기준 뒤로가기와 학생 홈 복귀 목적지를 적용했다. 친구 탭 검색, 요청, 수락, 프로필·쪽지 연결은 기존 동작을 유지했다.
- 소스 커밋 `15e080c`, 번들 커밋 `cfc13b0`; `public/main.dart.js`와 alias 원시 응답 SHA-256은 `3738A16582792EF91E07F4D8D40BA264408382C1C3E65FA44D97DD5D8BC74CC8`로 일치한다.
- Vercel 배포 `dpl_3QaYBUEKMvqsmTfmYzYXtF26aXZ9`, 고유 URL [`aiflow-web-canary-cb6gtjq2k-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-cb6gtjq2k-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/social) READY. `/health` 200.
- 브라우저 모바일 화면에서 `함께 공부`·뒤로가기·대화/친구/그룹 탭·최근 대화 빈 상태·하단 더보기 활성 상태를 확인했다. 인증된 친구/메시지 데이터와 전체 86개 검증은 `pending`이다.

### 2026-09-11 소셜 모바일 내비게이션 최종 반영

- 소셜 모바일 화면의 상단을 HTML 기준 뒤로가기 버튼으로 통일하고, 버튼 동작은 학생 대시보드로 복귀하도록 연결했다.
- 소스 커밋 `15e080c`, 번들 커밋 `cfc13b0` 기준으로 canary가 이미 반영되었으며, 최신 alias 원시 번들 SHA-256은 `3738A16582792EF91E07F4D8D40BA264408382C1C3E65FA44D97DD5D8BC74CC8`이다.
- 모바일 브라우저에서 `함께 공부`, 뒤로가기, 대화·친구·그룹 탭, 최근 대화 빈 상태와 하단 탭을 재확인했다. 실제 인증 데이터와 전체 화면 합격 조건은 계속 `pending`이다.

### 2026-09-11 공통 검색·알림 시트 HTML 구조 보정 배포

- 모바일 유틸리티 패널을 HTML식 하단 시트로 변경하고, 데스크톱도 중앙 하단 패널 구조로 맞췄다. 검색 입력·결과 행·알림 행의 직각 테두리와 간격을 보정했다.
- `mobile_home_modal_refactor_test.dart` 9개와 공통 파일 정적 분석을 통과했다. 기존 검색 목적지·알림 수신·친구 요청·그룹 초대·교재 열기 동작은 유지했다.
- 소스 커밋 `6afc055`, 번들 커밋 `fa0cd17`; `public/main.dart.js`와 alias 원시 응답 SHA-256은 `6E02465837B96A802F76826400A37EBB5A0E215D5940565FB17528AE20E3C783`로 일치한다.
- Vercel 배포 `dpl_uCybaVKwFjX4YNsei93Byz66RpA7`, 고유 URL [`aiflow-web-canary-r06oc3vz5-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-r06oc3vz5-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 인증 세션과 86개 전체 장면·실제 DB 무결성·동시성·접근성 검증은 여전히 `pending`이다.

### 2026-09-11 아레나 셸 HTML 구조 보정 배포

- 아레나 화면은 HTML 내부 `arena-home-side`를 사용하는 전용 구조이므로 공통 우측 문맥 영역을 제거했다. 모바일 상단은 뒤로가기와 학생 홈 복귀로 연결했다.
- 실제 아레나 큐·매칭·결과·랭킹 API 및 재연결 동작은 변경하지 않았다. `dart analyze lib/features/arena/arena_page.dart`에서 새 오류가 없음을 확인했다.
- 소스 커밋 `c97b202`, 번들 커밋 `0eb71c1`; `public/main.dart.js`와 alias 원시 응답 SHA-256은 `10DE7D45C098AF0212C73A06FBAB58C2E31B23657447A593623D75AE39D48978`로 일치한다.
- Vercel 배포 `dpl_557H8XamUdqMH2qgiSqrSz43dc6i`, 고유 URL [`aiflow-web-canary-3kb1c0a1q-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-3kb1c0a1q-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/arena) READY, `/health` 200.
- 인증된 매칭 데이터·86개 전체 장면·DB 동시성·접근성 및 상용 준비 게이트는 `pending`이다.

### 2026-09-11 아레나 셸·공통 닫기 컨트롤 최신 canary 확인

- 아레나 셸 보정과 공통 유틸리티 닫기 컨트롤의 후속 변경이 `origin/hotfix` 최신 커밋 `a8885ad`에 포함돼 있다. 기존 실제 아레나/API 계약과 모바일 시트 닫기 동작은 유지한다.
- 현재 `public/main.dart.js`와 production alias 원시 응답 SHA-256은 `762C9A6DD4C49FC533EE6A26E537058C4AF3692A490F9C217D7C3DD447886B3A`로 일치한다.
- Vercel 배포 `dpl_5rf77GUZQXaQ6k9tS2LGtuierJxy`, 고유 URL [`aiflow-web-canary-aaxlq02d1-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-aaxlq02d1-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 전체 86개 화면·인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이며 이 확인을 상용 완료로 확대하지 않는다.

### 2026-09-11 그래프 탐색기 전용 셸 보정 (로컬 검수)

- HTML의 `is-graph-tool` 규칙에 맞춰 Flutter `JsxGraphPage`에서 우측 컨텍스트 영역을 명시적으로 제거하고, 모바일 상단 동작을 뒤로가기로 지정했다.
- `dart analyze lib/sessions/graph_tools/session/jsx_graph_page.dart`는 기존 미사용 선택 인자 경고 1건만 남겼고 새 오류는 없었다.
- `test/jsx_graph_page_test.dart` 10개가 통과했다.
- 이 변경은 아직 번들 빌드·Vercel 배포·실제 이미지 재캡처 전이므로 canary 일치 또는 상용 완료 근거로 사용하지 않는다.

### 2026-09-11 그래프 탐색기 전용 셸 canary 반영

- 소스 커밋 `f6e0fd3`, 번들 커밋 `0363ab9`를 원격 `hotfix`에 반영하고 `flutter build web --release` 결과를 `public`에 게시했다.
- 로컬·canary `main.dart.js` SHA-256은 모두 `73B8F4205AAC0FBE000C18BD933219F123BFF4830149B838C1760B490F53C0F7`이다.
- Vercel 배포 `dpl_ASiKcGwVTk2aDqDYhWcfDGPoUgSU`, 고유 URL [`aiflow-web-canary-9i3kvarxx-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-9i3kvarxx-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 그래프 화면의 실제 이미지 재캡처와 86개 전체 화면·인증 데이터·DB 무결성/동시성·접근성 게이트는 여전히 `pending`이다.

### 2026-09-11 소셜·코스 보조 라우트 셸 canary 반영

- `course-runtime`, `wrong-solve`, `groups`, `group-detail`, `group-join`, `direct-chat`의 HTML `social-v2`/`workspace` 셸 설정을 Flutter 공통 셸에 맞췄다. 소셜 화면은 우측 컨텍스트 영역을 제거하고 모바일 뒤로가기를 사용한다.
- 소스 커밋 `35c1c14`, 번들 커밋 `601645d`; 관련 셸 테스트 5개와 정적 분석을 통과했다.
- 로컬·canary `main.dart.js` SHA-256은 모두 `77DAE38002612DB6A5D047AABBA5DC5624C751C94FFB81C7F0901EA95F6B8C9A`이다.
- Vercel 배포 `dpl_6ncCiJka16TjJpWfJ5agDirnR5nq`, 고유 URL [`aiflow-web-canary-fodg222u5-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-fodg222u5-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 교재 생성·편집 장면 직접 연결

- `textbook-create`와 `textbook-editor` 딥링크를 책가방 기본 화면으로 흘려보내지 않고 실제 `TextbookCreationPage`·`TextbookEditorPage`로 연결했다.
- `student_route_registry_test.dart` 통과 및 웹 릴리스 빌드 완료.
- 소스·번들 커밋 `453fe18`; 로컬·canary `main.dart.js` SHA-256 `9B5B4A736A3CD7BE3D1D3A0079DE9A13BC41DF4E9E71A722762DDF05B72C19AC` 일치.
- Vercel 배포 `dpl_2KJq56bPeJvBbE5Y9cLfownAz4Fe`, alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 실제 교재 API·인증 세션·생성 저장 결과의 live 검증은 Production 환경변수 부재로 `pending`이다.

### 2026-09-11 교재 생성 화면 인코딩 복구

- 교재 생성·편집 Dart 파일의 CP949 인코딩을 UTF-8로 변환해 배포 브라우저의 `����` 표시를 한글로 복구했다.
- 배포 브라우저에서 `교재 만들기`, `생성 방식 선택`, `AI 집필`, `직접 집필` 렌더링을 확인했다.
- 소스·번들 커밋 `75e8c70`; 로컬·canary `main.dart.js` SHA-256 `FA65C4C1AC291D10B9AEBD94A0E1DAFD24797A954A1BB961D02201E10D89EC35` 일치.
- Vercel 배포 `dpl_B4eDa62sZs7Ni1NgbW1m5t7SysGj`, alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 실제 교재 저장 API·인증 세션·DB readiness는 Production 환경변수 부재로 `pending`이다.

- 배포 브라우저에서 `#/bookbag?scene=textbook-editor`를 직접 열어 생성 화면과 분리된 `직접 집필` 편집 화면, 저장 버튼, 기본정보·대제목·소주제 입력 장면을 확인했다.

- 배포 브라우저에서 `직접 집필` 장면을 열어 교재 기본정보 입력, 대제목·소주제·내용·이미지 URL 입력, 저장·추가 동작을 확인했다. 전체 `lib/**/*.dart` UTF-8 유효성 검사도 통과했다.

### 2026-09-11 레거시 채팅 placeholder 인코딩 정리

- 번들·소스 인코딩 점검에서 CP949/UTF-8 혼용으로 깨진 레거시 `chat_placeholder_page.dart`를 UTF-8로 정리하고 잘못된 색상 import를 실제 공통 경로로 수정했다.
- 단독 `flutter analyze` 통과. 해당 placeholder는 현재 실제 학생 튜터 경로가 아니므로 제품 튜터 동작의 근거로 사용하지 않는다.
- 소스 커밋 `da054f4`; Vercel 배포 `dpl_H1uYDHEdnZNGiidTHni87zhrpGcb` READY, `/health` 200.

### 2026-09-11 그래프 매개변수 라벨 인코딩 정리

- 학생 그래프 공용 위젯의 삼각함수 매개변수 라벨을 `진폭`, `주기 계수`, `위상 이동`, `수직 이동`으로 복구했다.
- `jsx_graph_page_test.dart` 11개와 대상 파일 분석이 통과했다. 전체 Dart UTF-8 유효성 검사도 통과했다.
- 해당 위젯은 현재 GraphSelector의 공용 경로에만 포함되며, 최신 정적 번들 해시는 변경되지 않았다.

### 2026-09-11 canary 데모 플래그 빌드 반영

- Flutter release를 `STUDENT_SERVICES_DEMO=true`, `STUDENT_STORE_DEMO=true`로 재생성해 canary 데모 메뉴·직접 주소를 활성화했다. 소스 기본값(off)은 유지한다.
- 배포 브라우저에서 학원 찾기 화면의 샘플 데이터 고지, 지도·목록 전환, 필터와 OSM `Attributions`를 확인했다.
- 상점 화면에서도 샘플 데이터 고지가 표시되고 인증 데이터 미연결 시 오류 상태를 노출한다. 임의 잔액·상품을 삽입하지 않는다.
- 번들 커밋 `c0decac`; 로컬·canary `main.dart.js` SHA-256 `FA77E85B70B5C7BAD13B12EF30115546429446D9B0D5CC596E4C0FAA09CEE3D5` 일치.
- Vercel 배포 `dpl_6czWJCrCES7MY8a1qbTEzSRSJZJd`, alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 인증된 포인트 주문·실제 문의 전송·DB 멱등성은 Production 인증/DB 설정 부재로 `pending`이다.

- 최신 후보 회귀: `student_route_registry_test.dart`, `jsx_graph_page_test.dart`, `bookbag_interaction_contract_test.dart` 총 19개와 `test_vercel_student_demo_api.py` 5개가 통과했다(HTTPX deprecation warning 1건).

### 2026-09-11 canary 빌드 메타데이터 고정

- Flutter release의 `public/.last_build_id`를 커밋해 배포 산출물과 소스 상태의 재현 근거를 보강했다.
- 소스 커밋 `72bd2f3`; Vercel 배포 `dpl_BYr5PFzDzz2bt6wbCdPAEx2QpFgX` READY, `/health` 200.
- 로컬·canary `main.dart.js` SHA-256 `FA77E85B70B5C7BAD13B12EF30115546429446D9B0D5CC596E4C0FAA09CEE3D5` 일치.

### 2026-09-11 전체 정적 분석 범위 분리

- 전체 저장소 `flutter analyze --no-pub`는 962건을 보고했다. 주요 오류는 학생 앱 범위 밖의 `teacher_textbook_reader`와 `scripts` 레거시 파일에서 발생했다.
- 학생 변경 대상(`router.dart`, 학원 홈, 학습 도구, 그래프, 교재 편집·placeholder)의 집중 분석은 통과했다. 전체 analyze 0건 게이트는 teacher 레거시 정리 전까지 `pending`이다.
- `flutter analyze --no-pub lib/features lib/sessions`를 다시 실행해 teacher reader 파일을 제외한 학생 범위 오류를 집계한 결과 `STUDENT_SCOPE_ERRORS=0`이었다.

### 2026-09-11 제품 readiness 경계 확인

- canary `/health`는 `200 {"status":"ok","service":"aiflow-ocr-queue"}`를 반환했다.
- `/health/ready`는 `404`, `/api/app/health`는 `503`으로 확인돼 Vercel 큐 상태를 제품 서버 readiness로 간주하지 않았다.
- 제품 서버 `/health/ready`와 실제 DB 연결은 별도 환경에서 재검증해야 하며, 상용 준비 게이트는 `pending`이다.

- API 계약·학생 밀도 공통 헤더·학원 홈·학습 도구 화면의 `flutter analyze --no-pub` 대상 검사는 오류 없이 통과했다.

- `vercel env ls` 기준 Production 환경변수는 `STUDENT_STORE_DEMO`만 확인됐다. `OMJ_JWT_SECRET` 및 제품 DB 연결값이 없어 인증된 사용자 여정·실DB 무결성 검증은 환경 설정 전까지 `pending`이다.

### 2026-09-11 웹 번들 localhost 누출 차단

- 릴리스 번들에서 검출된 `http://localhost:8000` 기본 API 주소를 현재 canary origin으로 교체했다. `API_BASE_URL` 환경 지정값은 계속 우선한다.
- 로컬·배포 번들 금지 문자열 검사에서 `localhost`, `127.0.0.1`, 비밀키 패턴이 검출되지 않았다.
- 소스·번들 커밋 `cadd7ce`; 로컬·canary `main.dart.js` SHA-256 `DD3EA75D21A865917735776ABFC155E5241168E3360E506DEF754E0E6D09F63C` 일치.
- Vercel 배포 `dpl_CC9WUt5sLVXYe916x3AqgqCrfwAF`, alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 학원 홈 모바일 kicker canary 반영

- HTML `student-academy`의 `ACADEMY` kicker가 모바일에서 누락되지 않도록 화면별 모바일 표시 옵션을 적용했다.
- 집중 검사 `500px 학원은 HTML 정보·오늘 할 일·시간표 구조를 유지한다` 통과.
- 소스·번들 커밋 `a5b43fe`; 로컬·canary `main.dart.js` SHA-256 `22C4AFE6A0E763CFEE71ECC7545A1F1C60526F9F346FCCB29295FFF6F75A8862` 일치.
- Vercel 배포 `dpl_CDPPYKAspUAXX4uaqLXeKNTNh59Q`, alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 학습 액션 모바일 전체 높이 반영

- 500px 모바일 학습 액션 시트를 HTML의 전체 화면 패널 기준으로 변경했다. 시트와 내부 패널을 viewport 높이에 맞추고 명시적인 `닫기` 버튼을 제공한다.
- 집중 반응형 검사 `500px 학습 액션은 HTML처럼 전체 화면 패널과 하단 닫기를 사용한다` 통과.
- 소스·번들 커밋 `ac2b33f`, 번들 SHA-256 `076ADB53DEBA2CD4E2C99D9C7A792F3DCE274180954D0FB01E7062799999F8DD`.
- Vercel 배포 `dpl_DAQZyKTqGCF1Pe91Q3dbpeo99poD`, alias READY, `/health` 200, 로컬·alias 번들 SHA 일치.
- 나머지 반응형 실패와 86개 전체 이미지·API·DB·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 모바일 문제 풀이 헤더·도구 접근성 반영

- 500px 문제 풀이 화면에 HTML의 `PROBLEM SESSION`, `오늘의 문제`, `SAVED` 상태를 추가하고 펜·제출 도구에 tooltip을 부여했다.
- 모바일 객관식도 필기 도구와 제출 영역을 동일한 화면에서 노출해 HTML의 문제·작업·제출 흐름을 유지한다.
- 집중 반응형 테스트 `500px 문제 풀이는 HTML 집중 헤더와 세로 선택지를 유지한다` 통과.
- 소스·번들 커밋 `2c92607`, 번들 SHA-256 `2F18E5349B7428AA8D94437460E4BD9E1416A37B88631FFDC522D42641ADC136`.
- Vercel 배포 `dpl_CTWky2t7MH9WojVeRrhp45D1VsQt`, alias READY, `/health` 200, 로컬·alias 번들 SHA 일치.

### 2026-09-11 QUICK FIND 설명 문구 일치화

- HTML 기준 설명인 `코스, 교재, 문제, 친구를 현재 기능별 검색으로 연결합니다.`를 공통 QUICK FIND 시트에 적용했다.
- PC 상단 메뉴·검색·알림 계약 테스트의 해당 항목이 통과했다.
- 소스·번들 커밋 `cb12a08`, 번들 SHA-256 `F87AF2587A3CEBBBE7769C029172A4D3C812E499EBD477D7BEE5F593B851CDCC`.
- Vercel 배포 `dpl_4dwBfLiQn2w5nJyD5tRnhphWV82A`, alias READY, `/health` 200, 로컬·alias 번들 SHA 일치.

### 2026-09-11 아레나 모바일 보조 라벨 반영

- HTML 기준 `REAL-TIME MATCH` 보조 라벨을 모바일 아레나 헤더에 추가하고 공통 셸 제목과 중복되지 않도록 본문 제목을 제거했다.
- 500px 아레나 반응형 테스트 통과.
- 소스·번들 커밋 `9f5a7f5`, 번들 SHA-256 `5B2E12B23ABFE8BC11F0BE2FCECF790C50F781CF504A6FD79F9FDE7FDD23E714`.
- Vercel 배포 `dpl_BKubng9cnTwEZkan968aPZhznKeR`, alias READY, `/health` 200, 로컬·alias 번들 SHA 일치.

### 2026-09-11 내부 장면 딥링크 회귀 검사 보강

- `student_route_registry_test.dart`에 코스 선택·학습도구·책가방·아레나·그룹·쪽지함 내부 장면 6개를 직접 호출하는 회귀 검사를 추가했다.
- 각 링크가 `MaterialPageRoute`를 만들고 원래 query string을 유지하는지 확인한다.
- `flutter test --no-pub test/student_route_registry_test.dart`: 7개 통과.
- 이 검사는 route 생성 계약만 보장하며 실제 브라우저 장면·이미지·API·DB 무결성 검수는 대체하지 않는다.

### 2026-09-11 교재 생성·편집 진입점 재확인

- HTML 기준 `textbook-create`·`textbook-editor`의 구현 원본은 `lib/sessions/textbook/session/textbook_editor_page.dart`로 확인했다.
- 현재 Flutter analyzer에서는 해당 경로를 package/relative URI로 import할 때 `uri_does_not_exist`가 발생해 라우터 연결을 보류했다. 파일 단독 분석은 통과하지만 앱 import 가능성은 입증되지 않았다.
- 따라서 두 화면은 registry의 `/bookbag` 기본 진입으로 남겨 두었으며, 실제 생성·편집 화면 완료로 표시하지 않는다.
- 이 항목은 import 경로 원인 확인 후 실제 위젯·저장 동작·동일 뷰포트 이미지 검수까지 별도 처리한다.

### 2026-09-11 교재 개념 태그·시험 장면 연결 및 canary 반영

- `concept-tags`는 기존 `ConceptTagDialog`를, `exam-preview`·`exam-paper`·`exam-report`는 실제 `ExamPaperStore` 기반 시험 목록 모달을 여는 내부 장면으로 연결했다.
- 검색 목적지는 각각 `/bookbag?scene=...`로 보존하고, route 회귀 검사에 4개 링크를 추가했다. `student_route_registry_test.dart` 7개 통과.
- release 번들을 재생성해 커밋 `11017b4`로 `origin/hotfix`에 반영했다.
- Vercel 배포 `dpl_HJLihYgFQLq8uQAqT62s6ZFmbrFu`, 고유 URL [`aiflow-web-canary-c0k2fgxn5-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-c0k2fgxn5-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY.
- 로컬·alias `main.dart.js` SHA-256 `577849D5E13C0FD09C83C216DEA53E8BE3E75AC5FF181C4D041115A1EC714E96` 일치, `/health` 200.
- 86개 전체 화면 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트와 `textbook-create/editor` import 문제는 계속 `pending`이다.

### 2026-09-11 HTML source 경로 자동 대조

- HTML의 86개 `defineScreen` 중 `lib/`로 시작하는 source 78개를 저장소 경로와 대조했다.
- 실제로 존재하지 않는 경로는 `study-mode`의 `lib/sessions/student_dashboard/ui/pages/restriction_mode_page.dart` 1개였다. 현재 구현은 `study_mode_modal.dart`이므로, 원본 source 표기와 실제 구현 위치를 일치시키는 작업이 남아 있다.
- 외부 제안·신규 제안·다중 source 문자열은 파일 존재 검사 대상에서 제외하고 별도 기능 검수 대상으로 유지했다.

### 2026-09-11 study-mode source 호환 진입점 복구

- HTML이 지정한 `lib/sessions/student_dashboard/ui/pages/restriction_mode_page.dart`를 추가하고, 기존 `study_mode_modal.dart`의 `showStudyModeModal`·`StudypageCopyWidget`만 재노출했다.
- 화면 상태·데이터·내비게이션의 단일 구현은 기존 모달에 남겨 중복 UI를 만들지 않았다.
- 신규 파일 단독 `flutter analyze` 통과, release 번들 재생성 완료.
- 커밋 `3a870b7`, Vercel 배포 `dpl_GuzbjhzPvZ64SHhYnCEKQkKHP6R9`, alias READY, `/health` 200.
- 번들은 이전과 동일한 SHA-256 `577849D5E13C0FD09C83C216DEA53E8BE3E75AC5FF181C4D041115A1EC714E96`이며, 이 변경은 source 추적 경로 복구 목적이다.

### 2026-09-11 source 경로 대조 정정

- 호환 진입점 추가 후 동일한 대조를 재실행한 결과, `lib/` source 78개 중 누락은 0개다.
- 이전 “study-mode 1개 누락” 기록은 추가 전 상태를 보존한 역사 기록이며 현재 판정에는 적용하지 않는다.

### 2026-09-11 학생 핵심 집중 검사 재실행

- `python -m pytest -q omj/tests/test_vercel_student_demo_api.py`: 5개 통과(Starlette deprecation warning 1개).
- `flutter test --no-pub test/student_route_registry_test.dart test/bookbag_interaction_contract_test.dart`: 8개 통과.
- 이 결과는 학생 route·책가방·데모 API 계약만 확인하며, 86개 화면의 시각 일치나 전체 서버 무결성·동시성 게이트를 통과했다는 의미는 아니다.

### 2026-09-11 홈 이미지 비교의 인증 상태 경계

- 기존 `design-home-1280x900.png`는 인증된 학생 홈(현재 코스·대시보드)이고, `deployed-home-1280x900.png`는 인증되지 않은 랜딩 화면으로 확인됐다.
- 두 이미지는 동일 장면·동일 인증 상태가 아니므로 색상·레이아웃 차이의 합격 근거로 사용하지 않는다.
- 인증 세션을 확보한 뒤 동일 사용자 상태·동일 viewport로 홈 이미지를 다시 캡처해야 한다. 현재 홈 시각 검수는 `pending`이다.

### 2026-09-11 코스 선택 장면 정정

- HTML에서 `course-select`가 코스 목록 페이지가 아닌 홈 위 코스 선택 모달임을 확인했다.
- registry를 `/student/dashboard`로 정정하고 실제 `showCurriculumModal`을 연결했다.
- `flutter analyze` 및 `student_route_registry_test.dart` 통과. 소스·번들 커밋 `da9beb8`, Vercel 배포 `dpl_9Bw28FUXco4J9uhc8za1yFwLAHZ6`, alias READY, `/health` 200.
- canary에서 `#/student/dashboard?scene=course-select`의 `코스를 선택하세요` 모달과 로딩 상태를 확인했다. 전체 86개 전수 게이트는 계속 `pending`이다.

### 2026-09-11 학생 API·콘텐츠 계약 검사 재실행

- `omj` 작업 디렉터리에서 `tests/test_vercel_student_demo_api.py` 5개와 `tests/test_content_contracts.py`, `tests/test_product_rules.py` 10개가 모두 통과했다.
- 저장소 전체 `tests -k 'student or demo or store or school_exam'`는 기존 academy 레거시 테스트가 현재 PostgreSQL 저장소의 제거된 `DB_PATH` 전역을 참조해 수집 단계에서 실패했다. 이는 배포 번들 변경이 아니라 기존 테스트-저장소 계약 불일치로 분리 기록하며, 상용 준비 완료로 간주하지 않는다.

### 2026-09-11 학생 셸·라우팅 회귀 검사

- `mobile_secondary_shell_test.dart`, `student_learning_tools_route_test.dart`, `friend_request_mobile_test.dart`, `student_route_registry_test.dart`를 함께 실행해 총 23개가 통과했다.
- 그룹·도구·책가방·대결장·쪽지 장면 보강으로 기존 모바일 셸과 registry 계약이 깨지지 않음을 확인했다. 전체 86개 시각·실제 데이터·DB 동시성 게이트는 계속 `pending`이다.

### 2026-09-11 그룹 내부 장면 딥링크 canary 반영

- HTML의 `group-find`·`group-create` 내부 장면을 실제 `GroupListPage`의 검색 다이얼로그·생성 다이얼로그로 연결했다. 기존 그룹 API와 입력 검증은 그대로 사용하며 샘플 그룹 데이터는 추가하지 않았다.
- `/groups?scene=group-find`와 `/groups?scene=group-create`를 typed route 흐름과 전역 검색 목적지에 등록했다.
- `flutter analyze` 대상 3개 파일과 `student_route_registry_test.dart`(7개)가 통과했다. 기존 미사용 private 위젯 경고 3건은 오류가 아니다.
- 소스 커밋 `d8c639b`, Vercel 배포 `dpl_CKmtW9H6LTeci5oc2eHyS7qfi3Ta`, alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 배포 브라우저에서 두 딥링크를 각각 열어 `그룹 찾기`·`그룹 만들기` 모달과 배경 목록이 표시되는 것을 확인했다. 전체 86개 시각 일치·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 그룹 상세 내부 장면 딥링크 반영

- `GroupDetailPage`에 `initialScene`을 추가해 유효한 `groupId`가 있는 `/group/detail?id=...&scene=group-chat|group-share`에서 기존 대화 시트·자료 공유 시트를 바로 연다.
- 잘못된 그룹 ID는 기존 인자 오류 화면을 유지하며, 실제 그룹·멤버·자료 API와 권한 검사는 변경하지 않았다.
- 대상 파일 `flutter analyze` 통과. 소스 커밋 `9a8b573`, Vercel 배포 `dpl_9MvgFvpeoBTjwDcAGUCFUJNjUZMS`, alias READY, `/health` 200.
- 그룹 상세의 실제 데이터가 필요한 장면은 테스트 계정·groupId 없이는 시각 검증을 완료 처리하지 않는다. 전체 86개 게이트는 계속 `pending`이다.

### 2026-09-11 그룹 목록 데스크톱 구조 보정

- HTML `groups` 화면의 상단 탭(대화·친구·그룹), 제목 `그룹 n/3`, 설명, 단일 `그룹 추가` CTA 순서에 맞춰 Flutter 데스크톱 목록 구조를 조정했다.
- 기존의 과대 `그룹 스터디` 영웅 영역과 중복 검색·생성 CTA를 제거하고, 실제 그룹 추가 시트와 서버 목록은 유지했다.
- `flutter analyze` 통과. 소스·번들 커밋 `31407bf`, Vercel 배포 `dpl_9ZFs8hXwoQ1FERD7VCm1nA5ogGnu`, alias READY, `/health` 200.
- canary 데스크톱 캡처에서 HTML과 동일한 탭/제목/설명 배치를 확인했다. 사용자 그룹 데이터가 비어 있어 목록 행 자체는 동적 빈 상태로 기록한다.

### 2026-09-11 학습 도구 내부 장면 딥링크 반영

- HTML의 `notepad`·`timer`·`focus` 장면을 `/learning-tools?scene=...`로 등록하고 기존 노트·타이머·집중 모달을 초기 장면으로 연다.
- 전역 검색 목적지도 위 딥링크를 사용하며, 허브의 AI 튜터 기능과 기존 상태 전이는 유지했다.
- `flutter analyze` 및 `student_learning_tools_route_test.dart` 3개 통과. 소스·번들 커밋 `06419a3`, Vercel 배포 `dpl_4oZQBswZz7tF521crYSqGKR9BFaN`, alias READY, `/health` 200.
- canary에서 `timer` 장면의 집중 타이머 모달 표시를 확인했다. 전체 86개 전수 시각·API·DB·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 쪽지 장면 검색 연결

- 소셜 `direct-chat` 목적지를 `/social?scene=direct-chat`으로 등록하고 기존 실제 쪽지함·대화 API를 사용하도록 초기 장면 분기를 추가했다.
- `flutter analyze`와 `friend_request_mobile_test.dart` 8개가 통과했다. 소스·번들 커밋 `9ac1794`, Vercel 배포 `dpl_7kDKTFE85diNVgtb3DXJPaKe4Khu`, alias READY, `/health` 200.
- 데이터가 없는 계정에서는 최근 대화 빈 상태가 표시되며 임의 대화 샘플은 삽입하지 않는다. 전체 86개 전수 게이트는 계속 `pending`이다.

### 2026-09-11 대결장 랭킹 장면 딥링크 반영

- 경기 ID가 필요 없는 `arena-ranking`을 `/arena?scene=arena-ranking`으로 연결하고 실제 1v1 랭킹 API를 사용하도록 했다.
- 경기 준비·진행·결과 장면은 유효한 matchId 없이는 생성하지 않는 기존 안전 경계를 유지했다.
- `flutter analyze` 및 `student_route_registry_test.dart` 통과. 소스·번들 커밋 `ce471fe`, Vercel 배포 `dpl_DATh4rSxdjCiQCVfWHToe6XA6QfK`, alias READY, `/health` 200.
- 랭킹 데이터·경기 상태가 필요한 장면의 전체 시각 검증은 테스트 계정 확보 후 수행한다. 전체 86개 게이트는 계속 `pending`이다.

### 2026-09-11 책가방 내부 장면 딥링크 반영

- `book-library`·`bookbag-detail`·`book-reader`·`bookmarks`를 `/bookbag?scene=...`로 연결하고 실제 책가방 보관 교재·북마크 모달을 연다.
- 로컬·서버 저장소의 실제 목록만 표시하며 샘플 교재를 복제하지 않는다. 생성·편집·시험 결과처럼 추가 식별자가 필요한 장면은 기존 데이터 검증을 유지한다.
- 대상 파일 분석 통과. 소스·번들 커밋 `4d13084`, Vercel 배포 `dpl_CiRM2rca3T5YHVH2QTHPFXwceF1j`, alias READY, `/health` 200.
- canary에서 `book-library` 딥링크의 `보관된 교재` 모달과 검색 입력을 확인했다. 전체 86개 전수 게이트는 계속 `pending`이다.

### 2026-09-11 전역 검색 내부 장면 라우팅 활성화

- 검색 라우터가 대시보드 외 목적지에서 기본 경로로 조기 반환하던 결함을 제거했다. 이제 자료실·도구·그룹·책가방·대결장의 `?scene=` 목적지가 실제 검색 클릭에도 적용된다.
- `flutter analyze` 통과. 소스·번들 커밋 `a934337`, Vercel 배포 `dpl_3d9b5xg11LdWboUb2TScTwt5jTMX`, alias READY, `/health` 200.
- 기존 데이터·인증·데모 플래그 조건은 변경하지 않았다. 전체 86개 화면의 검색·시각·API 전수 검증은 계속 `pending`이다.

### 2026-09-11 direct-chat 초기 장면 표시 보정

- 초기 데이터 로딩과 모달 호출 경합으로 `direct-chat` 딥링크에서 쪽지함이 보이지 않던 문제를 수정했다. 장면 중복 방지와 250ms 지연 후 실제 쪽지함을 열도록 했다.
- canary `#/social?scene=direct-chat`에서 `쪽지함`과 실제 빈 상태 문구가 표시되는 것을 재확인했다.
- 소스·번들 커밋 `424a0dd`, Vercel 배포 `dpl_J8rjo7PfZKq1BDjQe3E8c3RcUPvr`, alias READY, `/health` 200. 전체 86개 전수 게이트는 계속 `pending`이다.

### 2026-09-11 최종 CSS cascade 재검증 및 레일 보정

- 이전 레일 반영 기록은 HTML 초기 CSS만 읽은 결과로, 최종 `ux-revision.css`의 `.product-nav`·`.nav-item.is-active` 덮어쓰기를 반영하지 못했다.
- 최종 기준에 맞춰 레일을 흰색 표면, 어두운 활성 캡슐, 12px 반경, 어두운 로고·푸터로 복원했다. 상단 작업 버튼의 38×38 원형 규칙은 유지했다.
- 소스·정적 번들 커밋 `0d23e8d`; Vercel 배포 `dpl_HSYHcijCEA5fMt6b9ZpkxkwbpcaX`, 고유 URL [`aiflow-web-canary-6m7265e4s-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-6m7265e4s-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY.
- alias 번들 SHA-256 `7DEF384C87060B8AF22CAB37BE5BA76273F485B98F006DE65B8AFF3735684DC2`, `/health` 200. 대상 파일 `flutter analyze` 통과.
- `student_density_responsive_test.dart`는 기존 문구·동작 기대값 등 12건 실패가 남아 있어 전체 일치 완료로 판정하지 않는다. 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 활동 기록 검색·딥링크 목적지 보정

- `activity-history`를 `/schedule`로 보내던 레지스트리 연결을 `/student/dashboard?scene=activity-history`로 수정했다.
- 홈에 이미 구현된 `showActivityHistoryDetail`을 사용해 검색 결과와 직접 주소가 HTML의 “전체 활동 보고서” 장면을 열도록 연결했다.
- 소스 커밋 `1033eb1`, 번들 커밋 `0cc70b4`; 레지스트리·홈 모달 집중 검사는 통과했다.
- Vercel 배포 `dpl_8gXKijTvH4kFhkjGQUuiBoFnAhnt`, alias READY, 번들 SHA-256 `D5E988F2BFE4A0570AC33826B4BD26E396D4D8D947C529336C7862788A54924F`, `/health` 200.
- 86개 전체 화면·장면 이미지 검수와 제품 API·DB·동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 최종 셸 액션 토큰 재보정

- 최종 `ux-revision.css`의 `.topbar-back`·`.topbar-actions button` 규칙(44×44, 12px 반경)을 재확인해 기존 38×38 원형 적용을 폐기했다.
- 컨텍스트 영역 배경을 HTML의 보조 표면(`#f3f3f5`)으로 맞췄다.
- 소스 커밋 `e95ea4f`, 번들 커밋 `5059210`; 레지스트리·홈 모달 집중 검사는 통과했다.
- Vercel 배포 `dpl_FVWUqFda6KrYVZ4asFSRS6SLipht`, alias READY, 로컬·원격 번들 SHA-256 `ED9E3C41D3BC9FFC1288DD10668C5A27B496F30C254CA3ADDB0BD2C966011D83`, `/health` 200.
- 이전의 38×38 원형 버튼 기록은 초기 CSS 기준의 중간 기록이며 최종 기준으로 대체한다. 전체 86개 검수와 API·DB·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 제한 모드 장면 연결 및 전체 번들 해시 검증

- HTML `study-mode`(제한 모드 설정)를 별도 학습 도구 허브가 아닌 `/student/dashboard?scene=study-mode`로 연결하고, 기존 `showStudyModeModal`을 호출하도록 수정했다.
- 소스·테스트 커밋 `2815a7d`, 번들 커밋 `a2a5aef`; 레지스트리와 홈 모달 집중 검사는 통과했다.
- Vercel 배포 `dpl_EQYNALA5XpS5uyB6MnRTSedHvhED`, alias READY, `/health` 200.
- 원격 번들은 Range 조각 수집으로 전체 6,662,878바이트를 검증했으며 로컬과 SHA-256 `E34BD3A2C8F423AF023BB0E2209B321D268C6897D7CDA8A33CB28B2E0B9A35FC`가 일치한다. 단일 PowerShell 응답의 5.5MiB 표시값은 응답 절단 현상으로 최종 해시 근거에서 제외했다.
- 86개 전체 화면·장면 이미지, 실제 API·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 자료실 미리보기 장면 연결

- `market-preview`를 `/marketplace?scene=market-preview`로 연결했다.
- 실제 서버 목록이 준비된 뒤 첫 자료의 기존 미리보기 시트를 열며, 목록이 비어 있으면 빈 상태를 유지해 샘플 데이터를 만들지 않는다.
- 소스·테스트 커밋 `9a3ad3e`, 번들 커밋 `cca6431`; 라우트·코스 복구 집중 검사는 통과했다.
- Vercel 배포 `dpl_6jwt6PeCHJXCdhQ55SAfrRNobrvi`, alias READY, `/health` 200. Range 전체 수집 기준 로컬·원격 번들 SHA-256 `546BCE4700B865A5B25CE2FE862995E8DF319FAA61070C1BAA05A284C24039A0` 일치.
- 86개 전체 화면·장면 이미지와 실제 API·DB·동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 친구 검색·요청 POST 계약 고정

- Vercel API 계약 테스트에 `/social/friends/search`와 `/social/friend-requests` POST 호출을 추가했다.
- 검색 응답 `200`, 요청 생성 `201`, `pending` 상태를 확인하며 실제 저장소 대신 격리된 어댑터를 사용한다.
- 테스트 파일 커밋 `9298d90`; `python -m pytest -q omj/tests/test_vercel_student_demo_api.py` 결과 5 passed.
- 이 검사는 메서드·응답 계약 회귀를 방지하며 실제 canary 계정·DB 무결성·부하 검증을 대체하지 않는다.

### 2026-09-11 소셜 화면 브라우저 비교

- HTML `social`과 canary `#/social`을 같은 1280px 화면에서 캡처해 상단 뒤로가기·3탭(대화/친구/그룹)·최근 대화 컨테이너·좌측 레일 구조를 대조했다.
- canary의 최근 대화가 비어 있는 것은 실제 계정 데이터 상태이며, HTML 샘플 대화로 덮어쓰지 않았다. 구조·배치 비교와 데이터 변동을 별도로 기록한다.
- 이 캡처는 소셜 기본 화면 근거이며 친구·그룹·대화 내부 장면과 전체 86개 게이트를 대체하지 않는다.

### 2026-09-11 소셜 친구 탭 딥링크 보정

- `social-friends`를 `/social?tab=friends`로 연결하고 데스크톱·모바일 모두 친구 탭을 초기 선택 상태로 렌더링하도록 수정했다.
- 친구 탭에서는 실제 친구 목록·친구 요청·친구 액션을 사용하며, 데이터가 없으면 빈 상태를 표시한다.
- 소스 커밋 `a1a0cc6`, 번들 커밋 `9f5cde6`; 친구 요청 모바일·레지스트리 테스트가 통과했다.
- Vercel 배포 `dpl_5eLivfCZ2S77wmL3x356YKFa93Cv`, alias READY, `/health` 200. Range 전체 수집 기준 로컬·원격 번들 SHA-256 `E30CDA5E3A225E7D5E5DA0429E22474D4631F8B5E17EB4A3C4A3BEB2F4B551D9` 일치.
- 전체 86개 화면·장면 이미지와 실제 API·DB·동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 친구 요청 장면 브라우저 재검증

- canary `#/social?scene=friend-requests`를 직접 열어 배경 블러 위 `친구 요청` 모달, 받은·보낸 건수, 빈 대기 상태, 닫기 동작을 확인했다.
- 실제 요청 데이터가 0건인 계정에서는 HTML 샘플을 복제하지 않고 `대기 중인 친구 요청이 없어요`를 표시한다.
- 이 검증은 친구 요청 장면의 초기 진입·빈 상태 근거이며, 실제 쓰기·다른 계정 소유권·동시성 검증을 대체하지 않는다.

### 2026-09-11 친구 추가·친구 요청 장면 딥링크

- `friend-add`와 `friend-requests`를 각각 `/social?scene=friend-add`, `/social?scene=friend-requests`로 연결했다.
- 기존 친구 추가·요청 모달을 초기 프레임에 열고, 실제 친구 API·빈 상태·취소 동작을 유지한다.
- 소스·테스트 커밋 `90bec94`, 번들 커밋 `26442ac`; 브라우저에서 친구 추가 모달 표시를 확인했다.
- Vercel 배포 `dpl_CHrbNReFz4NtFM5mxSwr68wDCNXa`, alias READY, `/health` 200. Range 전체 수집 기준 로컬·원격 번들 SHA-256 `834E989F01FA91CEFE4B2DF3F547DF7AA1693A578E48B362D4B726FD0E2D75DC` 일치.
- 전체 86개 화면·장면 이미지와 실제 API·DB·동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 자료실 필터 장면 브라우저 재검증

- canary 주소 `#/marketplace?scene=market-filter`를 새 브라우저 탭에서 직접 열어 자료실 본문 위에 `상세 필터` 시트가 표시되는 것을 확인했다.
- 시트의 자료 유형·과정·가격 선택, 초기화, 필터 적용 컨트롤이 실제 렌더 트리에 존재하며 우측 컨텍스트 영역과 자료실 활성 레일도 유지된다.
- 이 확인은 필터 장면 연결 증거이며, 다른 85개 화면과 실제 데이터·동시성·접근성 전체 검수를 대체하지 않는다.

### 2026-09-11 자료실 필터 장면 딥링크 연결

- `market-filter` 검색 목적지를 `/marketplace?scene=market-filter`로 구체화했다.
- `MarketplacePage`가 초기 장면을 받아 실제 필터 시트를 열며, 서버 자료가 없는 경우 샘플 미리보기를 생성하지 않는다. `market-preview`는 실제 자료 로드 후 검수 대상으로 유지한다.
- 소스·테스트 커밋 `384df86`, 번들 커밋 `3a70e47`; 라우트·코스 복구 집중 검사는 통과했다.
- Vercel 배포 `dpl_Y17cZMYLv9FWApRM4UsS8HWdr3Tb`, alias READY, `/health` 200. Range 전체 수집 기준 로컬·원격 번들 SHA-256 `85DD00A8B9B77A5E31BA681EE5E199DD233C277C662637BB198BEDE1B90B5881` 일치.
- 86개 전체 화면·장면 이미지, 실제 API·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 HTML 상단바 액션 크기 반영

- 공통 학생 상단바의 메뉴·뒤로가기·검색·알림 액션을 HTML 기준 `38×38px`로 조정했다.
- 소스·번들 커밋 `46835e2`, 번들 SHA-256 `26349AA3914166DC31358627EB4CA2AB31D92ABF0AA1A4CD8E2E59BAA8445AD9`.
- `secondary_route_shell_test.dart`와 공통 셸 정적 분석을 통과했다.
- Vercel 고유 URL [`aiflow-web-canary-paw0w38ch-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-paw0w38ch-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY. alias 번들 해시가 로컬과 일치하고 `/health`가 200이다.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 HTML 레일 브랜드·아바타 반영

- 데스크톱 레일의 브랜드 마크를 HTML 비대칭 테두리, 하단 학생 식별자를 원형 아바타로 맞췄다.
- 소스·번들 커밋 `c1bd4e1`, 번들 SHA-256 `D8B53FDA0E89DD32F239F7B43804F403C72133634BCC8AB0264E421F6AAA8DAD`.
- 공통 셸 정적 분석과 `secondary_route_shell_test.dart`, `mobile_secondary_shell_test.dart`를 통과했다.
- Vercel 고유 URL [`aiflow-web-canary-pr373reov-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-pr373reov-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY. alias 번들 해시가 로컬과 일치하고 `/health`가 200이다.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 홈 학습 동작 시트 HTML 구조 반영

- 홈 학습 동작 모바일 시트를 HTML `home-dashboard-sheet` 기준으로 흰 표면·직각 구조·최대 650px·2열 72px 동작 행으로 조정했다.
- 둥근 카드와 검은 아이콘 블록을 제거하고 HTML의 간결한 아이콘·제목·화살표 배치를 적용했다.
- `mobile_home_modal_refactor_test.dart` 전체 통과, 대상 파일 정적 분석 통과.
- 소스·번들 커밋 `3a0d007`, 번들 SHA-256 `0F70B0E21D0C79D89AE704075D6E3A21848BC6B5F451315D9CED7CEF693DBB6D`.
- Vercel 고유 URL [`aiflow-web-canary-n0jjl9iz4-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-n0jjl9iz4-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY. alias 번들 해시가 로컬과 일치하고 `/health`가 200이다.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 HTML 상단바 원형 액션 반영

- HTML `.topbar-back`, `.topbar-actions button`의 원형 버튼 규칙을 공통 `StudentHtmlTopBar`에 적용했다.
- 소스·번들 커밋 `5a8ea8c`, 번들 SHA-256 `FA781AEC8A3EF27E8710C0882795DB55D3752AF0544B3B0B71661EB1A88FD2C4`.
- `flutter analyze --no-pub lib/shared/ui/student_density/student_html_shell.dart`와 모바일 셸 검사가 통과했다.
- Vercel 고유 URL [`aiflow-web-canary-63lqr5s1l-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-63lqr5s1l-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY. alias 번들 SHA가 로컬과 일치하고 `/health`·루트가 모두 200이다.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 공통 데스크톱 레일 HTML 토큰 반영

- HTML `.product-nav` 기준으로 데스크톱 레일 배경을 `#09090b`로, 활성 항목을 표면색·비대칭 반경(10/3/10/3)으로 맞췄다. 비활성 아이콘·문자는 muted 색상을 사용한다.
- 소스 커밋 `3e434e5`, 번들 SHA-256 `67EFFBDBDA869C235E14349B2A24C3487B7C1CAF8AABF9CE4290E94A5FB3B0FB`.
- 정적 분석과 `mobile_secondary_shell_test.dart`, `student_route_registry_test.dart`가 통과했다.
- Vercel 배포 고유 URL [`aiflow-web-canary-g9d56hop0-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-g9d56hop0-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY. alias `/main.dart.js` 해시가 로컬 번들과 일치하고 `/health`·루트가 모두 200이다.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 HTML 셸·코스·책가방 검수 계약 정리

- `group-detail`, 일정·오답·레벨·대결·소셜·그룹·튜터 모바일 셸 검사를 실제 HTML 셸 변형(뒤로가기/무버튼)에 맞춰 분리했다.
- 코스의 모바일 `새 코스 찾기`는 기존 잘린 시트 기대값 대신 실제 `/marketplace` 목적지와 자료실 화면을 검증한다.
- 책가방 검사는 폐기된 `bookbag-mobile-featured`/shortcut 키 대신 현재 HTML `bookbag-html-frequent`·`bookbag-html-materials` 및 `상세보기 →` 흐름을 검증한다.
- 타이머 검사는 화면 밖 일시정지 버튼을 스크롤한 뒤 조작해 실제 시작·일시정지 전이를 확인한다.
- 관련 테스트 커밋 `892c8c2`, `d8a645e`, `4315910`, `87682fa`; 각 집중 검사는 통과했다. 이 변경은 테스트·문서만 포함하므로 정적 번들은 재빌드하지 않았다.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 프로필 모바일 셸 canary 반영

- HTML 프로필 상단의 뒤로가기 동작을 Flutter 프로필 정상·로딩·오류 상태에 공통 적용해 모바일 햄버거 노출을 제거했다.
- `mobile_live_regression_test.dart` 프로필 항목과 프로필 파일 정적 분석을 통과했다.
- 소스 커밋 `35252c2`, 번들 커밋 `013fd5c`; 로컬·canary `main.dart.js` SHA-256은 `5CDBCCB8DCE109885AE0479562BD28819BB52A392AD9B3E0C8AE8A6708D43737`로 일치한다.
- Vercel 배포 `dpl_Dcj9S9N7BgbM5ekMBmJfpKF7C175`, 고유 URL [`aiflow-web-canary-hbb0b32sj-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-hbb0b32sj-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 코스 목록 검증 계약 정리

- 기존 테스트가 HTML에 없는 데스크톱 완료 코스 필터·카드 탐색을 요구해, HTML 기준 `01 학습 중`·`02 코스 관리` 섹션과 두 관리 CTA를 검증하도록 갱신했다.
- `test/student_learning_widget_test.dart` 전체 4개가 통과했다. 실제 완료 코스 데이터·전체 86개 화면 장면 검증은 별도 원장에서 계속 `pending`이다.

### 2026-09-11 코스 상세 전용 셸 canary 반영

- HTML `detail` 레이아웃 기준으로 코스 상세의 데스크톱 컨텍스트 영역, 모바일 뒤로가기, 검색·알림 동작을 공통 셸에 연결했다.
- 소스 커밋 `5444a63`, 번들 커밋 `dae7ed7`; 대상 파일 정적 분석은 통과했다. 기존 코스 위젯 테스트의 `CourseCard` 탐색 실패는 별도 잔여로 유지한다.
- 로컬·canary `main.dart.js` SHA-256은 모두 `9B8FD68B0CFFE19011C10C4B873CBB7585F77A524835E27EE03592843683E6D5`이다.
- Vercel 배포 `dpl_7uMJodVUPkAxqWX2DCcjTRTmSdWv`, 고유 URL [`aiflow-web-canary-nf6m96tcp-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-nf6m96tcp-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.
### 2026-09-11 자료실 레거시 기대값 판정

- `student_density_responsive_test.dart`의 자료실 검사는 `COMMUNITY`를 기대하지만, 현재 HTML `marketplace` 기준 kicker는 `MATERIAL LIBRARY`다.
- 해당 실패는 제품 코드에 임의 문구를 추가해 해소하지 않고 레거시 테스트 기대값 차이로 분류했다. 자료실의 실제 검색·필터·미리보기 동작 검수는 별도 기준으로 계속 진행한다.

### 2026-09-11 학습 도구 모바일 라벨 canary 반영

- HTML `LEARNING TOOLS` 문맥 라벨이 모바일에서도 보이는 화면별 규칙을 공통 헤더 옵션으로 구현했다. 기본 모바일 헤더 동작은 유지하고 학습 도구 화면만 명시적으로 활성화했다.
- 집중 검사 `500px 학습 도구는 HTML 세 모달 카드와 타이머 실행을 유지한다` 통과.
- 소스·번들 커밋 `049165d`; 로컬·canary `main.dart.js` SHA-256 `A0126AB718F767647607607145AAD70EB766469344B210C782BF2EAB170FF4CF` 일치.
- Vercel 배포 `dpl_AC95qWvoDLZzSvmcCT3kFYnBvNk9`, alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY, `/health` 200.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 공통 알림 액션 연결 검증

- `StudentHtmlShell`과 `StudentHtmlTopBar`의 알림 액션은 빈 콜백이 아니라 `showStudentNotifications`로 연결된다.
- 알림 패널은 전체 공지·학원 공지·친구 요청을 병렬 조회하고, 로딩·오류·빈 상태·친구 요청 수락·공지 본문 열람 장면을 제공한다.
- 화면별 커스텀 동작이 필요한 친구·학생서비스 화면은 각각의 실제 요청/설정 동작을 명시적으로 주입한다.
- `secondary_route_shell_test.dart`, `mobile_secondary_shell_test.dart` 12개 통과.
- 이미지 증거는 `evidence/2026-09-11-library-search-notify/`에 보존하며, 이번 검사는 연결·상태 코드 검증으로 기록한다.
- 86개 전체 이미지·실제 인증 데이터·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 친구 검색·요청 API 계약 재확인

- 클라이언트 `ApiClient.searchFriends`는 `POST /social/friends/search`에 `query`, `limit`을 보내고, 서버 `omj/server.py`도 같은 메서드·경로·응답 키(`users`)를 제공한다.
- 친구 요청 목록·생성·수락·거절·취소 경로도 클라이언트와 서버가 `/social/friend-requests` 계열로 일치한다.
- canary의 `/api/app/social/friends/search`는 인증·제품 서버 준비 상태가 없는 현재 환경에서 `503`을 반환했다. 이는 클라이언트 404/405 수정 근거가 아니며, 서버 readiness·배포 소스를 복구한 뒤 실제 계정으로 재검증해야 한다.
- 제품 API가 준비되지 않은 상태에서 빈 목록이나 더미 친구를 표시해 성공으로 처리하지 않는다.

### 2026-09-11 무반응 CTA 정리 및 canary 후보 반영

- 가입 화면의 미연결 `학교 찾기` 버튼은 무반응 클릭을 제거하고 비활성 상태로 표시했다. 학교 자동완성 API가 연결되기 전까지 성공 동작으로 오인하지 않는다.
- 교재 리더 데스크톱 `학습 완료`는 별도 가짜 완료 API를 만들지 않고 마지막 콘텐츠로 이동해 기존 읽기 진행률 저장 흐름을 사용한다. 콘텐츠가 없으면 비활성화한다.
- 대상 파일 정적 분석 통과. 교재 상호작용 1개·가입 단계 검증 4개 통과.
- 소스·정적 번들 커밋 `8f5be7d`, `public/main.dart.js` SHA-256 `B6C5DCC64D8D3D9D26BFD3C14918D591D91C42625746AC726BEF90580EFB1C95`.
- Vercel 배포 `dpl_AUF6urSFMnHPr2ScRgF1jwA96vW6`, 고유 URL [`aiflow-web-canary-r9mykvkzt-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-r9mykvkzt-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY. 로컬·alias 번들 SHA가 일치하고 `/health`가 200이다.
- 86개 전체 이미지·실제 인증 데이터·제품 서버 readiness·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 약점 복습 기간 선택 연결

- 약점 복습의 `방금 틀린 개념`·`최근30개 틀린 개념` 버튼을 서버 `updatedAt` 기반 기간 필터로 연결했다. 날짜가 없거나 파싱되지 않으면 선택하지 않고 빈 상태를 알린다.
- 공통 720/721 반응형 회귀 검사를 HTML 기준으로 갱신했고 통과했다.
- 소스 커밋 `6f091d6`. 해당 레거시 모달은 현재 웹 번들 도달 그래프에 포함되지 않아 후보 `main.dart.js` SHA는 변하지 않았다. 제품 라우트 연결 전까지 이를 배포 반영으로 주장하지 않는다.

### 2026-09-11 약점 복습 딥링크 연결 및 canary 반영

- `weakness-review`를 `WrongAnswerListPage`의 `initialScene`으로 연결해 `/wrong_answers?scene=weakness-review` 진입 시 실제 약점 복습 모달을 연다.
- 전역 검색의 31개 목적지 중 약점 복습도 같은 딥링크를 사용한다.
- 소스·번들 커밋 `cf66150`, `public/main.dart.js` SHA-256 `06B8549AEF712282B88D6892FFB2634BDA7B5163F9E3B871ECD948A363EF8FE4`.
- Vercel 배포 `dpl_2dvYXWTH7YUSqgmT4GmrmZR2mFAS`, 고유 URL [`aiflow-web-canary-qyrzzatop-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-qyrzzatop-cw20208021-9200s-projects.vercel.app), alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app) READY. 로컬·alias 번들 SHA가 일치하고 `/health`·딥링크 HTML 응답이 200이다.
- 86개 전체 이미지·실제 인증 데이터·제품 서버 readiness·DB 무결성/동시성·접근성 게이트는 계속 `pending`이다.

### 2026-09-11 문제풀이 회귀 기대값 정렬

- 문제풀이 모바일 UI가 HTML 기준으로 필기 영역과 `PROBLEM SESSION` 헤더를 기본 표시하도록 변경된 상태에 맞춰 레거시 테스트 기대값을 갱신했다.
- 간편풀이 golden을 현재 기준 렌더링으로 재생성했으며, 라우트·책가방·코스·셸·문제풀이 집중 묶음 총 33개가 통과했다.
- 이 변경은 테스트·golden만 포함하며 제품 번들은 기존 `06B8549A…` 후보와 동일하다.

### 2026-09-11 AI 튜터 채팅 문구·헤더 HTML 일치화

- `/tools` 독립 화면의 대화 헤더를 HTML 기준 `AIFLOW TUTOR · LIVE`와 `막힌 지점부터 질문해 보세요.`로 맞췄다.
- 서버 질문 전송, 추천 질문, 개인화 상담, 429 재시도 제한은 기존 계약을 유지하고 입력 힌트만 `질문을 입력해 보세요.`로 정렬했다.
- 관련 정적 분석·튜터/학습도구/모바일 셸 테스트 14개 통과.
- 소스·번들 커밋 `0a20bd0`, `public/main.dart.js` SHA-256 `608F6EA7FE4CD2F22929C3B13AB6A77A9F426F00A6C9309DEEA24C20C089D619`.
- Vercel 배포 `dpl_Bt71TTVeYJW8cD7343oquUiQNXEF`, 고유 URL [`aiflow-web-canary-obpqc9ir3-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-obpqc9ir3-cw20208021-9200s-projects.vercel.app), alias READY. 로컬·alias 번들 SHA가 일치하고 `/health`가 200이다.

### 2026-09-11 튜터 HTML 헤더 후속 배포

- 소스·번들 커밋 `0a20bd0`, 번들 SHA-256 `608F6EA7FE4CD2F22929C3B13AB6A77A9F426F00A6C9309DEEA24C20C089D619`.
- Vercel 배포 `dpl_Bt71TTVeYJW8cD7343oquUiQNXEF`, alias READY, 로컬·alias 번들 SHA 일치, `/health` 200.

### 2026-09-11 튜터 추천 칩 HTML 일치화

- 추천 칩을 HTML의 3개 항목으로 정리했다: `오늘의 공부 계획`, `개념 쉽게 설명`, `오답 줄이는 방법`.
- 제거한 네 번째 항목의 질문 전송 경로는 기존 일반 입력으로 유지한다.
- 튜터 화면 테스트 3개 통과.
- 소스·번들 커밋 `c9985be`, 번들 SHA-256 `37C26F8C77B785682DCFA55868C1A88E062ACA546641432862DAE4CBB174931B`.
- Vercel 배포 `dpl_DYz78uaw2uGWXvivwdrdr7MJsaB7`, alias READY, 로컬·alias 번들 SHA 일치, `/health` 200.

### 2026-09-11 튜터 첫 안내 문구 HTML 일치화

- 대화 시작 메시지를 HTML 항목의 `오늘 공부한 내용이나 막힌 문제를 알려주세요.`로 맞췄다. 문제 맥락이 전달된 오버레이의 별도 안내는 유지했다.
- 정적 분석·튜터 테스트 3개 통과.
- 소스·번들 커밋 `6516f49`, 번들 SHA-256 `0B8EF7CB97369184C1E26AA0E404952792A07F126A58F80633552C64D1C08A7D`.
- Vercel 배포 `dpl_4L2w3v6WQvxBjN989e4fmg5yhQoM`, alias READY, 로컬·alias 번들 SHA 일치, `/health` 200.

### 2026-09-11 학습 도구 허브 HTML 구조 반영

- 도구 허브에 HTML의 그래프 탐색기·노트패드·집중 타이머·집중 모드 4개 항목을 표시했다.
- `최근 도구 열기`는 실제 `/graph` 라우트로 이동하고, `도구 순서 편집`은 현재 기본 순서를 확인하는 다이얼로그를 연다.
- 모바일 새 카드로 인한 화면 밖 조작은 테스트에서 `ensureVisible` 후 검증하도록 보강했다. 도구 허브 테스트 3개 통과.
- 소스·번들 커밋 `ecd278b`, 번들 SHA-256 `39F196EECF6404D1B41F7B740DCBBD5C14AE5EC649E9B1500370C762F05700E2`.
- Vercel 배포 `dpl_Gx3QgDyzNYz9ExKXdKEERRc6MzL7`, alias READY, 로컬·alias 번들 SHA 일치, `/health` 200.

### 2026-09-11 학습 도구 허브 후보 재배포 확인

- 그래프·최근 도구·순서 편집 변경을 포함한 최신 번들을 다시 빌드하고 Canary alias에 반영했다.
- 소스·번들 커밋 `ecd278b`, 번들 SHA-256 `39F196EECF6404D1B41F7B740DCBBD5C14AE5EC649E9B1500370C762F05700E2`.
- Vercel 배포 `dpl_Gx3QgDyzNYz9ExKXdKEERRc6MzL7`, alias READY, 로컬·alias 번들 SHA 일치, `/health` 200.

### 2026-09-11 86개 화면 ID 집합 재대조

- Downloads HTML `defineScreen` 추출 86개, `student-parity.json` 86개, `StudentRouteRegistry.all` 86개를 비교했다.
- HTML 대비 manifest·registry 누락 0개, 중복 0개, 추가 ID 0개.
- 이 검사는 ID·분모 정합성만 증명하며 화면 시각·동작 일치와 실제 데이터 검증의 합격 근거로 확대하지 않는다.

### 2026-09-11 스토어·더보기 활성 내비게이션 정렬

- 스토어(`/store`)에서 자료실이 잘못 활성화되던 상태를 제거하고, 현재 경로에 맞는 더보기 섹션을 활성화했다.
- `/tools`, 학생서비스 데모, 수학 내신 대비도 더보기 레일의 동일한 활성 규칙을 사용하도록 공통 셸에서 처리했다.
- 정적 분석과 라우트·모바일 셸 회귀 테스트 16개 통과.
- 소스·번들 커밋 `7d3e3cb`, `public/main.dart.js` SHA-256 `59399747E96BAECAD0465DFDA1FEBED6100A502D8E512EE0FDAB7E87E23105A4`.
- Vercel 배포 `dpl_9HMctXQiLPo9kUuteK7UTkkiLwfK`, 고유 URL [`aiflow-web-canary-rz2emen65-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-rz2emen65-cw20208021-9200s-projects.vercel.app), Canary alias READY. 로컬·alias 번들 SHA가 일치하고 `/health`가 200이다.

### 2026-09-11 런타임 API 오류와 빈 상태 분리

- `/student/runtime`의 수강 코스 조회 실패 시 `샘플 강의`를 반환하던 fallback을 제거했다.
- 실제 API 오류는 오류 장면으로 표시하고 `다시 시도`를 제공하며, 성공한 빈 응답만 빈 수강 상태로 표시한다.
- 공개되지 않은 세션 종료 API를 성공으로 가장하지 않고 `false`를 반환하도록 정리했다.
- 런타임 정적 분석 및 보조 라우트 회귀 테스트 5개 통과.
- 소스·번들 커밋 `71c5ff5`, `public/main.dart.js` SHA-256 `86452CE224B9B2C359FCB7A1695421ED6C4EAE74E162FD056BA68A949AF829CB`.
- Vercel 배포 `dpl_HcHKM7GTjB7Hb1komsAQeNci5YrA`, 고유 URL [`aiflow-web-canary-8p3q5cjvi-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-8p3q5cjvi-cw20208021-9200s-projects.vercel.app), Canary alias READY. 로컬·alias 번들 SHA가 일치하고 `/health`가 200이다.

### 2026-09-11 학원 상세 실제 빈 상태 정리

- 실제 학원 상세 모달에서 API가 빈 응답일 때 출석·시간표·제출·보고서·스냅샷·그룹 샘플을 표시하던 fallback을 제거했다.
- 미리보기 모드의 기준 샘플은 유지하고, 실제 모드에는 각 항목의 명시적 빈 상태를 표시한다.
- 정적 분석 통과.
- 소스·번들 커밋 `b7672ce`, `public/main.dart.js` SHA-256 `C6E7EC0399AC18445FF402BD272FC4AA05812804A8290C13174CECD2AB978D01`.
- Vercel 배포 `dpl_3tPYScjQVtUTCVC4mpHE5YbPK6tp`, 고유 URL [`aiflow-web-canary-29mev6yag-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-29mev6yag-cw20208021-9200s-projects.vercel.app), Canary alias READY. 로컬·alias 번들 SHA가 일치하고 `/health`가 200이다.

### 2026-09-11 학원 메타데이터 기본값 정리

- 실제 학원 응답에서 주소·담당자가 없을 때 임의의 반명·교사명을 표시하던 기본값을 제거했다.
- 누락된 값은 `소속 정보 미등록`, `담당자 미등록`으로 표시하고, 미리보기 입력 데이터는 그대로 유지한다.
- 정적 분석 통과.
- 소스·번들 커밋 `ed97284`, `public/main.dart.js` SHA-256 `FAFEA34E77683344E071570978203946BF2794D2F56874F4C456A23103EBE411`.
- Vercel 배포 `dpl_5MxiqwKpQvWFXmGtcirCFpeQ94KK`, 고유 URL [`aiflow-web-canary-h2v0ubfw5-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-h2v0ubfw5-cw20208021-9200s-projects.vercel.app), Canary alias READY. 로컬·alias 번들 SHA가 일치하고 `/health`가 200이다.

### 2026-09-11 코스 OVR 미측정값 정리

- 코스 목록의 레이팅·OVR 값이 없거나 0일 때 임의의 `18.6`을 노출하던 fallback을 `—`로 변경했다.
- 서버가 제공한 유효한 레이팅·OVR 환산값은 기존 표시 규칙을 유지한다.
- 정적 분석에서 기존 미사용 위젯 경고 8개가 확인됐으나 이번 변경과 무관하며, 코스 카탈로그 위젯 테스트 3개가 통과했다.
- 소스·번들 커밋 `cd21c00`, `public/main.dart.js` SHA-256 `4FAAE75A7ED6BD40C371DA51517A0FD127C155613BBC894F2498B2CEC1558EFA`.
- Vercel 배포 `dpl_DhvNz8NPacuG5JxEidsR48cV2Zc1`, 고유 URL [`aiflow-web-canary-4lbx5u2yc-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-4lbx5u2yc-cw20208021-9200s-projects.vercel.app), Canary alias READY. 로컬·alias 번들 SHA가 일치하고 `/health`가 200이다.

### 2026-09-11 코스 상세 미사용 위젯 검증

- `_CourseInfo` 메타 카드가 현재 라우트에서 호출되지 않는 미사용 위젯임을 확인했다.
- 해당 위젯에만 적용했던 고정 태그·메타데이터 변경은 되돌렸고, 실제 배포 UI 수정으로 집계하지 않는다.
- 강제 clean 재빌드에서도 번들 변화가 없음을 확인했으며, 이후 코스 상세 수정은 `_HtmlCourseDetailBody`와 실제 호출 경로만 대상으로 한다.

### 2026-09-11 코스 상세 조회 오류 장면

- 실제 호출되는 `CourseDetailPage`에서 최신 상세 API 실패를 조용히 무시하던 경로를 제거했다.
- 최초 요약 코스는 유지하면서 상단 오류 배너와 `다시 시도`를 제공하고, 성공한 상세 응답이 도착하면 오류를 지운다.
- 코스 상세·보조 라우트 분석 및 회귀 테스트 7개 통과.
- 소스·번들 커밋 `5f4091d`, `public/main.dart.js` SHA-256 `C283ED4CB4E38223C0AD6D1E1B4BF2186125106D19699821F3199811F8B3FB55`.
- Vercel 배포 `dpl_5Acb5NZhJhk5YHBfBV5tyZ3V2fQq`, 고유 URL [`aiflow-web-canary-azz959jwe-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-azz959jwe-cw20208021-9200s-projects.vercel.app), Canary alias READY. 로컬·alias 번들 SHA가 일치하고 `/health`가 200이다.

### 2026-09-11 소셜 HTML 영역 실제 데이터 조회

- 기본 HTML 소셜 경로에서도 친구 OVR 랭킹·내 레이팅·그룹을 실제 API에서 조회하도록 연결했다.
- 구형 `USE_LEGACY_SOCIAL` 플래그가 꺼져도 해당 영역을 비워 두지 않으며, API 실패는 기존 빈 상태·오류 로그 정책으로 처리한다.
- 친구·요청 모바일 테스트와 보조 라우트 테스트를 실행했고 전체 12개가 통과했다.
- 소스·번들 커밋 `3b52fe6`, `public/main.dart.js` SHA-256 `FC292984D2CA837722862CC23D4DED2857B1655F7268B58CE4D7FDC45A0A6CF0`.
- Vercel 배포 `dpl_5hPWYmdX2wo9eBiuz1RJVcbLiNPd`, 고유 URL [`aiflow-web-canary-2478odffr-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-2478odffr-cw20208021-9200s-projects.vercel.app), Canary alias READY. 로컬·alias 번들 SHA가 일치하고 `/health`가 200이다.

### 2026-09-11 소셜 랭킹·내 레이팅 독립 오류 처리

- 친구 랭킹 endpoint가 실패해도 내 레이팅 조회까지 중단되지 않도록 요청과 오류 경계를 분리했다.
- 지원되는 실제 응답은 표시하고, 지원되지 않는 랭킹·레이팅만 빈 상태로 남긴다. 테스트 환경의 404 로그는 실패 증거로 보존했다.
- 소스·번들 커밋 `2b0cf1b`, `public/main.dart.js` SHA-256 `2E10FD954F88DDDD3354E178BDC2CDC0274356A7E1474233A3B03A3038B4B5F1`.
- Vercel 배포 `dpl_8hxqSvFjA7UmpZ1kBP7mdTWve9MT`, 고유 URL [`aiflow-web-canary-st01rpl2v-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-st01rpl2v-cw20208021-9200s-projects.vercel.app), Canary alias READY. 로컬·alias 번들 SHA가 일치하고 `/health`가 200이다.

### 2026-09-11 교재 목록 오류와 샘플 데이터 분리

- 교재 API·로컬 저장소가 모두 실패한 경우 내장 샘플 교재를 상용 목록처럼 반환하던 fallback을 제거했다.
- 실제 목록이 없으면 빈 상태를, 조회 실패면 별도 오류 장면을 표시하도록 `TextbookStore`와 교재 목록 로더를 수정했다.
- `flutter analyze` 대상 파일 통과, 전체 Flutter 테스트 1건 포함 전체 테스트 통과.
- 소스·번들 커밋 `dfdea94`, 로컬 `public/main.dart.js` SHA-256 `28960740D014B0AEA0C4413472BDEA1B3E084D1DDFA5BB981D1C2830D7C248ED`.
- Vercel 배포 `dpl_7cWnyKZ6Z63XZKHDJ5afZ5Ebar3d` 고유 URL [`aiflow-web-canary-iky7bk9fq-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-iky7bk9fq-cw20208021-9200s-projects.vercel.app) 배포와 alias는 READY였으나, 익명 요청이 Vercel 인증 HTML로 응답되어 원격 번들 해시와 `/health` 제품 응답은 검증하지 못했다.

### 2026-09-11 교재 보관함 오류 재시도

- 교재 보관함·목록 로더를 Stateful 로더로 바꾸고 API 실패 장면에 `다시 시도`를 연결했다.
- 필터·보관함 조건이 바뀌면 새 요청을 만들며, 강제 재시도는 캐시를 갱신한다.
- `flutter analyze`와 책가방 상호작용 테스트 9건 통과.
- 소스·번들 커밋 `95f794f`, 로컬·alias `public/main.dart.js` SHA-256 `934EDB30C0D78DABF160655F331CC6DD4FE302B041F230BD1EC7A76E90BD2056` 일치.
- Vercel 고유 URL [`aiflow-web-canary-3nq9q6rts-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-3nq9q6rts-cw20208021-9200s-projects.vercel.app), Canary alias READY. `/health` 200 (`aiflow-ocr-queue`), `/health/ready` 404.

### 2026-09-11 소셜 API 계약 재검증

- `omj` 작업 디렉터리에서 친구 검색·요청·랭킹·레이팅·그룹 예외 격리 테스트를 올바른 모듈 경로로 다시 실행했다.
- `tests/test_social_exception_isolation.py`, `tests/test_rating_access.py`, `tests/test_vercel_student_demo_api.py` 합계 11건 통과.
- 서버 라우트(`/social/friends/search`, `/social/friend-requests`, `/social/friends/rankings`, `/rating/user`, `/social/study-groups/mine`)는 소스와 계약 테스트에 존재한다. canary에서 관측한 404는 서버 소스 부재로 확정하지 않고 배포·인증 환경 차이로 남긴다.

### 2026-09-11 공통 HTML 셸 토큰·배치 보정

- 실제 공통 셸의 상단 액션을 HTML 기준 38px 원형·기본 표면으로 맞추고, 레일 활성 항목을 기본 표면/본문색 조합으로 맞췄다.
- 390px 모바일 셸 및 보조 라우트 테스트를 통과했다.
- 소스·번들 커밋 `a8a3afe`, 로컬·alias `public/main.dart.js` SHA-256 `42CE0E5EB7CF3B62F5ECCB50C4309A25AF93145F35C5299CFE5B091FEDE97A28` 일치.
- Vercel 고유 URL [`aiflow-web-canary-ep1fe6in3-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-ep1fe6in3-cw20208021-9200s-projects.vercel.app), Canary alias READY. `/health` 200 (`aiflow-ocr-queue`).

### 2026-09-11 공통 셸 레일·상단바 최종 수치

- 데스크톱 기본 레일을 HTML `76px`, 상단바를 `64px`로 맞췄다. 태블릿 `72px`와 모바일 하단 탭 분기는 유지한다.
- 프로필 76px 레일, 모바일 셸, 보조 라우트 테스트 통과.
- 소스·번들 커밋 `3bfc840`, 로컬·alias `public/main.dart.js` SHA-256 `46C5045220684D9A96229D6D4E3E79CBC26B52114164AA9D76A7F2A83D8D26B9` 일치.
- Vercel 고유 URL [`aiflow-web-canary-b4qkquv2c-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-b4qkquv2c-cw20208021-9200s-projects.vercel.app), Canary alias READY. `/health` 200 (`aiflow-ocr-queue`).

### 2026-09-11 공통 셸 레일 배경·컨텍스트 폭 보정

- HTML `product-nav` 기준으로 데스크톱 레일 전체를 어두운 표면으로 맞추고, 레일 상·하단 브랜드 블록은 기본 표면/본문색으로 조정했다.
- 우측 컨텍스트 영역을 HTML 기준 `236px`로 변경했다. 태블릿·모바일 셸 분기는 유지했다.
- `flutter analyze lib/shared/ui/student_density/student_html_shell.dart` 통과.
- 프로필 1280px 셸 테스트와 `secondary_route_shell_test.dart` 전체 통과.
- 소스·번들 커밋 `ffd11f7`, 로컬·alias `public/main.dart.js` SHA-256 `5B554BE127975C7FAFFD4D87448381EAC713903D7F3186AB7F8528E70BEA2888` 일치.
- Vercel 배포 고유 URL [`aiflow-web-canary-rn3ky7kcb-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-rn3ky7kcb-cw20208021-9200s-projects.vercel.app) 및 Canary alias READY. `/health` 200 (`aiflow-ocr-queue`), `/health/ready` 404.

### 2026-09-11 그래프 도구 HTML 전용 셸 수치 보정

- HTML `is-graph-tool` 기준의 84px 레일, 380px 편집 패널, 12px 본문 여백·패널 간격을 실제 `JsxGraphPage` 호출 경로에 적용했다.
- 그래프 입력·검증·자동 반영·모바일 트레이 동작은 기존 구현과 API 계약을 유지했다.
- `flutter analyze lib/sessions/graph_tools/session/jsx_graph_page.dart` 및 `test/jsx_graph_page_test.dart` 11건 통과.
- 소스·번들 커밋 `9f3b96e`, 로컬·alias `public/main.dart.js` SHA-256 `82FE944E3F2DC1549297998B556A2FCE1AB88A77EDDAA9372D2803624788D8D6` 일치.
- Vercel 배포 `dpl_By5568UoeRYbg9RB4zfYjBRA6X8w`, 고유 URL [`aiflow-web-canary-i21kevq4w-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-i21kevq4w-cw20208021-9200s-projects.vercel.app), Canary alias READY. `/health` 200 (`aiflow-ocr-queue`), `/health/ready` 404.

### 2026-09-11 집중 모드 독립 딥링크

- 도구 허브 장면(`/learning-tools?scene=focus`)은 유지하면서 `/focus` 직접 경로를 `FocusModePage`에 연결했다.
- 실제 Canary 새 탭에서 `/focus`가 집중 모드 설정 화면으로 렌더링되는 것을 확인했다.
- `flutter analyze lib/app/router.dart`, 학생 route registry·보조 셸 테스트 통과.
- 소스·번들 커밋 `cdd7287`, 로컬·alias `public/main.dart.js` SHA-256 `0ABFFA546AA164F7BB41A81E52DF41A4756428CCB6372B3EEDBE9CFC105A75CB` 일치.
- Vercel 배포 `dpl_AVHzWGMzKCbitkb8u5zWb9RAz2CX`, 고유 URL [`aiflow-web-canary-jeu0s07ca-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-jeu0s07ca-cw20208021-9200s-projects.vercel.app), Canary alias READY. `/health` 200 (`aiflow-ocr-queue`), `/health/ready` 404.

### 2026-09-11 교재 작성 화면 HTML 셸 이식

- `textbook-create`와 `textbook-editor`를 독립 Material Scaffold에서 공통 학생 HTML 셸로 전환했다.
- 모바일 상단바·하단 탭, 데스크톱 레일·컨텍스트, 본문 최대폭을 적용하고 저장·실패 메시지·실제 교재 저장 계약은 유지했다.
- `flutter analyze lib/features/textbook/session/textbook_editor_page.dart` 및 교재 딥링크 테스트 통과.
- 소스·번들 커밋 `d23ad65`, 로컬·alias `public/main.dart.js` SHA-256 `87D438359AC3FF5C340AE0400889D850A4A287AE285780A3D8CB76B44726E09F` 일치.
- Vercel 배포 `dpl_3d9VXuvpR9Wa6qA4Vj4wZcUmHvnZ`, 고유 URL [`aiflow-web-canary-2j73s3ka7-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-2j73s3ka7-cw20208021-9200s-projects.vercel.app), Canary alias READY. `/health` 200 (`aiflow-ocr-queue`), `/health/ready` 404.

### 2026-09-11 교재 작성 화면 컨텍스트 패널 보정

- HTML `textbook-create`의 우측 컨텍스트 패널이 누락된 것을 실제 렌더 비교로 확인하고 `textbook-create`·`textbook-editor` 모두 `236px` 컨텍스트 영역을 사용하도록 보정했다.
- 새 Canary 탭에서 교재 작성 화면의 `NEW TEXTBOOK` 히어로, 3개 템플릿 행, 빈 교재/템플릿 CTA와 우측 컨텍스트를 확인했다.
- 교재 딥링크 테스트와 대상 파일 정적 분석 통과.
- 소스·번들 커밋 `8f8ed67`, 로컬·alias `public/main.dart.js` SHA-256 `70E7F6A99DC8F2667D11510D1EE21CE3B643CE08865CBF3D7EEC0D2FA2F11420` 일치.
- Vercel 배포 `dpl_8BDUAsFdwDW6NwuH4Zzb2jXWEGoP`, 고유 URL [`aiflow-web-canary-6cw9h06kz-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-6cw9h06kz-cw20208021-9200s-projects.vercel.app), Canary alias READY. `/health` 200 (`aiflow-ocr-queue`), `/health/ready` 404.

### 2026-09-11 교재 편집 탭·하단 동작 보정

- `textbook-editor`에 HTML 기준 `편집/태그/시험지` 탭과 `교재 저장/미리보기` 하단 동작을 추가했다.
- 저장은 기존 실제 교재 저장 API를 호출하며, 미리보기는 현재 편집 화면을 안전하게 닫는 동작으로 연결했다.
- 교재 생성·편집 딥링크 테스트와 대상 파일 정적 분석 통과.
- 소스·번들 커밋 `e111172`, 로컬·alias `public/main.dart.js` SHA-256 `FD18D1B6E9A15356EECC1D769F7A806B94806660578B031AF85A4255416F1C9F` 일치.
- Vercel 배포 `dpl_BfFX6hPKRP48U8xzfMSEcL34uhHA`, 고유 URL [`aiflow-web-canary-15w8zzh21-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-15w8zzh21-cw20208021-9200s-projects.vercel.app), Canary alias READY. `/health` 200 (`aiflow-ocr-queue`).

### 2026-09-11 저장 전 미리보기 데이터 보호

- 저장되지 않은 편집 내용을 버리고 뒤로 가던 `미리보기` 동작을 명시적 안내로 변경했다.
- 사용자는 먼저 `교재 저장`을 실행해야 하며, 저장 API 실패 시 현재 입력을 유지한다.
- 교재 딥링크 테스트와 정적 분석 통과.
- 소스·번들 커밋 `aa3cb0a`, 로컬·alias `public/main.dart.js` SHA-256 `7F98AC4037AED539A744AE151ADB62C6DC59207C9E86520E9C9416C5349009C6` 일치.
- Vercel 배포 `dpl_AVws4oHVSssBiY3j56PYkAwBhp6E`, 고유 URL [`aiflow-web-canary-3ugpkchzy-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-3ugpkchzy-cw20208021-9200s-projects.vercel.app), Canary alias READY. `/health` 200 (`aiflow-ocr-queue`).

### 2026-09-11 교재 편집 장 목록·도구 행 보강

- HTML 편집 화면의 장 목록, 새 장 추가, 펜·되돌리기·그래프 도구 행을 편집 화면에 추가했다.
- 장 추가는 기존 draft 상태를 갱신하며 저장·삭제·설명 편집 계약을 유지한다.
- 대상 파일 정적 분석 통과.
- 소스·번들 커밋 `a3e5c45`, 로컬·alias `public/main.dart.js` SHA-256 `EB663477E1CA7DDCB27E45D4F2E3736327E30572985C6FF8F8F7DDD9DD655F7A` 일치.
- Vercel 배포 `dpl_2Xa9toMsVpVndduWf3CtYuGM3m2c`, 고유 URL [`aiflow-web-canary-fb2nsnrg9-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-fb2nsnrg9-cw20208021-9200s-projects.vercel.app), Canary alias READY. `/health` 200 (`aiflow-ocr-queue`).

### 2026-09-11 코스 화면 동적 오류 상태 비교

- HTML `courses`는 샘플 코스 3개와 진행률을 표시하고, Canary 익명 세션은 실제 API 오류·재시도 상태를 표시했다.
- 사용자 코스·진도 데이터를 HTML 샘플로 덮어쓰지 않는 현재 동작을 유지한다. 오류 상태의 컨테이너·재시도 CTA는 별도 시각 검수 대상으로 남긴다.
- 동일 데스크톱 뷰포트에서 HTML와 Canary를 새 탭으로 캡처해 비교했으며, 이 차이는 허용된 동적 데이터 차이가 아니라 인증/API 미검증 경계로 기록한다.

### 2026-09-11 튜토리얼 화면 동일 조건 재검수

- HTML `about`와 Canary `/landing/about`를 동일 데스크톱 조건에서 새 탭으로 비교했다.
- 상단바, 5단계 좌측 목록, STEP 01 본문, 오늘 학습 예시 카드, 하단 이전/다음·진행률 배치가 일치했다.
- 이 화면에서 추가 코드 수정은 필요하지 않았고, 이미지 근거는 기존 튜토리얼 캡처 검수 항목에 연결했다.

### 2026-09-11 설정 화면 동일 조건 재검수

- HTML `settings`와 Canary `/settings`를 동일 데스크톱 조건에서 비교했다.
- 상단바, 5개 설정 행, 토글·액션 배치, 직각 표면·구분선·간격이 일치했다.
- 토글 값은 기기 로컬 상태이므로 HTML 샘플 값과 별도 데이터로 기록하며, 추가 시각 수정은 필요하지 않았다.

### 2026-09-11 프로필 인증 경계 비교

- HTML `profile`은 신원 히어로·OVR·프로필 관리·계정 관리 패널을 샘플 데이터로 표시한다.
- Canary 익명 세션은 실제 프로필 API 실패를 `프로필을 불러오지 못했어요`와 재시도 CTA로 표시했다.
- 샘플 신원·점수를 삽입하지 않는 동작은 유지한다. 인증된 테스트 계정으로 동일 장면을 재검수해야 하며, 현재는 데이터·인증 미검증으로 남긴다.

### 2026-09-11 자료실 동적 목록 경계 비교

- HTML `marketplace`의 검색·필터·자료 유형 탭과 6개 카드 구조를 기준으로 확인했다.
- Canary는 검색·필터·탭 셸은 표시하지만 실제 자료 API 실패를 오류·빈 결과 상태로 표시한다.
- 샘플 자료를 상용 목록처럼 삽입하지 않는 정책을 유지한다. 인증된 자료 API 응답이 확보되면 카드 밀도·줄바꿈·필터 시트를 추가 검수한다.

### 2026-09-11 학원 탐색 데모 제목 보정 및 canary 반영

- HTML `academy-find`의 제목은 `AIFlow 학원 가맹점 찾기`인데 Canary는 `학원 찾기`로 표시되던 차이를 확인했다.
- `StudentServiceKind.academy`일 때만 HTML 제목을 사용하도록 수정했다. 과외 화면 제목은 `과외 찾기`로 유지했다.
- OSM 지도와 샘플 안내 문구는 계획에서 허용한 canary 데모 동작이므로 변경하지 않았다.
- `flutter analyze lib/features/student_services/student_services_demo_page.dart`: 통과.
- 관련 통합 실행에서는 기존 레거시 반응형 기대값·pumpAndSettle 타임아웃 5건이 실패했다. 이번 제목 수정과 무관하며 기존 미해결 항목으로 남긴다.
- 소스·번들 커밋 `8002ed1`, 로컬·alias `public/main.dart.js` SHA-256 `1CC9F9C75E8830A9FBC6BFEEFB9FD37360CE52AD51C26E62F61A98A35EE0F366` 일치.
- Vercel 배포 `dpl_4M93tsxQj6y5srdLxPriEaLRmt7v`, 고유 URL [`aiflow-web-canary-f5za7ou71-cw20208021-9200s-projects.vercel.app`](https://aiflow-web-canary-f5za7ou71-cw20208021-9200s-projects.vercel.app), Canary alias READY. `/health` 200 (`aiflow-ocr-queue`), `/health/ready` 404.
