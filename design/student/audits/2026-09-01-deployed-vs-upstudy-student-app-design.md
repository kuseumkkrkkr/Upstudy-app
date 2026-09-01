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
| G-TOKEN-001 | canvas `#f0f0f2`, surface `#fdfdfe`, muted `#f3f3f5`, ink `#09090b`, dark `#111113` | `student_density.dart`의 배경·보조표면·dark 값이 다름 | P2 | 공통 토큰으로 통일 |
| G-SHELL-001 | PC 84px rail + main + 244px context aside | 상단 메뉴 중심 셸, 화면별 drawer 혼용 | P1 | 공통 StudentShell로 통합 |
| G-SHELL-002 | tablet 72px rail, aside 숨김 | 화면별 breakpoint가 720/780/900/980/1000으로 분산 | P2 | 공통 720/1040, 작업공간 예외만 유지 |
| G-SHELL-003 | mobile 66px bottom nav | 일부 화면만 bottom nav를 표시 | P1 | shell-backed 학생 화면에 일관 적용 |
| G-NAV-001 | mobile 활성 셀은 흰색 + 상단 3px 선 | 활성 셀 검은 캡슐 + 흰색 글자 | P2 | HTML 최종 cascade 적용 |
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
| profile | `/profile` · `ProfilePage` | partial | HTML 요약+편집 sheet, Flutter 장문 inline form |
| settings | `/settings` · `SettingsPage` | partial | 토글은 유사하나 account-link wizard·삭제/재인증 상태 차이 |
| about | `/landing/about` · `LandingAboutPage` | partial | HTML 5단계 제품 튜토리얼과 marketing/about 페이지 불일치 |

### 홈 (10)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| home | `/student/dashboard` · `MainStudentPage` | partial | HTML A rail, 현재 코스 68%, 6 action, 9 dashboard와 현재 hero/status/tools 구조 불일치 |
| today-tasks | 홈 modal · `today_tasks_modal.dart` | partial | 시간순 task·완료/추가 상태와 현재 modal 구성 차이 |
| course-select | 홈 modal · `curriculum_modal.dart` | partial | 코스 선택 sheet 높이·행·완료/미등록 이동 차이 |
| rating-detail | 홈 modal · `rating_detail_modal.dart` | partial | OVR graph/개념·활동 상세 구조 차이 |
| daily-test | `/level_test` · `LevelTestHomePage` | partial | HTML 홈 quick action과 실제 진입·라벨 차이 |
| study-mode | 제한 모드 route/modal | partial | HTML sheet와 drawer의 모드 선택·복귀 차이 |
| activity-history | `/schedule`·활동 보고서 | partial | 56일 타임라인·활동 지표와 현재 일정/이력 분리 |
| achievements | 활동 배지 위젯 | partial | 탭·상세 sheet·진행률 상태가 HTML 구조와 다름 |
| schedule | `/schedule` · `SchedulePage` | partial | HTML 주간 타임라인·일정 추가 dialog와 현재 화면 차이 |
| schedule-history | `/schedule/history` | partial | 커리큘럼 이력 필터·재배정 상태 차이 |

### 코스 (14)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| courses | `/courses` · `CourseCatalogPage` | partial | HTML library shell·filter·카드 밀도 차이 |
| course-detail | 코스 상세 위젯 | missing | 신규 hero/progress/accordion/mobile fixed CTA 미구현 |
| course-learning | 코스 학습 위젯 | partial | mission dispatcher·다음 문제·runtime 상태 차이 |
| course-runtime | `/course_runtime` | P1 | 인자 없는 경로가 catalog fallback |
| review-course | 복습 course 위젯 | partial | review 상태·완료 후 복귀 차이 |
| course-curriculum | 코스 curriculum 위젯 | partial | 현재 단원 자동 펼침·선행 상태 차이 |
| course-challenge | challenge 위젯 | partial | challenge 묶음·제한 시간·재시도 차이 |
| course-exam | exam 위젯 | partial | 시험 전 preview/submit/result 연결 차이 |
| course-review | review 위젯 | partial | 코스 review CTA·완료 갱신 차이 |
| level-home | `/level_test` | partial | HTML 진단 overview와 현재 entry 차이 |
| level-solve | level test runtime | partial | 25문항·시간·뒤로가기 상태 검증 필요 |
| level-result | `/level_test/result` | partial | 결과·재시도·코스 추천 상태 차이 |
| wrong-list | `/wrong_answers` | partial | filter·약점·복습 CTA 차이 |
| wrong-solve | `/wrong_answer_solve` | P1 | 현재 목록으로 redirect, 실제 solve workspace 아님 |

### 풀이 (8)

| HTML ID | Flutter/배포 기준 | 상태 | 핵심 차이 |
| --- | --- | --- | --- |
| student-runtime | `StudentRuntimePage` | partial | HTML learning runtime header와 현재 shell 차이 |
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
| marketplace | `/marketplace` · `MarketplacePage` | partial | HTML resource grid/filter와 현재 marketplace 카드·구매 상태 차이 |
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
| 캡처 근거 | 기준 HTML 홈, 배포 canary, 로컬 hotfix 홈·학원 데모 캡처를 동일 evidence 폴더에 저장 | `evidence/2026-09-01-deployed-vs-design/design-home-390x844.png`, `deployed-post-hotfix-dashboard-390x844.png`, `deployed-post-hotfix-dashboard-1280x900.png`, `local-hotfix-dashboard-390x844.png`, `local-academy-demo.png` | 모바일·PC 배포 렌더링 확인 |

초기 비교 캡처(`deployed-dashboard-390x844.png`)는 이전 `public/main.dart.js` 정적 번들이 배포된 상태라 흰 화면으로 기록되었다. `public/`을 새 release bundle로 갱신한 최종 배포(`8894377`, Vercel `dpl_AngCDDZgX8H6bipAVDxPpZrjQLDN`)에서는 동일 390×844와 1280×900에서 홈이 렌더링됨을 이미지로 재확인했다(`deployed-post-hotfix-dashboard-390x844.png`, `deployed-post-hotfix-dashboard-1280x900.png`). 브라우저 DOM 접근성 스냅샷은 CanvasKit 특성상 `Enable accessibility` 버튼만 노출되어, Semantics·키보드 포커스는 별도 Flutter 테스트 범위로 남긴다. 기준 HTML은 `?screen=home` 상태에서 A rail, 현재 코스, 6개 학습 동작, 대시보드 카드와 우측 컨텍스트 영역이 표시됨을 확인했다.

### 최종 배포 기록 (2026-09-01)

- 커밋: `8894377` (`chore(hotfix): refresh Flutter web bundle`), `origin/hotfix` 반영.
- Vercel: [`dpl_G6G3xomTuPnPyXH6wSSi7X3kH2yQ`](https://vercel.com/cw20208021-9200s-projects/aiflow-web-canary/G6G3xomTuPnPyXH6wSSi7X3kH2yQ), production alias [`aiflow-web-canary.vercel.app`](https://aiflow-web-canary.vercel.app/#/student/dashboard).
- 환경: `STUDENT_STORE_DEMO=true`를 Vercel Production에 추가해 포인트 데모 API를 canary에서만 활성화했다. Flutter UI의 `STUDENT_SERVICES_DEMO`·`STUDENT_STORE_DEMO`는 release 빌드 define으로 포함됐다.
- 런타임: `GET /health` 200, 인증 없는 `/demo/student-store`·`/student/school-exam-plan/active`는 401 `Bearer token required`.
- 브라우저: 390×844 모바일·1280×900 데스크톱 홈 렌더링 확인. 실제 학생 계정 데이터와 Supabase migration 적용 여부는 이 캡처에 포함하지 않는다.

자동 검증:

- `flutter test --no-pub test/student_route_registry_test.dart test/wrong_answer_legacy_route_test.dart test/app_drawer_navigation_test.dart test/marketplace_page_test.dart test/student_learning_tools_route_test.dart` — 통과.
- 수정 파일 대상 `dart analyze --format machine` — 오류 없음(신규 demo file의 기존 API deprecated hint 3건).
- `python -m py_compile api/index.py`, `git diff --check` — 통과.
- 전체 `flutter analyze --no-pub`는 기존 teacher/textbook 누락·타입 오류 1,269건으로 저장소 기준선에서 실패했으며, 이번 변경 범위 밖이다.
