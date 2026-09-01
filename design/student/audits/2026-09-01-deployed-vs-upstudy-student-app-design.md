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
| schedule-history | `/schedule/history` | partial | 커리큘럼 이력 필터·재배정 상태 차이 |

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
| group-join | `/groups/join` | partial | code route·잠금/공개 복귀 차이 |
| group-detail | `/group/detail` | partial | args 필수·3탭·공유·멤버 구조 차이 |
| group-chat | group chat | partial | 메시지·권한·공유 상태 차이 |
| group-share | group share | partial | 최근 60일·최대 5개·학생 답안 제외 계약 차이 |
| student-academy | `/academy/dashboard` | partial | args 없는 production caller 부재 |
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
| tools-hub | learning tools hub | partial | production entry·라벨 충돌 |
| learning-tools-modal | learning tools modal | partial | six destination·nested return 상태 차이 |
| notepad | `NotepadPage` | partial | 저장·모바일 toolbar·복귀 차이 |
| timer | `TimerPage` | partial | 테마/세션/완료 상태 차이 |
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

초기 비교 캡처(`deployed-dashboard-390x844.png`)는 이전 `public/main.dart.js` 정적 번들이 배포된 상태라 흰 화면으로 기록되었다. 이후 `HtmlHomeDashboard`가 실제 Flutter 홈 본문을 대체하고 `_HtmlStudentRail`·`_HtmlStudentTopBar`·`_HtmlContextAside` 공통 셸을 추가했다. `725cf16` production 배포에서 HTML과 같은 390×844·1280×900 홈 구조(모바일 상단바/하단탭, 데스크톱 A 레일, 인사·코스·이어하기, 6개 액션, 마이 대시보드, 우측 컨텍스트)를 이미지로 재확인했고, 설정·프로필·코스 목록에도 같은 셸과 HTML 구조를 이식했다(`deployed-725cf16-*.png`). `663fd3d` production 배포에서는 자료실도 같은 셸로 전환해 `deployed-663fd3d-marketplace-390x844.png` 및 `deployed-663fd3d-marketplace-1280x900.png`로 확인했다. 새 탭에서 5초 대기 후 브라우저 콘솔 error/warn은 0건이었다(정보 로그에는 canary `OMJ_JWT_SECRET` 미설정 안내가 남는다). 브라우저 DOM 접근성 스냅샷은 CanvasKit 특성상 `Enable accessibility` 버튼만 노출되어, Semantics·키보드 포커스는 별도 Flutter 테스트 범위로 남긴다. 기준 HTML은 `?screen=home` 상태에서 같은 순서와 밀도로 표시됨을 확인했다. 이 반영은 홈·공통 셸·설정·프로필·코스 상세·자료실 구조에 한정되며, 나머지 화면은 아래 매핑 상태(`partial`/`missing`) 그대로 추가 구현 대상이다.

### 최종 배포 기록 (2026-09-02)

- 커밋: `d27d75c` (`refactor(student): align wrong answer list with html shell`), `origin/hotfix` 반영. 자료실·학습 일정·레벨 테스트·학생 런타임·오답 목록 수정과 감사 증거를 포함한다.
- Vercel: [`dpl_6kkHdcouane8dYi2db92mDnY5mjw`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/6kkHdcouane8dYi2db92mDnY5mjw), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/student/dashboard). 새 release bundle에 오답 목록 HTML 셸 변경을 포함한다.
- 환경: release bundle에 `API_BASE_URL=https://aiflow-web-canary.vercel.app`, `STUDENT_SERVICES_DEMO=true`, `STUDENT_STORE_DEMO=true`, HTTPS `OSM_TILE_URL`을 정의했다. 포인트 데모 API는 canary에서만 활성화된다.
- 런타임: `GET /health` 200, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active`는 401 JSON이며 release bundle에는 `localhost`가 없다.
- 브라우저: production alias의 390×844 모바일·1280×900 데스크톱 홈·설정·프로필·코스 목록·오답 재풀이·오답 목록·코스 런타임·자료실·학습 일정·레벨 테스트·학생 런타임을 새 탭에서 5초 대기 후 캡처했고, 각 캡처의 콘솔 error/warn은 0건이다. 오답 목록과 학생 런타임은 최신 `6kkHdc` 배포에서 각각 HTML 모바일 상단바/하단탭과 PC A 레일/메인 셸을 확인했다. 오답 재풀이 데이터 호출은 canary에서 `OMJ_JWT_SECRET is not configured` 503을 반환해 오류/재시도 상태로 캡처했다. 코스 런타임도 인증 없는 임의 ID에 대해 오류/목록 복귀 상태를 렌더링한다. 자료실·학습 일정·레벨 테스트는 API 인증/데이터 경계에서 HTML 셸의 빈/오류 또는 시작 상태를 렌더링한다. 실제 학생 계정 데이터와 Supabase migration 적용 여부는 이 캡처에 포함하지 않는다.

자동 검증:

- `flutter test --no-pub test/student_route_registry_test.dart test/wrong_answer_legacy_route_test.dart test/app_drawer_navigation_test.dart test/marketplace_page_test.dart test/student_learning_tools_route_test.dart` — 통과.
- 수정 파일 대상 `dart analyze --format machine` — 오류 없음(신규 demo file의 기존 API deprecated hint 3건).
- `python -m py_compile api/index.py`, `git diff --check` — 통과.
- 전체 `flutter analyze --no-pub`는 기존 teacher/textbook 누락·타입 오류 1,269건으로 저장소 기준선에서 실패했으며, 이번 변경 범위 밖이다.
