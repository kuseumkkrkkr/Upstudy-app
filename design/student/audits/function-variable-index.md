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
| `StudentServicesDemoStore.requests` · `List<DemoServiceRequest>` | 현재 사용자 데모 문의 | 빈 목록, 앱 세션 + 로컬 복구 | `add/cancel/restore`, 로컬 JSON |
| `_SchoolExamPrepPageState._taskIds` · `List<String>` | 서버 task 식별자 | 빈 목록, 화면 수명 | `_loadPlan`, 서버 task ID만 사용 |
| `_SchoolExamPrepPageState._version` · `int` | 내신 계획 optimistic 버전 | 0, 서버 응답으로 갱신 | `_loadPlan`, 설정 저장·task PATCH |
| `_StudentStoreDemoPageState._idempotencyKeys` · `Map<String,String>` | 상품별 재시도 키 | 빈 map, 주문 완료까지 | `_redeem`, 메모리; 서버 주문 원장과 대응 |
| `_StudentStoreDemoPageState._redeeming` · `Set<String>` | 진행 중 상품 잠금 | 빈 set, 요청 수명 | `_redeem` 시작/finally |
| `StudentFeatureFlags.servicesDemo/storeDemo` · `bool` | canary 데모 노출 여부 | build-time false, 번들 수명 | `--dart-define`, 메뉴·라우트·검색·페이지 |
