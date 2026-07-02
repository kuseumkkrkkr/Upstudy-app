# s11_teacher 프로젝트 설명서

## 개요

`s11_teacher`는 **s11 학생 앱**의 교사용 관리 앱입니다.  
같은 백엔드를 공유하며, 교사 전용 UI로 **코스/교재 생성**, **시험지 생성**, **문항 제작/변형** 기능을 제공합니다.

- **위치**: `C:\Users\82102\Desktop\s11_teacher`
- **플랫폼**: Flutter (Android / iOS / Web / Desktop)
- **SDK**: `>=3.9.0`
- **빌드 상태**: ✅ `flutter build apk --debug` 성공 (0 errors)

---

## 프로젝트 구조

```
s11_teacher/
├── lib/
│   ├── main.dart                          # 진입점 (TeacherApp, 라우트 정의)
│   ├── models/                            # 학생 앱에서 복사한 모델
│   │   ├── concept_textbooks.dart
│   │   ├── content_block.dart
│   │   ├── course.dart
│   │   └── textbook.dart
│   ├── pages/                             # 핵심 화면
│   │   ├── auth_wrapper.dart              # 인증 게이트 (로그인 상태 확인)
│   │   ├── teacher_login_page.dart        # 교사 로그인 (이메일/비밀번호)
│   │   ├── teacher_register_page.dart     # 교사 회원가입
│   │   ├── teacher_dashboard_page.dart    # 대시보드 (메뉴)
│   │   ├── course_builder_page.dart       # 코스/교재 생성 (API 연동)
│   │   ├── exam_paper_builder_page.dart   # 시험지 생성 + PDF 다운로드
│   │   └── problem_editor_page.dart       # 문항 제작/변형 (로컬 저장 + tray)
│   ├── services/                          # API + 로컬 저장
│   │   ├── api_client.dart                # 확장된 ApiClient (익명 + 교사 인증)
│   │   ├── auth_storage.dart              # JWT 토큰 + username + role 저장
│   │   ├── course_service.dart            # 코스 관련 로직
│   │   ├── local_db*.dart                 # 플랫폼별 로컬 DB
│   │   └── textbook_store.dart            # 교재 저장소
│   └── widgets/
│       ├── content_blocks_view.dart
│       └── design_tokens.dart
├── test/
│   └── widget_test.dart                   # TeacherApp 위젯 테스트
├── pubspec.yaml                           # 의존성: http, url_launcher, flutter_inappwebview, shared_preferences
└── README.md
```

---

## 의존성 (pubspec.yaml)

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `http` | `^1.2.2` | REST API 통신 |
| `url_launcher` | `^6.3.0` | PDF 다운로드 (외부 브라우저) |
| `flutter_inappwebview` | `^6.1.5` | 웹뷰 (학생 앱과 동일) |
| `shared_preferences` | (내장) | JWT 토큰 / username / role 저장 |

---

## 인증 시스템

### 흐름

1. **앱 시작** → `AuthWrapper`가 `ApiClient.instance.isAuthenticated()` 호출
2. **인증된 교사** (`token` 있음 + `role == 'teacher'`) → `TeacherDashboardPage`
3. **미인증** → `TeacherLoginPage` (메시지: "로그인이 필요합니다.")
4. **게스트 로그인** → 익명 JWT 발급 (`/auth/anonymous`) → 대시보드 진입

### 화면

| 화면 | 라우트 | 설명 |
|------|--------|------|
| AuthWrapper | `/` | 인증 상태 확인 후 분기 |
| TeacherLoginPage | `/login` | 이메일/비밀번호 로그인 + 게스트 로그인 |
| TeacherRegisterPage | `/register` | 이메일/비밀번호/이름 회원가입 |

### ApiClient 인증 메서드

| 메서드 | 엔드포인트 | 설명 |
|--------|-----------|------|
| `loginTeacher(email, password)` | `POST /auth/teacher/login` | 로그인 + JWT 저장 |
| `registerTeacher({email, password, name})` | `POST /auth/teacher/register` | 회원가입 |
| `logoutTeacher()` | - | 토큰/role 삭제 |
| `isAuthenticated()` | - | `token != null && role == 'teacher'` |
| `requireToken()` | `POST /auth/anonymous` | 익명 JWT (게스트용) |

### AuthStorage

```dart
// 저장
await AuthStorage.instance.saveToken(token, username: '홍길동', role: 'teacher');

// 읽기
final token = await AuthStorage.instance.readToken();
final role = await AuthStorage.instance.readRole();

// 삭제
await AuthStorage.instance.clear();
```

---

## API 연동 현황

### 사용 중인 백엔드 엔드포인트

| 엔드포인트 | 메서드 | 사용 페이지 | 상태 |
|-----------|--------|-----------|------|
| `/auth/teacher/login` | POST | TeacherLoginPage | ✅ 교사 로그인 |
| `/auth/teacher/register` | POST | TeacherRegisterPage | ✅ 교사 회원가입 |
| `/auth/anonymous` | POST | 전체 (게스트) | ✅ 익명 JWT 발급 |
| `/courses/hash-tags` | GET | CourseBuilderPage | ✅ 해시태그 목록 로드 |
| `/courses` | POST | CourseBuilderPage | ✅ 코스 생성 |
| `/textbooks` | GET | CourseBuilderPage | ✅ 기존 교재 목록 |
| `/textbooks` | POST | CourseBuilderPage | ✅ 신규 교재 생성 |
| `/exams` | POST | ExamPaperBuilderPage | ✅ 시험지 생성 |
| `/exams/{id}/status` | GET | ExamPaperBuilderPage | ✅ 생성 상태 폴링 |
| `/exams/{id}/pdf` | GET | ExamPaperBuilderPage | ✅ PDF 다운로드 URL |

### 미연동 (백엔드 미지원)

| 기능 | 이유 | 현재 동작 |
|------|------|----------|
| 개별 문제 편집 모드 | 백엔드에서 제거됨 | 사용하지 않음 |

---

## 주요 화면 상세

### 1. TeacherLoginPage (`/login`)
- **이메일/비밀번호** 입력 + 유효성 검사
- **로그인** → `ApiClient.instance.loginTeacher()` → 성공 시 `/` 이동
- **게스트 로그인** → 익명 JWT → `/` 이동
- **회원가입 링크** → `/register` 이동
- 에러 메시지: 인증 실패 / 네트워크 오류 / 기타

### 2. TeacherRegisterPage (`/register`)
- **이름/이메일/비밀번호/비밀번호 확인** 입력 + 유효성 검사
- **회원가입** → `ApiClient.instance.registerTeacher()` → 성공 시 로그인 페이지로 돌아감
- **로그인 링크** → 이전 페이지로 이동

### 3. TeacherDashboardPage (`/dashboard`)
- 3개 카드 메뉴: **코스 만들기**, **시험지 만들기**, **문항 제작**
- 각 카드 탭 시 해당 페이지로 이동

### 4. CourseBuilderPage (`/course-builder`)
- **4개 탭**: 기본 정보 / 챕터 / 해시태그 / 미리보기
- **기존 교재 선택**: `listTextbooks()` 드롭다운 + 토글 스위치
- **해시태그**: `getCourseHashTags()` 로드 → 칩 + 다이얼로그 + 직접 입력
- **저장 로직**:
  - 기존 교재 선택 시 → `_selectedTextbookId` 재사용 → `createCourse()`
  - 신규 교재 시 → `createTextbook()` → `createCourse()`

### 5. ExamPaperBuilderPage (`/exam-builder`)
- 시험지 설정 (과목, 학년, 문제 수, 난이도)
- `createExam()` → `_examId` 수신
- `getExamStatus()` 폴링로 상태 확인
- PDF 완료 시 `url_launcher`로 외부 브라우저 열기 (모바일) / 데스크톱은 스낵바 + URL 표시

### 6. ProblemEditorPage (`/problem-editor`)
- 문항 초안, 해시태그, base quest 기준 변형, MCQ 변환
- **유효성 검사**: 필수 base quest/태그 누락, 빈 flow 노드 입력 방지
- 결과는 tray에 저장되고, 개별 문제 편집 모드는 제공하지 않음
- 기본 생성 모드 2개만 유지

---

## 빌드 방법

```bash
# APK (Debug)
flutter build apk --debug

# APK (Release)
flutter build apk --release

# Web
flutter build web
```

---

## 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `API_BASE_URL` | `http://localhost:8000` | 백엔드 API 주소 |

```bash
# 예: 빌드 시 주입
flutter build apk --debug --dart-define=API_BASE_URL=https://api.example.com
```

---

## 알려진 이슈

| 이슈 | 심각도 | 설명 |
|------|--------|------|
| 11개 info/warning | 낮음 | 학생 앱 복사 파일의 deprecation, style 경고 |
| `_SectionDraft.imageCtrls` | 낮음 | 생성자에서 초기화 누락 (기본 빈 리스트로 동작) |
| 개별 문제 편집 | 낮음 | 제거됨, `flow_draft`/`prompt_note`만 유지 |
| 교사 인증 백엔드 | 중간 | `/auth/teacher/login`, `/auth/teacher/register` 엔드포인트 필요 |

---

## 완료된 작업

### Phase 3 (API 연동)
- [x] `ApiClient` 확장: `getCourseHashTags()`, `createCourse()`
- [x] CourseBuilderPage API 연동 (교재 선택 + 해시태그 + 저장)
- [x] ExamPaperBuilderPage PDF 다운로드 (`url_launcher`)
- [x] ProblemEditorPage 문항 제작/변형 정리
- [x] 위젯 테스트 수정 (`MyApp` → `TeacherApp`)
- [x] 미사용 import 정리
- [x] 빌드 성공 확인 (0 errors)

### Phase 4 (교사 인증)
- [x] `TeacherLoginPage` UI (이메일/비밀번호 + 게스트 + 회원가입 링크)
- [x] `TeacherRegisterPage` UI (이름/이메일/비밀번호/확인 + 유효성 검사)
- [x] `AuthWrapper` 인증 게이트 (토큰 + role 확인)
- [x] `ApiClient` 교사 인증 메서드 (`loginTeacher`, `registerTeacher`, `logoutTeacher`, `isAuthenticated`)
- [x] `AuthStorage` role 저장/읽기 지원
- [x] `main.dart` 라우팅 업데이트 (`/`, `/login`, `/register`, `/dashboard`, ...)
- [x] 통합 및 빌드 검증 완료

---

## 향후 가능한 개선

1. **백엔드 `POST /quests`**: 수동 문제 생성 API 추가 시 즉시 연동 가능 (페이로드 준비 완료)
2. **고급 UI 폴리시**: 애니메이션, 로딩 상태, 에러 핸들링 개선
3. **코드 재사용 정리**: 학생 앱과 공통 모델/서비스 패키지 분리
4. **비밀번호 찾기**: "Forgot Password?" 링크 기능 구현

---

*작성일: 2026-05-16*  
*버전: Phase 4 완료 (교사 인증 시스템)*
