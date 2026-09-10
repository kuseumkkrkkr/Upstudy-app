# 학생 앱 수정 함수·변수표

이 문서는 이번 HTML 일치화 작업에서 책임이 바뀐 공개 클래스와 핵심 상태를 빠르게 찾기 위한 인덱스다. 화면 전체의 일치 여부는 `2026-09-01-deployed-vs-upstudy-student-app-design.md`와 `student-parity.json`에서 관리한다.

## 함수·클래스표

| 클래스·함수 | 하는 일 | 입력·반환 | 상태 변경·실패 처리 |
|---|---|---|---|
| `StudentHtmlShell.build` | 모바일·태블릿·데스크톱 셸과 레일/컨텍스트 영역을 조합 | `BuildContext` → `Widget` | 내비게이션은 전달 콜백과 명명 라우트를 사용 |
| `StudentRouteSpec.destination` | 화면 ID를 메뉴·검색에서 재사용할 불변 목적지 값으로 노출 | 없음 → `StudentDestination` | 문자열 목적지를 화면 메타와 분리해 감사 ID를 보존 |
| `StudentDestination` | 화면 ID·route·인증·데모 조건을 함께 보유하는 검색/메뉴용 목적지 값 | `screenId`, `routeName`, `requiresAuth`, `demoOnly` → 불변 객체 | 목적지 생성 시 registry 메타데이터를 복사하며 임의 문자열 경로를 만들지 않음 |
| `StudentRouteSpec.shell/activeNav` | HTML 셸 종류와 활성 내비게이션 영역을 화면 ID에서 계산 | 없음 → `StudentShellKind`/`StudentNavSection` | registry 한 곳에서만 분류해 화면별 셸 복제를 막음 |
| `StudentRouteRegistry.searchable` | HTML QUICK FIND 31개 목적지를 레지스트리에서 제공 | 없음 → `Iterable<StudentRouteSpec>` | 데모 전용 항목은 기능 플래그로 필터 |
| `_StudentQuickSearchSheetState._open` | 검색 시트를 닫고 등록 목적지로 이동 | 검색 record → 없음 | 루트 Navigator 이동, 잘못된 목적지는 라우터가 처리 |
| `_StudentQuickSearchSheetState._routeForSearchDestination` | 검색 목적지의 기본 라우트와 홈 내부 장면 딥링크를 변환 | 검색 record → `String` | `today-tasks`·`rating-detail`·`achievements`만 `?scene=`을 붙이고 나머지는 registry 라우트를 그대로 사용 |
| `_showStudentUtilityPanel` | 검색·알림 패널을 원본 셸 규칙에 맞는 시트 또는 우측 패널로 표시 | `BuildContext`, `Widget`, `sidePanel` → `Future<void>` | 검색은 모바일 하단/데스크톱 우측, 알림은 모든 폭 우측 390px 패널; 배경 클릭·닫기·ESC는 Navigator 계약을 사용 |
| `showStudentNotifications` | 알림 센터를 전체 높이 우측 패널로 연다 | `BuildContext` → `void` | 공지·친구 요청·메시지 조회와 기존 수락/거절 API를 유지 |
| `_LoginPageState._canSubmit` | HTML 로그인 기본 버튼의 활성 조건을 계산 | 없음 → `bool` | 아이디·비밀번호가 모두 입력되고 로딩 중이 아닐 때만 true를 반환 |
| `_LoginPageState._buildHtmlLoginFormContents` | 기준 HTML 로그인 필드·버튼·간편 로그인·가입 진입 순서를 렌더링 | `BuildContext` → `Widget` | 기존 인증 submit/Kakao API와 입력 검증을 재사용하고 로딩 중 중복 제출을 막음 |
| `_HtmlLoginBrand.build` | HTML 로그인 패널의 A 마크와 AIFlow 브랜드를 표시 | `BuildContext` → `Widget` | 검은 A 마크·직각 패널 토큰만 사용하며 상태 변경 없음 |
| `_SignupPageState._buildHtmlSignupScreen` | 가입 HTML 패널·단계 헤더·현재 단계 폼을 조합 | `BuildContext` → `Widget` | 640px 데스크톱/전체 폭 모바일, 기존 가입 상태와 API 계약 재사용 |
| `_SignupPageState._buildHtmlProfileStage` | 닉네임·과정·학년·과목·학교명과 다음 단계 CTA를 HTML 순서로 표시 | 없음 → `Widget` | 학교명 선택 입력, 중학교 과목 비활성, 단계 검증 실패 시 현재 단계 유지 |
| `_SignupPageState._buildHtmlAccountStage` | 아이디·비밀번호·확인·이메일 입력과 이전/확인 CTA를 표시 | 없음 → `Widget` | 비밀번호 보기 상태를 로컬로 변경하고 기존 형식 검증을 재사용 |
| `_SignupPageState._buildHtmlConfirmStage` | 가입 정보 요약·동의·실제 가입 CTA를 표시 | 없음 → `Widget` | 동의 전 제출 비활성, `_submit`의 JWT 저장·홈 이동 계약 유지 |
| `_SignupPageState._htmlSelectField` | HTML 직각 선택 입력과 선택적 도움말을 렌더링 | label/value/items/onChanged → `Widget` | 비활성 과목은 선택을 차단하고 서버에 임의 값을 만들지 않음 |
| `_SignupPageState._htmlPrimaryButton` | HTML 52px 검은 주요 버튼과 오른쪽 화살표를 렌더링 | label, `VoidCallback?` → `Widget` | null 콜백은 HTML 42% 비활성 색상으로 표시 |
| `_MainStudentPageState._handleStudyAction` | 홈 6개 학습 타일의 요약 시트를 열고 내부 CTA를 기존 실제 목적지로 dispatch | `String`, `Course?` → `void` | enum으로 목적지를 제한하고 코스·오답·책가방 라우팅은 기존 계약을 재사용 |
| `_HomeStudyActionSheet.build` | HTML 홈 학습 시트의 제목·실제 데이터 안내·단일 CTA를 렌더링 | `BuildContext` → `Widget` | 닫기·CTA 후 Navigator를 닫고 호출자가 기존 화면으로 이동 |
| `_CourseCatalogPageState._openMarketplace` | 코스 화면의 새 코스 찾기와 상단 검색을 기존 자료실 화면으로 연결 | 없음 → `void` | `/marketplace` 명명 라우트를 사용하고 코스 검색 전용 시트를 열지 않음 |
| `CourseRuntimePage.build` | 실제 `courseId`가 있는 런타임만 학습 화면으로 열고 인자 없는 딥링크는 명확한 오류 상태로 표시 | `BuildContext` → `Widget` | 인자 없음·조회 실패·로딩을 구분하고 코스 목록 복귀 CTA를 제공 |
| `_SettingsPageState._showAccountLinkSheet` | HTML 계정 연동 역할·방법·입력 시트를 연다 | 없음 → `void` | 실제 연동 API가 없을 때 전송하지 않는 안내를 유지 |
| `_AccountLinkSheetState._buildStep` | 역할·ID·QR 스캔·내 QR 코드 장면을 현재 단계에 맞춰 렌더링 | 없음 → `Widget` | 단계 이동은 로컬 상태, API 호출·권한 변경 없음 |
| `_CourseLoaderState._load` | 실제 수강 코스에서 사용자별 마지막 선택 코스를 우선 복원 | 없음 → `Future<void>` | `student.active_course.v1` 조회 실패 시 서버 순서로 fallback, 코스 데이터는 API에서만 사용 |
| `_MobileCourseCatalog` | 모바일 코스 목록의 로딩·오류·빈 목록·실제 코스 상태를 HTML 순서로 렌더링 | `loading`, `hasError`, 코스 목록·콜백 → `Widget` | API 오류는 재시도 행으로 표시하고 빈 목록으로 축약하지 않음 |
| `StudentTutorialPage` | HTML `about` 화면의 5단계 학생 튜토리얼과 전용 셸을 렌더링 | 없음 → `Widget` | 단계 이동·실습 완료·완료 후 홈 이동, 진행 상태는 로컬 저장만 사용 |
| `_StudentTutorialPageState._loadState/_saveState` | 튜토리얼 현재 단계와 실습 완료 단계를 복원·저장 | 없음 → `Future<void>` | `student.atlas.tutorial.v1` 로컬 키, 저장 실패는 안내 동작을 막지 않음 |
| `_TutorialLayout` | 720px 기준 데스크톱 레일/모바일 가로 단계 목록과 본문·하단 액션을 조합 | 폭·현재 단계·콜백 → `Widget` | HTML의 230px 단계 레일·64px 모바일 단계 바·70px 액션 바를 유지 |
| `_TutorialDemo` | 현재 단계의 강조 실습 카드와 완료 상태를 표시 | 단계·완료 여부·콜백 → `Widget` | 샘플 문구만 사용하며 실습 버튼은 로컬 진행 상태만 변경 |
| `StudentServicesDemoStore.restore` | 사용자별 데모 문의 상태를 로컬 저장소에서 복구 | 없음 → `Future<void>` | 손상된 데모 JSON은 무시하고 실제 서버 데이터는 변경하지 않음 |
| `StudentServicesDemoStore.add/cancel` | 데모 문의 추가·취소와 영속 저장 | `DemoServiceRequest` → 없음 | `aiflow.student.services.demo.v1` 키로 비동기 저장 |
| `_SchoolExamPrepPageState._loadPlan` | 실제 수학 내신 계획·task ID·버전을 조회 | 없음 → `Future<void>` | 로딩/오류/빈 상태를 분리하고 재시도 제공 |
| `_SchoolExamPrepPageState._toggleTask` | task 완료 상태를 서버 PATCH로 저장 | index, bool → `Future<void>` | optimistic 표시 후 실패 복구, 409는 최신 계획 재조회 |
| `_StudentStoreDemoPageState._redeem` | 서버 권위 포인트 교환을 수행 | 상품 record → `Future<void>` | 상품별 멱등 키를 유지하고 요청 중 중복 탭 차단 |
| `_social_next_group_created_at` | 그룹 메시지 생성 시 정렬 가능한 단조 시간 생성 | group ID → ISO 문자열 | 기존 메시지보다 이른 시스템 시계를 보정 |
| `send_server_chat_message` | 인증된 튜터 요청을 upstream으로 전달 | `ServerChatMessageRequest` → JSON | 비설정 503, upstream 오류 502, 토큰은 서버에서만 사용 |

## 변수표

| 이름·타입 | 의미·출처 | 기본값·수명 | 갱신 위치·저장 |
|---|---|---|---|
| `StudentHtmlShell.railWidth` · `double?` | 화면별 CSS 레일 폭(px) | null이면 84/72px, 화면 수명 | 셸 빌드, 메모리 |
| `_StudentQuickSearchSheetState._query` · `String` | 검색 입력값 | 빈 문자열, 시트 수명 | `TextField.onChanged`, 메모리 |
| `_showStudentUtilityPanel.sidePanel` · `bool` | 알림처럼 우측 전체 높이 패널을 사용할지 여부 | false, 호출 수명 | `showStudentNotifications`에서만 true로 지정, 메모리 |
| `StudentServicesDemoStore.requests` · `List<DemoServiceRequest>` | 현재 사용자 데모 문의 | 빈 목록, 앱 세션 + 로컬 복구 | `add/cancel/restore`, 로컬 JSON |
| `_SchoolExamPrepPageState._taskIds` · `List<String>` | 서버 task 식별자 | 빈 목록, 화면 수명 | `_loadPlan`, 서버 task ID만 사용 |
| `_SchoolExamPrepPageState._version` · `int` | 내신 계획 optimistic 버전 | 0, 서버 응답으로 갱신 | `_loadPlan`, 설정 저장·task PATCH |
| `_StudentStoreDemoPageState._idempotencyKeys` · `Map<String,String>` | 상품별 재시도 키 | 빈 map, 주문 완료까지 | `_redeem`, 메모리; 서버 주문 원장과 대응 |
| `_StudentStoreDemoPageState._redeeming` · `Set<String>` | 진행 중 상품 잠금 | 빈 set, 요청 수명 | `_redeem` 시작/finally |
| `_activeCourseStorageKey` · `String` | 홈에서 마지막으로 선택한 코스의 사용자 저장소 키 | `student.active_course.v1`, 앱 수명 | `_handleCourseTap` 저장·`_CourseLoaderState._load` 복원, 서버 사용자 저장소 |
| `_LoginPageState._canSubmit` · `bool` | 두 로그인 필드가 입력되어 기본 제출이 가능한지 나타냄 | false, 화면 수명 | 아이디·비밀번호 `onChanged`에서 재계산, 메모리 |
| `_SignupPageState._stage` · `int` | 가입 현재 단계(0 기반) | 0, 화면 수명 | `_setStage`/`_requestStage`, 메모리 |
| `_SignupPageState._track` · `String` | 중학교·고등학교 과정 선택 | 중학교, 화면 수명 | 과정 세그먼트 클릭, 메모리·가입 payload |
| `_SignupPageState._subject` · `String` | 고등학교 수학 과목 선택 | 확률과통계, 화면 수명 | 과목 선택/중학교 전환 시 기본값 복구, 가입 payload |
| `_SignupPageState._agreed` · `bool` | 최종 가입 안내 동의 여부 | false, 화면 수명 | 확인 단계 체크박스, 제출 활성 조건 |
| `_SignupPageState._passwordVisible`/`_passwordConfirmVisible` · `bool` | 각 비밀번호 표시 상태 | false, 화면 수명 | 보기/숨기기 버튼, 메모리 |
| `_HomeStudyAction` · `enum` | 홈 학습 타일의 허용된 6개 dispatch 키 | `resume` 등 6개, 화면 수명 | `_handleStudyAction.fromId`, 영속화하지 않음 |
| `_JsxGraphPageState._scheduleGraphApply` | 수식 입력을 280ms 디바운스하고 최신 요청만 그래프에 반영 | 없음 → `void` | 이전 타이머 취소, revision 불일치 응답 무시 |
| `_JsxGraphPageState._applyCurrentDrafts` | 검증된 함수식을 `/graphs/sample`에 보내 좌표 시리즈를 갱신 | 선택 revision → `Future<void>` | 422 수식 오류와 네트워크 오류를 구분하고 마지막 정상 그래프 유지 |
| `_JsxGraphPageState._buildMobileGraphLayout` | HTML 그래프의 보드·compact/expanded/collapsed 하단 트레이를 조합 | 제약·보드·편집기 → `Widget` | 트레이 높이와 애니메이션만 로컬 상태로 변경 |
| `StudentFeatureFlags.servicesDemo/storeDemo` · `bool` | canary 데모 노출 여부 | build-time false, 번들 수명 | `--dart-define`, 메뉴·라우트·검색·페이지 |
| `_JsxGraphPageState._sampleDebounce` · `Timer?` | 마지막 수식 입력 후 자동 갱신 예약 | null, 화면 수명 | `_scheduleGraphApply`, dispose에서 취소 |
| `_JsxGraphPageState._sampleRevision` · `int` | 비동기 그래프 요청의 최신 순번 | 0, 화면 수명 | 입력·수동 갱신마다 증가, 오래된 응답 차단 |
| `_JsxGraphPageState._mobileTrayState` · `_GraphTrayState` | 모바일 입력 트레이 접힘/기본/확장 상태 | `compact`, 화면 수명 | 트레이 손잡이 탭, 영속화하지 않음 |
| `StudentTutorialPage._storageKey` · `String` | HTML 튜토리얼 진행 상태를 구분하는 로컬 저장 키 | `student.atlas.tutorial.v1`, 앱 수명 | `_loadState/_saveState`, SharedPreferences |
| `_StudentTutorialPageState._current` · `int` | 현재 튜토리얼 단계(0 기반) | 0, 화면·로컬 저장 수명 | 단계 레일·이전/다음 버튼, SharedPreferences |
| `_StudentTutorialPageState._practiced` · `Set<String>` | 실습을 확인한 단계 ID 집합 | 빈 집합, 화면·로컬 저장 수명 | 실습 CTA, SharedPreferences 문자열 목록 |
