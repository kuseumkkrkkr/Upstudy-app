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

### 2026-09-10 PC 상단 내비게이션 HTML 목적지 일치화 (다음 후보)

- `studentTopNavItems`의 legacy 목록을 HTML `appNavigation()`과 같은 `홈·코스·자료실·더보기` 4개로 정리했다. 자료실은 기존 `/marketplace`, 더보기는 기존 메뉴 호스트를 사용하며 친구·소셜·책가방 화면에서는 해당 보조 섹션을 활성 표시한다.
- 기존 화면의 `StudentTopDestination` enum과 명명 라우트 호출은 보존했다. 새 임의 문자열 목적지나 샘플 데이터는 추가하지 않았다.
- 회귀 검증: `PC 공용 상단 메뉴는 HTML 네 목적지와 명명 라우트를 공유한다`, `PC 상단 홈과 코스는 서로 다른 경로로 이동한다` 통과. 새 정적 번들·canary 반영과 `1280×900` 캡처는 다음 빌드 게이트에서 수행한다.
