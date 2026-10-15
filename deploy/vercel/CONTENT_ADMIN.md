# 내부 콘텐츠 관리 — 별도 관리자 DB

2026-10-15 사용자 변경 지시: 기존 학생 계정 DB를 관리자 인증에 사용하지 않는다. 관리자의 ID·PW는 바탕화면 텍스트 파일로 전달한다. 이전 학생 admin membership 방식은 폐기했다.

## 실제 분리

- 학생 DB: 기존 `aybqetiydxafeuzudltb`. 이번 관리자 설정으로 수정하지 않는다.
- 새 무료 프로젝트: `aiflow-admin-canary`, ref `ekogkwhvyqwdxibjfnko`, Tokyo. 대시보드 Healthy 확인.
- 새 프로젝트에서 `supabase_content_admin.sql` 적용 성공. 계정, 로그인 요청 제한, 콘텐츠, 변경 원장이 모두 별도 DB 안에 있다. 스키마도 기존 `canary_users`가 발견되면 적용을 거부한다.
- 기본 새 테이블 공개 off, 자동 RLS on. 모든 관리자 테이블에서 public/anon/authenticated 권한 회수. 서버 키만 사용한다.

## 설정

Vercel 서버 전용 환경 변수:

| 변수 | 의미 |
|---|---|
| `ADMIN_SUPABASE_URL` | 학생 DB와 다른 프로젝트 HTTPS 주소 |
| `ADMIN_SUPABASE_SERVICE_ROLE_KEY` | 별도 DB 전용 서버 키, Flutter에 배포 금지 |
| `ADMIN_JWT_SECRET` | 32자 이상 독립 비밀값, 학생 JWT secret과 같은 값 금지 |
| `CONTENT_ADMIN_API_KEY_SHA256` | 관리자 전용 API 키의 SHA-256, 원문 키는 브라우저 입력용 |
| `CONTENT_ADMIN_ENABLED=true` | 명시적 활성화 전에는 접근 거부 |

주소 host 또는 서버 키가 학생 DB와 같으면 연결을 거부한다. 설정 누락 시 기존 학생 DB로 fallback하지 않는다. 관리자 계정 비밀번호는 PBKDF2-SHA256 600,000회 해시로만 저장한다. 관리자 JWT는 독립 서명·issuer·audience, 30분 만료이며 active/session_version을 매 요청 재확인한다. 학생 JWT로 관리자 API, 관리자 JWT로 학생 API를 사용할 수 없다.

`tools/create_content_admin_account.ps1`은 별도 DB에만 계정을 만든다. 기존 학생 가입/로그인 API를 호출하지 않고, 기존 별도 admin 계정도 덮어쓰지 않는다. 생성 자격증명은 D: private 디렉터리에 DPAPI 암호화로 보관하고 DB 저장 확인 후 바탕화면 `AIFlow 관리자 로그인.txt`에 ID·PW를 기록한다. 사용자의 명시 요청에 따른 평문 파일이며 현재 Windows 사용자만 파일 ACL을 허용한다. 서버 DB 키·JWT secret은 이 파일에 넣지 않는다. 파일이 이미 있으면 덮어쓰지 않는다.

## 화면/API

관리자 API 키는 ID/PW 텍스트 파일과 분리해 DPAPI 암호화 파일에 보관한다. 현재 Windows 사용자만 D: hotfix 루트에서 `& .\tools\copy_content_admin_api_key.ps1`을 명시적으로 실행해 클립보드로 복사할 수 있다. 사용 후 클립보드를 비운다. `build/temp/private-content-admin`은 빌드 임시물 일괄 정리 전에 반드시 별도로 보존해야 하는 자격증명 백업이다.

| 책임 단위 | 입력/수명 | 결과·실패 처리 |
|---|---|---|
| admin.js `confirmArchive` | 목록 row, 열린 dialog 동안 | 확인만 기존 멱등 DELETE; 취소/Escape 무변경, 포커스 복귀 |
| admin.js `token`/`apiKey` | 관리자 로그인 응답/직접 입력, 탭 메모리 | 로그아웃·새로고침 소거, 저장소·URL에 넣지 않음 |
| admin.js `pending` | 요청 경로/본문/키, 응답 불명 동안 | 동일 요청 키 유지, 다른 요청으로 덮어쓰기 거부 |
| `copy_content_admin_api_key.ps1` | 로컬 DPAPI 파일, 사용자 실행 한 번 | 클립보드 복사만; 키 원문 출력 없음, 복호화 실패 시 중단 |

`/admin`에서 별도 관리자 로그인과 전용 API 키를 입력한다. 자격증명은 탭 메모리에만 유지하며 localStorage/sessionStorage/URL에 넣지 않는다. `/admin/api/login`도 API 키가 필요하고 DB의 원자적 카운터로 계정당 5분/10회 제한한다. 역할 상승이나 공개 가입 API는 없다.

모든 `/admin/api/content` 경로는 관리자 JWT와 `X-Admin-Api-Key`가 모두 필요하다. 쓰기는 `X-Idempotency-Key`(1~160자)가 추가로 필요하다.

| API | 계약 |
|---|---|
| GET `/admin/api/content` | 번들+별도 DB 콘텐츠, version/archived |
| PUT `/admin/api/content/{id}` | id/kind/title/description/grade_band/difficulty/problem_ids/version |
| DELETE `/admin/api/content/{id}?version=N` | 보관 처리, 학생 보유·진도 유지 |
| POST `/admin/api/content/{id}/restore?version=N` | 공개 목록 복원 |

kind는 course/exam/problem_set. canonical 문항 ID만 연결, 가격 무료 고정. 공개 후 문항 구성·종류 변경은 새 ID로 등록한다. 코스는 문항별 problem_solve 모듈을 만든다. 학생 앱의 보유 기록은 기존 학생 DB에 그대로 두고, 콘텐츠 추가/보관 원장은 별도 관리자 DB에서 읽는다. 읽기 실패를 빈 데이터나 번들로 숨기지 않는다.

`admin_write_content` SQL은 별도 admin 계정 active 검사, 기대 version, idempotency key, 감사 기록을 단일 트랜잭션에서 처리한다. 보관/복원 지문에는 서버 재조회 메타데이터를 넣지 않아 후속 편집 후 재시도도 최초 결과를 반환한다. 원장 직접 쓰기 권한은 service_role에서도 회수하고 RPC만 허용한다.

## 검증 경계

API 단위/회귀 테스트는 실제 분리된 DB의 동시성 또는 배포 UI 검증을 대체하지 않는다. 실제 계정 등록, DB RPC·RLS·충돌·재시도, Vercel 서버 변수 설정, 관리자 UI 로그인/CRUD를 각각 확인한다. 실제 적용·검증 결과는 `design/student/audits/2026-10-15-library-admin.md`를 따른다.
