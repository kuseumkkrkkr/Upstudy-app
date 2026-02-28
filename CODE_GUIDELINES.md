# AIFlow 프로젝트 코드 지침

## 프로젝트 개요

**AIFlow**는 AI 기반 수학 문제 생성 및 학습 관리 시스템입니다. Flutter 프론트엔드와 FastAPI 백엔드로 구성된 풀스택 애플리케이션입니다.

### 기술 스택
- **프론트엔드**: Flutter 3.9.0+, Dart
- **백엔드**: Python, FastAPI
- **데이터베이스**: SQLite (quests.db)
- **주요 라이브러리**: 
  - Flutter: google_fonts, flutter_slidable, http, url_launcher, flutter_math_fork
  - Python: fastapi, pydantic, google-genai, pyjwt, reportlab (asyncio는 표준 라이브러리)

---

## 프로젝트 구조

```
s11/
├── lib/                          # Flutter 애플리케이션
│   ├── main.dart                 # 앱 진입점
│   ├── pages.dart                # AppShell 라우팅/토큰 표시
│   ├── landing/                  # 랜딩 페이지
│   │   └── landing_page.dart
│   ├── auth/                     # 인증 플로우
│   │   ├── login_page.dart
│   │   └── signup_page.dart
│   ├── models/                   # 데이터 모델
│   │   ├── concept_tag.dart
│   │   └── content_block.dart    # 콘텐츠 블록 파싱 (text/latex)
│   ├── pages/                    # 화면 위젯
│   │   ├── mainpage_widget.dart  # 메인 페이지
│   │   ├── student.dart          # 학생 대시보드(BuildboxCopyWidget)
│   │   ├── character_chat_debug_page.dart  # 캐릭터 챗봇 디버깅
│   │   ├── quick_generate_page.dart       # 1문제 생성/디버깅
│   │   ├── solution_view_page.dart        # 문제 검색/풀이 흐름 보기
│   │   ├── data_open_page.dart            # DB 페이지네이션 조회
│   │   ├── exam_preview_page.dart         # 시험지 미리보기(A4 그리드)
│   │   ├── flow_view_page.dart            # Flow Editor
│   │   └── quest_picker_page.dart         # 문제 선택 페이지
│   ├── services/                 # 비즈니스 로직
│   │   ├── api_client.dart       # HTTP API 클라이언트
│   │   ├── auth_service.dart     # 로그인/회원가입 API
│   │   └── dialog_service.dart   # 다이얼로그 관리
│   ├── widgets/                  # 재사용 가능한 위젯
│   │   ├── content_blocks_view.dart
│   │   ├── header_bar.dart
│   │   └── menu_button.dart
│   └── dialogs/                  # 커스텀 다이얼로그
│       ├── buildbox_widget.dart
│       ├── concept_tag_dialog.dart
│       └── web_fixed_dialog.dart
│
└── omj/                          # Python 백엔드
    ├── README.md                 # 백엔드 실행/환경 변수 안내
    ├── server.py                 # FastAPI 서버
    ├── main.py                   # CLI 문제 생성 도구
    ├── auth.py                   # JWT 인증
    ├── exam_service.py           # 시험지 생성 로직
    ├── pdf_builder.py            # PDF 생성
    ├── write2LaTeX.py            # LaTeX 보조 스크립트
    ├── resampling.py             # 리샘플링 유틸
    ├── quests.db                 # SQLite 데이터베이스
    ├── generater/                # AI 문제 생성
    │   ├── ai_gen.py
    │   ├── fix_gen.py
    │   ├── make.py
    │   └── prompt_builder.py
    ├── storage/                  # 데이터 저장소
    │   ├── storage.py
    │   └── exam_storage.py
    ├── baselines/                # 기본 모델
    │   └── basemodel.py
    └── test_chat/                # 챗봇 서비스
        └── service.py
```

---

## 아키텍처 패턴

### 1. 프론트엔드 (Flutter)

#### **레이어 구조**
```
Presentation Layer (Landing/Auth/Pages/Widgets)
        ↓
Service Layer (ApiClient, AuthService, DialogService)
        ↓
Model Layer (ContentBlock, ConceptTag)
```

#### **주요 패턴**
- **Stateful Widget 패턴**: 상태 관리가 필요한 페이지
- **Singleton 패턴**: `ApiClient.instance` (HTTP 클라이언트)
- **Factory 패턴**: `ContentBlock.fromMap()`, `ExamItem.fromJson()`
- **Service Locator**: `DialogService`로 중앙화된 다이얼로그 관리
- **환경변수 기반 라우팅**: `API_BASE_URL`, `API_LOGIN_PATH`, `API_REGISTER_PATH`
- **토큰 보장 흐름**: 토큰이 없으면 `ApiClient._ensureToken()`이 `/auth/anonymous` 호출
- **라우팅 상수**: 각 화면은 `static const routeName` 선언 (예: `/`, `/login`, `/signup`, `/app`)
- **라우트 인자 전달**: `AppShell`은 `onGenerateRoute`에서 `settings.arguments`로 token을 수신
- **Material3 테마**: `useMaterial3: true` + `colorSchemeSeed(0xFF45BF63)` 기반 색상 유지

### 2. 백엔드 (Python/FastAPI)

#### **레이어 구조**
```
API Layer (server.py - FastAPI endpoints)
        ↓
Service Layer (exam_service, test_chat/service)
        ↓
Generator Layer (generater/make.py, ai_gen.py)
        ↓
Storage Layer (storage.py, exam_storage.py)
        ↓
Database (SQLite)
```

#### **주요 패턴**
- **RESTful API**: 표준 HTTP 메서드 사용
- **Dependency Injection**: FastAPI의 `Depends()` 활용
- **Repository 패턴**: `storage.py`, `exam_storage.py`
- **Async/Await**: 비동기 문제 생성 처리
- **Semaphore**: `_GEN_SEMAPHORE`로 동시 생성 제한 (최대 2개)

---

## 코딩 컨벤션

### Flutter/Dart

#### **네이밍 규칙**
```dart
// 클래스: PascalCase
class MainpageWidget extends StatefulWidget {}

// 변수/함수: camelCase
final List<Map<String, String>> menuItems = [];
void _onMenuItemPressed(String title) {}

// 상수: camelCase (Dart 권장)
static const String baseUrl = 'http://localhost:8000';

// Private 멤버: _ 접두사
String? _token;
bool _sending = false;
```

#### **파일 구조**
```dart
// 1. Imports (패키지 → 상대경로)
import 'package:flutter/material.dart';
import '../services/api_client.dart';

// 2. 클래스 정의
class MyWidget extends StatefulWidget {
  const MyWidget({super.key});
  
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

// 3. State 클래스
class _MyWidgetState extends State<MyWidget> {
  // 상태 변수
  bool _loading = false;

  // 생명주기 메서드
  @override
  void dispose() {
    // TextEditingController 등 리소스는 반드시 해제
    super.dispose();
  }
  
  // 비즈니스 로직 메서드
  Future<void> _loadData() async {}
  
  // 빌드 메서드
  @override
  Widget build(BuildContext context) {}
}
```

#### **위젯 빌드 패턴**
```dart
// 복잡한 위젯은 별도 메서드로 분리
Widget _buildHeader() {
  return Container(
    child: Text('Header'),
  );
}

// const 생성자 사용 (성능 최적화)
const Text('Static text')
const SizedBox(height: 12)
```

#### **에러 처리**
```dart
try {
  final response = await ApiClient.instance.createExam(...);
  // 성공 처리
} catch (error) {
  if (!mounted) return;  // 위젯이 dispose된 경우 체크
  setState(() {
    _loading = false;
  });
  _showMessage('오류 발생');
}
```

#### **네비게이션 패턴**
```dart
// 데이터 전달이 필요한 화면은 MaterialPageRoute + 생성자 전달
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => AppShell(token: token)),
);

// 단순 화면은 routes 테이블과 routeName 사용
routes: {
  LoginPage.routeName: (_) => const LoginPage(),
  SignupPage.routeName: (_) => const SignupPage(),
}
```

### Python/FastAPI

#### **네이밍 규칙**
```python
# 클래스: PascalCase
class ExamCreateRequest(BaseModel):
    pass

# 함수/변수: snake_case
def create_exam_handler():
    pass

exam_id = str(uuid.uuid4())

# 상수: UPPER_SNAKE_CASE
_GEN_SEMAPHORE = asyncio.Semaphore(2)

# Private: _ 접두사
def _resolve_items():
    pass
```

#### **타입 힌팅**
```python
# 모든 함수에 타입 힌트 사용
def get_quest(quest_id: str) -> Optional[Dict[str, Any]]:
    pass

# Pydantic 모델 활용
class ExamCreateRequest(BaseModel):
    ranges: List[RangeInput]
    difficulty_tier: int = Field(ge=1, le=5)
    question_count: int = Field(ge=1)
```

#### **비동기 처리**
```python
# async/await 일관성 있게 사용
async def _run_exam_generation(exam_id: str) -> None:
    update_exam_status(exam_id, "generating")
    items = get_exam_items(exam_id)
    
    # CPU 바운드 작업은 to_thread 사용
    storage_data = await asyncio.to_thread(
        make,
        hash_tags,
        solves_count,
        strategy_level,
        branch_conditions,
    )
```

#### **에러 처리**
```python
# HTTPException으로 명확한 에러 반환
if not payload.ranges:
    raise HTTPException(
        status_code=400, 
        detail="ranges must not be empty"
    )

# try-except로 예외 처리
try:
    items = plan_exam_items(...)
except ValueError as exc:
    raise HTTPException(status_code=400, detail=str(exc)) from exc
```

---

## API 설계 원칙

### 엔드포인트 구조

```
POST   /auth/anonymous              # 익명 토큰 발급
POST   /exams                        # 시험지 생성
GET    /exams/{exam_id}              # 시험지 상태 조회
GET    /exams/{exam_id}/pdf          # 시험지 PDF 다운로드
GET    /quests                       # 문제 검색/목록
POST   /quests/generate              # 문제 생성
POST   /test-chat/message            # 챗봇 메시지 전송
```

### 쿼리 파라미터
- `/exams/{exam_id}/pdf`: `inline`(0/1), `token`(헤더 없이 접근 시)
- `/quests`: `hash_tag`, `quest_id`, `text`, `page`, `page_size`

### 인증 방식
- **Bearer Token**: JWT 기반 인증
- `Authorization: Bearer <token>` 헤더 사용
- 익명 사용자도 토큰 발급 가능

### 요청/응답 형식
```json
// 요청 예시
POST /exams
{
  "ranges": [
    {"key": "math", "tags": ["미적분", "극한"]}
  ],
  "difficulty_tier": 3,
  "question_count": 5
}

// 응답 예시
{
  "exam_id": "uuid-string",
  "status": "queued"
}
```


### Flutter 구현 (`exam_preview_page.dart`)

```dart
// 첫 페이지 헤더 텍스트
const headerText = 'Powered By AIFlow | 수학영역 | 학번 | 이름';

// 큰 flow는 컬럼 전체(2행) 사용
final flowCount = item.flowCount ?? item.solvesCount;
final isLarge = flowCount > _largeFlowThreshold;

// 그리드 분할선은 컬럼 스팬 여부에 따라 표시
CustomPaint(
  painter: _GridPainter(
    splitLeft: !page.columnSpans[0],
    splitRight: !page.columnSpans[1],
  ),
);
```

### Python PDF 구현 (`pdf_builder.py`)

```python
# 그리드/헤더 설정
_GRID_COLUMNS = 2
_GRID_ROWS = 2
_LARGE_FLOW_THRESHOLD = 5
_HEADER_TEXT = "Powered By AIFlow | 수학영역 | 학번 | 이름"

def build_exam_pdf(items: List[Dict[str, object]]) -> bytes:
    if _REPORTLAB_AVAILABLE:
        return _build_reportlab_pdf(items)
    return _build_simple_pdf(items)
```

- `OMJ_PDF_FONT_PATH`가 있으면 해당 폰트를 사용하고, 없으면 OS 기본 폰트를 탐색합니다.
- `reportlab` 미설치 시 간단 PDF 빌더로 fallback 합니다.

### 페이지당 문제 배치

```dart
// Flutter (2x2 그리드 + 큰 flow는 컬럼 전체 사용)
List<_PageLayout> _layoutItems(List<ExamItem> items) {
  final pages = <_PageLayout>[];
  var entries = <_LayoutEntry>[];
  var columnSpans = [false, false];
  var occupied = [
    [false, false],
    [false, false],
  ];

  void flush() {
    if (entries.isNotEmpty) {
      pages.add(_PageLayout(entries: entries, columnSpans: columnSpans));
    }
    entries = <_LayoutEntry>[];
    columnSpans = [false, false];
    occupied = [
      [false, false],
      [false, false],
    ];
  }

  int? findFreeColumn() {
    for (var col = 0; col < 2; col++) {
      if (!occupied[col][0] && !occupied[col][1]) {
        return col;
      }
    }
    return null;
  }

  List<int>? findFreeSlot() {
    for (var col = 0; col < 2; col++) {
      for (var row = 0; row < 2; row++) {
        if (!occupied[col][row]) {
          return [col, row];
        }
      }
    }
    return null;
  }

  for (final item in items) {
    final flowCount = item.flowCount ?? item.solvesCount;
    final isLarge = flowCount > _largeFlowThreshold;

    if (isLarge) {
      var column = findFreeColumn();
      if (column == null) {
        flush();
        column = findFreeColumn() ?? 0;
      }
      entries.add(
        _LayoutEntry(
          item,
          column: column,
          row: 0,
          rowSpan: 2,
        ),
      );
      columnSpans[column] = true;
      occupied[column][0] = true;
      occupied[column][1] = true;
      continue;
    }

    var slot = findFreeSlot();
    if (slot == null) {
      flush();
      slot = findFreeSlot() ?? [0, 0];
    }
    entries.add(
      _LayoutEntry(
        item,
        column: slot[0],
        row: slot[1],
        rowSpan: 1,
      ),
    );
    occupied[slot[0]][slot[1]] = true;
  }

  if (entries.isNotEmpty) {
    pages.add(_PageLayout(entries: entries, columnSpans: columnSpans));
  }

  return pages;
}
```

```python
# Python
def _layout_items(items: List[Dict[str, object]]) -> List[Dict[str, object]]:
    pages: List[Dict[str, object]] = []
    entries: List[Dict[str, object]] = []
    column_spans = [False, False]
    occupied = [[False, False], [False, False]]

    def flush() -> None:
        nonlocal entries, column_spans
        if entries:
            pages.append(
                {
                    "entries": entries,
                    "column_spans": column_spans,
                }
            )
        entries = []
        column_spans = [False, False]
        occupied[:] = [[False, False], [False, False]]

    def find_free_column() -> int | None:
        for col in range(_GRID_COLUMNS):
            if not occupied[col][0] and not occupied[col][1]:
                return col
        return None

    def find_free_slot() -> tuple[int, int] | None:
        for col in range(_GRID_COLUMNS):
            for row in range(_GRID_ROWS):
                if not occupied[col][row]:
                    return col, row
        return None

    for item in items:
        flow_count = item.get("flow_count") or item.get("solves_count") or 0
        is_large = flow_count > _LARGE_FLOW_THRESHOLD
        if is_large:
            column = find_free_column()
            if column is None:
                flush()
                column = find_free_column() or 0
            entries.append(
                {
                    "item": item,
                    "col": column,
                    "row": 0,
                    "row_span": 2,
                }
            )
            column_spans[column] = True
            occupied[column][0] = True
            occupied[column][1] = True
            continue

        slot = find_free_slot()
        if slot is None:
            flush()
            slot = find_free_slot() or (0, 0)
        entries.append(
            {
                "item": item,
                "col": slot[0],
                "row": slot[1],
                "row_span": 1,
            }
        )
        occupied[slot[0]][slot[1]] = True

    if entries:
        pages.append(
            {
                "entries": entries,
                "column_spans": column_spans,
            }
        )
    return pages
```

---

## 데이터 모델

### ContentBlock (Flutter)
```dart
class ContentBlock {
  final String type;      // 'text' | 'latex'
  final String content;   // 실제 내용
  
  bool get isLatex => type == 'latex';
}
```

**용도**: 수학 문제의 텍스트와 LaTeX 수식을 구분하여 렌더링

### ContentBlock 파싱 (Flutter)

```dart
// content_block.dart
List<ContentBlock> parseContentBlocks(dynamic value) {
  if (value == null) {
    return [];
  }

  if (value is Map<String, dynamic>) {
    final blocksValue = value['blocks'];
    if (blocksValue is List) {
      return _parseBlockList(blocksValue);
    }
    if (value.containsKey('type') && value.containsKey('content')) {
      return [ContentBlock.fromMap(value)];
    }
  }
  
  if (value is List) {
    return _parseBlockList(value);
  }
  
  if (value is String) {
    if (value.isEmpty) {
      return [];
    }
    return [ContentBlock(type: 'text', content: value)];
  }
  
  return [ContentBlock(type: 'text', content: value.toString())];
}
```

### ContentBlock → 텍스트 변환 (Python)

```python
# pdf_builder.py
def _content_to_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, dict):
        blocks = value.get("blocks", [])
        return " ".join(
            block.get("content", "")
            for block in blocks
            if isinstance(block, dict) and block.get("content")
        )
    if isinstance(value, list):
        return " ".join(
            block.get("content", "")
            for block in value
            if isinstance(block, dict) and block.get("content")
        )
    if isinstance(value, str):
        if not value:
            return ""
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError:
            return value
        return _content_to_text(parsed)
    return str(value)
```

### Quest 데이터 구조 (Python)
```python
{
  "header": {
    "quest_id": "002/260120/22125366",
    "quest_model": {"models": ["gemini-vision"]}
  },
  "info": {
    "main": 4,
    "sub": ["미적분", "극한"],
    "hash_tag": ["미적분", "극한"],
    "flow_rate": 6,
    "difficulty": 9,
    "main_huddle": 2
  },
  "data": {
    "quest_title": {"blocks": [...]},
    "quest_image": null,
    "quest_answer": {"blocks": [...]}
  },
  "solves": [
    {
      "flow": {"blocks": [...]},
      "hash_tag": ["미적분"],
      "hint_riddle": {"blocks": [...]},
      "answer_riddle": {"blocks": [...]},
      "enter_huddle": 3,
      "branches": []
    }
  ]
}
```

---

## 주요 기능 구현 가이드

### 1. 새로운 페이지 추가

```dart
// 1. lib/pages/에 파일 생성
class NewPage extends StatefulWidget {
  const NewPage({super.key});
  
  @override
  State<NewPage> createState() => _NewPageState();
}

class _NewPageState extends State<NewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Page')),
      body: Container(),
    );
  }
}

// 2. 네비게이션 추가
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const NewPage()),
);
```

### 2. API 엔드포인트 추가

```python
# 1. Pydantic 모델 정의
class NewRequest(BaseModel):
    param1: str
    param2: int = Field(ge=1)

class NewResponse(BaseModel):
    result: str

# 2. 엔드포인트 구현
@app.post("/new-endpoint", response_model=NewResponse)
def new_endpoint_handler(
    payload: NewRequest,
    user_id: str = Depends(_get_user_id),
) -> NewResponse:
    # 비즈니스 로직
    result = process_data(payload.param1, payload.param2)
    return NewResponse(result=result)

# 3. Flutter에서 호출
Future<String> callNewEndpoint(String param1, int param2) async {
  final token = await _ensureToken();
  final uri = Uri.parse('$baseUrl/new-endpoint');
  final body = jsonEncode({'param1': param1, 'param2': param2});
  final response = await _client.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: body,
  );
  if (response.statusCode != 200) {
    throw Exception('Failed: ${response.statusCode}');
  }
  final payload = jsonDecode(response.body) as Map<String, dynamic>;
  return payload['result'] as String;
}
```

### 3. 문제 생성 로직 수정

```python
# omj/generater/make.py
def make(
    hash_tags: List[str],
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
    reference_quest_id: Optional[str] = None,
    strict_tags: bool = True,
) -> Dict[str, Any]:
    # 1. 태그 검증
    validate_tags(hash_tags)
    
    # 2. AI 문제 생성
    quest_data = generate_quest_with_ai(...)
    
    # 3. 풀이 생성
    solves = generate_solutions(...)
    
    # 4. 데이터 조립
    return assemble_quest_data(quest_data, solves)
```

---

## 테스트 가이드

### Flutter 위젯 테스트
```dart
// test/widget_test.dart
testWidgets('Counter increments smoke test', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  
  expect(find.text('0'), findsOneWidget);
  expect(find.text('1'), findsNothing);
  
  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();
  
  expect(find.text('0'), findsNothing);
  expect(find.text('1'), findsOneWidget);
});
```

### Python 유닛 테스트
```python
# tests/test_exam_service.py
import pytest
from exam_service import plan_exam_items

def test_plan_exam_items():
    ranges = [{"key": "math", "tags": ["미적분"]}]
    items = plan_exam_items(ranges, difficulty_tier=3, question_count=5)
    
    assert len(items) == 5
    assert all(item["difficulty_tier"] == 3 for item in items)
```

---

## 배포 가이드

### 백엔드 실행
```bash
cd omj
pip install -r requirements.txt
uvicorn server:app --host 0.0.0.0 --port 8000
```

### 프론트엔드 빌드
```bash
# 개발 모드
flutter run

# 웹 빌드
flutter build web

# Android APK
flutter build apk --release

# iOS (macOS 필요)
flutter build ios --release
```

### 환경 변수
```bash
# 백엔드
export OMJ_CORS_ORIGINS="*"  # CORS 설정
export OMJ_JWT_SECRET="dev-secret-change-me"  # JWT 서명 키
export OMJ_PDF_FONT_PATH="C:\\Windows\\Fonts\\malgun.ttf"  # PDF 한글 폰트 경로 (선택)

# 프론트엔드
flutter run --dart-define=API_BASE_URL=http://localhost:8000
flutter run --dart-define=API_LOGIN_PATH=/auth/login
flutter run --dart-define=API_REGISTER_PATH=/auth/register
```

---

## 성능 최적화

### Flutter
1. **const 생성자 사용**: 불변 위젯은 const로 선언
2. **ListView.builder 사용**: 긴 리스트는 lazy loading
3. **이미지 캐싱**: `CachedNetworkImage` 사용 고려
4. **불필요한 rebuild 방지**: `setState()` 범위 최소화

### Python
1. **비동기 처리**: I/O 바운드 작업은 async/await
2. **Semaphore 활용**: 동시 실행 제한으로 리소스 관리
3. **데이터베이스 인덱싱**: 자주 조회하는 컬럼에 인덱스
4. **캐싱**: 반복 조회 데이터는 메모리 캐싱

---

## 보안 고려사항

### 인증/인가
- JWT 토큰 기반 인증
- 모든 API 엔드포인트에 인증 필요 (익명 토큰 포함)
- 토큰 검증: `decode_token()` 함수 사용
- JWT 시크릿: `OMJ_JWT_SECRET` (없으면 기본값 사용)

### 입력 검증
```python
# Pydantic으로 자동 검증
class ExamCreateRequest(BaseModel):
    difficulty_tier: int = Field(ge=1, le=5)  # 1~5 범위
    question_count: int = Field(ge=1)         # 1 이상
```

### CORS 설정
```python
# 환경 변수로 허용 도메인 관리
_raw_origins = os.environ.get("OMJ_CORS_ORIGINS", "*")
```

---

## 문제 해결 가이드

### 자주 발생하는 이슈

#### 1. Flutter: "setState() called after dispose()"
```dart
// 해결: mounted 체크
if (!mounted) return;
setState(() {
  // 상태 업데이트
});
```

#### 2. Python: "Token missing in response"
```python
# 해결: 토큰 발급 확인
token = await _ensureToken()
```

#### 3. CORS 에러
```bash
# 해결: 환경 변수 설정
export OMJ_CORS_ORIGINS="http://localhost:3000,https://example.com"
```

#### 4. PDF 생성 실패
```python
# 해결: pdf_builder 모듈 확인
if build_exam_pdf is None:
    raise HTTPException(status_code=500, detail="PDF builder not available")
```

---

## LaTeX 렌더링 가이드

### Flutter에서 LaTeX 렌더링

`flutter_math_fork` 패키지를 사용하여 수학 수식을 렌더링합니다.

#### ContentBlocksView 위젯 사용

기본은 `inline: true`로 `Text.rich`를 사용하고, `inline: false`면 블록 단위로 렌더링합니다.

```dart
// widgets/content_blocks_view.dart
import 'package:flutter_math_fork/flutter_math.dart';

class ContentBlocksView extends StatelessWidget {
  final List<ContentBlock> blocks;
  final TextStyle? textStyle;
  final TextStyle? latexStyle;
  final double spacing;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final effectiveTextStyle =
        textStyle ?? DefaultTextStyle.of(context).style;
    final effectiveLatexStyle = latexStyle ?? effectiveTextStyle;

    if (inline) {
      final spans = <InlineSpan>[
        for (final block in blocks)
          block.isLatex
              ? WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Math.tex(block.content, textStyle: effectiveLatexStyle),
                )
              : TextSpan(text: block.content),
      ];
      return Text.rich(TextSpan(style: effectiveTextStyle, children: spans));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks
          .map((block) => block.isLatex
              ? Math.tex(block.content, textStyle: effectiveLatexStyle)
              : Text(block.content, style: effectiveTextStyle))
          .toList(),
    );
  }
}
```

#### 시험지 미리보기에서 사용

```dart
// exam_preview_page.dart
Widget _buildCell(ExamItem item) {
  final titleBlocks = parseContentBlocks(item.questTitle);
  final displayTitleBlocks = titleBlocks.isEmpty
      ? [const ContentBlock(type: 'text', content: 'Generating...')]
      : titleBlocks;
  final flowCount = item.flowCount ?? item.solvesCount;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Q${item.itemIndex} (${flowCount} flows)',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: ClipRect(
          child: ContentBlocksView(
            blocks: displayTitleBlocks,
            textStyle: const TextStyle(fontSize: 12),
            latexStyle: const TextStyle(fontSize: 12),
            spacing: 2,
          ),
        ),
      ),
    ],
  );
}
```

### PDF에서 LaTeX 처리

PDF에서는 LaTeX를 직접 렌더링하지 않고 ContentBlock의 텍스트만 출력합니다.

```python
# pdf_builder.py
def _content_to_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, dict):
        blocks = value.get("blocks", [])
        return " ".join(
            block.get("content", "")
            for block in blocks
            if isinstance(block, dict) and block.get("content")
        )
    if isinstance(value, list):
        return " ".join(
            block.get("content", "")
            for block in value
            if isinstance(block, dict) and block.get("content")
        )
    if isinstance(value, str):
        if not value:
            return ""
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError:
            return value
        return _content_to_text(parsed)
    return str(value)
```

### 지원되는 LaTeX 문법

`flutter_math_fork`에서 지원하는 주요 LaTeX 문법:

| 문법 | 설명 | 예시 |
|------|------|------|
| `\frac{a}{b}` | 분수 | $\frac{1}{2}$ |
| `x^{n}` | 위 첨자 | $x^2$ |
| `x_{n}` | 아래 첨자 | $x_1$ |
| `\sqrt{x}` | 제곱근 | $\sqrt{2}$ |
| `\sum` | 합계 | $\sum_{i=1}^{n}$ |
| `\int` | 적분 | $\int_{a}^{b}$ |
| `\lim` | 극한 | $\lim_{x \to 0}$ |
| `\alpha, \beta` | 그리스 문자 | $\alpha, \beta$ |

### 에러 처리

```dart
// ContentBlocksView uses Math.tex directly; add try/catch if needed.
Math.tex(
  block.content,
  textStyle: effectiveLatexStyle,
);
```

---

## 캐릭터 챗봇 시스템

### 개요

캐릭터 챗봇은 소크라테스식 질문을 사용하는 AI 과외 선생님 캐릭터입니다. Gemini API(comet API 경유)를 사용하여 학생의 사고를 이끌어내는 대화를 생성합니다.

### 아키텍처

```
Flutter UI (character_chat_debug_page.dart)
        ↓
ApiClient.sendTestChatMessage()
        ↓
POST /test-chat/message
        ↓
test_chat/service.py → build_test_chat_response()
        ↓
Gemini API (gemini-2.5-flash-lite)
```

### 핵심 파라미터

| 파라미터 | 타입 | 범위 | 설명 |
|---------|------|------|------|
| `affection` | int | 1~255 | 호감도 (256 금지) |
| `attendance_days` | int | 1+ | 연속 출석일수 |
| `quest_id` | string? | - | 선택된 문제 ID |
| `problem_number` | string? | - | 문제번호 (선택) |
| `solution_notes` | string? | - | 풀이 내역 (선택) |
| `learning_ratings` | Map<string, int> | 0~256 | 태그별 학습 Rating |
| `recent_pairs` | List | - | 최근 대화 쌍 (`{user, assistant}`) |

### 출석 프로필 시스템

출석일수에 따라 대화 방식이 달라집니다:

```python
# test_chat/service.py
def _attendance_profile(days: int) -> Tuple[str, str]:
    if days <= 7:
        return ("1~7일", "출석이 막 시작된 단계다. 칭찬을 자주하고 질문은 짧게 이어간다.")
    if days <= 14:
        return ("8~14일", "습관이 형성되는 단계다. 핵심 근거를 한 줄로 설명하게 유도한다.")
    if days <= 30:
        return ("15~30일", "안정화 단계다. 풀이 과정을 스스로 말하게 하고 흐름을 점검한다.")
    return ("30일 이상", "장기 지속 단계다. 반례나 일반화를 질문해 사고 범위를 넓힌다.")
```

```dart
// Flutter에서도 동일한 로직 사용
String _attendanceLabel(int days) {
  if (days <= 7) return '1~7일';
  if (days <= 14) return '8~14일';
  if (days <= 30) return '15~30일';
  return '30일 이상';
}
```

### 프롬프트 구성

프롬프트는 다음 순서로 구성됩니다:

```python
def _build_prompt(...) -> str:
    sections = [
        PERSONA_PROMPT,
        "규칙: 256 만점은 금지이며 호감도는 1~255 범위로 유지한다.",
        f"호감도: {affection}/256",
        f"연속 출석일수: {attendance_days}일 ({attendance_label})",
        attendance_prompt,
    ]
    
    if quest_id or quest_title or quest_tags:
        quest_lines = ["문제 정보:"]
        if quest_id:
            quest_lines.append(f"- quest_id: {quest_id}")
        if quest_title:
            quest_lines.append(f"- 제목: {quest_title}")
        if quest_tags:
            quest_lines.append(f"- 해시태그: {', '.join(quest_tags)}")
        if learning_ratings:
            ratings = ", ".join(
                f"{tag}={score}" for tag, score in sorted(learning_ratings.items())
            )
            quest_lines.append(
                f"- 학습 Rating(질문 시에만 참고): {ratings}"
            )
        if problem_number or solution_notes:
            quest_lines.append(
                "- 문제풀이데이터: "
                f"문제번호={problem_number or '미입력'}, "
                f"풀이내역={solution_notes or '미입력'}"
            )
        quest_lines.append(
            "문제를 가져온 뒤에는 반드시 소크라테스식 되묻기를 포함한다."
        )
        sections.append("\n".join(quest_lines))
    
    if pair_summary:
        sections.append(f"직전 페어 요약: {pair_summary}")
    
    sections.append(f"사용자 질문: {user_message}")
    sections.append(
        "응답은 짧고 명확하게. 마지막 문장은 반드시 되묻는 질문으로 끝낸다."
    )
    
    return "\n\n".join(section for section in sections if section)
```

### 페어 요약 시스템

최근 대화를 요약하여 컨텍스트 유지:

```python
# 상수
PAIR_SUMMARY_MIN_CHARS = 40   # 최소 문자 수
SUMMARY_SNIPPET_LIMIT = 80    # 요약 최대 길이

def _summarize_last_pair(pairs: List[Dict]) -> Optional[str]:
    if not pairs:
        return None
    last_pair = pairs[-1]
    user = last_pair.get("user")
    assistant = last_pair.get("assistant")
    
    if len(user) + len(assistant) < PAIR_SUMMARY_MIN_CHARS:
        return None
    
    return f"사용자: {_compact(user, 80)} / AI: {_compact(assistant, 80)}"
```

```dart
// Flutter에서 페어 구성
List<Map<String, String>> _buildRecentPairs() {
  final pairs = <Map<String, String>>[];
  String? pendingUser;
  
  for (final message in _messages) {
    if (message.isUser) {
      pendingUser = message.text;
    } else if (pendingUser != null) {
      pairs.add({'user': pendingUser, 'assistant': message.text});
      pendingUser = null;
    }
  }
  
  return pairs.isEmpty ? [] : [pairs.last];  // 마지막 페어만 전송
}
```

### 학습 Rating 시스템

태그별 학습 점수를 관리하여 맞춤형 피드백 제공:

```dart
// Flutter - 태그별 Rating 슬라이더
Widget _buildRatingSlider(String tag) {
  final rating = _learningRatings[tag] ?? 0;
  return Slider(
    value: rating.toDouble(),
    min: 0,
    max: 256,
    divisions: 256,
    onChanged: (value) {
      setState(() {
        _learningRatings[tag] = value.round();
      });
    },
  );
}
```

```python
# Python - Rating 정규화
def _normalize_ratings(raw: Dict[str, Any]) -> Dict[str, int]:
    normalized = {}
    for tag, score in raw.items():
        tag_text = str(tag).strip()
        if not tag_text:
            continue
        value = _clamp_int(score, 0, 256)
        normalized[tag_text] = value
    return normalized
```

### 토큰 추정

```python
def _estimate_tokens(text: str) -> int:
    """한글 기준 대략적인 토큰 수 추정"""
    if not text:
        return 0
    return max(1, int(math.ceil(len(text) / 4)))
```

### API 응답 모델

```dart
// Flutter
class TestChatResponse {
  final String assistantMessage;
  final String? pairSummary;
  final String prompt;
  final int inputTokenEstimate;
  final int outputTokenEstimate;
  final int totalTokenEstimate;
}
```

```python
# Python
class TestChatMessageResponse(BaseModel):
    assistant_message: str
    pair_summary: Optional[str] = None
    prompt: str
    input_token_estimate: int
    output_token_estimate: int
    token_estimate: int
```

### 환경 변수

```bash
# Gemini API (comet API 경유, 문제 생성/챗봇 공통)
export COMETAPI_KEY="your-api-key"
```

### UI 구성 (character_chat_debug_page.dart)

```dart
// 주요 상태 변수
double _affection = 120;
double _attendanceDays = 7;
bool _sending = false;
int _currentInputTokens = 0;
int _currentOutputTokens = 0;
int _totalInputTokens = 0;
int _totalOutputTokens = 0;
String? _pairSummary;
String _promptPreview = '';
String? _selectedQuestId;
String? _selectedQuestTitle;
List<String> _selectedQuestTags = [];
Map<String, int> _learningRatings = {};
final TextEditingController _problemNumberController = TextEditingController();
final TextEditingController _solutionNotesController = TextEditingController();
final TextEditingController _chatInputController = TextEditingController();
final List<_ChatMessage> _messages = [];

// 내부 메시지 클래스
class _ChatMessage {
  final String text;
  final bool isUser;
  const _ChatMessage({required this.text, required this.isUser});
}
```

---

## 추가 리소스

### 문서
- [Flutter 공식 문서](https://flutter.dev/docs)
- [FastAPI 공식 문서](https://fastapi.tiangolo.com/)
- [Dart 스타일 가이드](https://dart.dev/guides/language/effective-dart/style)
- [PEP 8 - Python 스타일 가이드](https://peps.python.org/pep-0008/)

### 주요 패키지
- `google_fonts`: 구글 폰트 사용
- `flutter_slidable`: 슬라이드 액션 UI
- `flutter_math_fork`: LaTeX 수식 렌더링
- `http`: HTTP 클라이언트
- `url_launcher`: 외부 링크/PDF 열기
- `google-genai`: Gemini 호출
- `pyjwt`: JWT 인코딩/디코딩
- `reportlab`: PDF 생성
- `pydantic`: 데이터 검증
- `fastapi`: 웹 프레임워크

---

## 버전 관리

### Git 커밋 메시지 규칙
```
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 수정
style: 코드 포맷팅
refactor: 코드 리팩토링
test: 테스트 코드
chore: 빌드/설정 변경
```

### 브랜치 전략
```
main        - 프로덕션 배포
develop     - 개발 통합
feature/*   - 기능 개발
hotfix/*    - 긴급 수정
```

---

## 연락처 및 기여

프로젝트에 기여하거나 문의사항이 있으시면 이슈를 등록해주세요.

**마지막 업데이트**: 2026년 2월 2일
