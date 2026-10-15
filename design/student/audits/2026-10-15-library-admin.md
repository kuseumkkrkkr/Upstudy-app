# 자료실/책가방·더보기·관리자 작업 체크포인트

- 작업 경로: `D:\AIFlow-Workspace\Projects\Aiflow\Upstudy-hotfix`, `hotfix`.
- 시작 HEAD: `87cc9a00fb274377b847802cb9e0c9853757fb66`. 기존 다수 미커밋 수정 보존. 다른 브랜치/작업본 사용 안 함.
- 기준 HTML SHA256: `EF8F6E40D01B099631C1940628E623A6113E1ADA68CFF3DEC0F1F89DEFCD0868` 확인.
- 사용자 새 지시 우선: 기본 자료실 탭→책가방, 더보기 학습 탭의 자료실→마켓. 학습8/도구7/내 메뉴7(데모 on) 분류. 높이는 항목 수 기반, 화면이 짧을 때만 제한/스크롤 fallback.
- 시험지 누락 원인: 책가방이 ExamPaperStore 열람 이력만 사용. 보유 API 시험지와 합치고 asset ID 중복 제거. 시험지 분류 조회는 교재/북마크 장애와 독립. 계정 scope/epoch와 오래된 열기 콜백 거부 유지.
- 관리자 `/admin` 및 `/admin/api/content`: 기존 인증 + DB admin membership + 전용 키 hash 검증. 기본 비활성. SQL 버전/멱등/트랜잭션, soft archive/restore 및 감사 기록 구현. 적용 절차/함수·변수는 `deploy/vercel/CONTENT_ADMIN.md`.

## 검증

- API 전체 `python -m pytest tests -q`: 239 passed, 기존 경고82. 새 관리자 테스트5 포함. 실제 PostgreSQL 동시성 시험은 **미실행**.
- Flutter 집중4파일: 13 passed. 더보기 목적지/가변 높이, 보유 시험지 행/계정 교체, 책가방 390·780·1280 리더 연결 및 셸 확인.
- 중간 실패 원인과 수정: 새 보유 API mock 누락을 계약에 추가, 기존 모바일 뒤로 tooltip 이름 불일치 보완, 자료 추가로 바뀐 목록의 첫 항목을 무조건 누르던 테스트를 지정 교재 행 선택으로 변경. 실패 검사 삭제/실제 오류에 맞춘 기대값 축소 없음.
- 집중 analyze 4파일: 오류0이나 docx_box.dart 기존 unused/스타일 경고·info 합38. 전체 analyze 성공이라고 보고하지 않음.
- D: Flutter release build 성공124.7초, 기존 CupertinoIcons 경고. API_BASE_URL 지정 canary, STUDENT_SERVICES_DEMO=true, STUDENT_STORE_DEMO=true.
- `build/web`→`public` 동기화. 이전 public은 삭제하지 않고 `build/temp/public-before-library-20261015`로 보존.
- main.dart.js SHA256 `B79EFC41F78556A12D3CFC1337CB1FFF6E28AE6AD9F91D378F33DAC3E38411DE`, 7,114,524 bytes.
- 실제 브라우저 1280×720: 더보기 자료실→`/#/marketplace`, 기본 자료실→`/#/bookbag` 확인. 로컬 origin에는 인증 계정이 없으므로 실제 보유 학생 데이터 검증은 미실행. 시험지 행은 위젯 계약 fixture로 검증한 범위임.
- 브라우저 viewport capability는 크기에 반영되지 않아 390 모바일 증거로 쓰지 않음. CDP device metrics 적용 후 실제 innerWidth390/innerHeight844/DPR≈1 확인, 원본 Page.captureScreenshot로 모바일 캡처. 검수 후 override 해제.
- 전후 이미지: `evidence/2026-10-15-library-admin/html-more.png`, `dart-before-more.png`, `dart-after-more.png`(1280×720). 모바일 `dart-after-more-learning-390.png`, `dart-after-more-my-390.png`.
- 관리자 연결 폼 렌더 확인: `admin-locked.png`. 인증된 관리자 CRUD 브라우저 검증은 아직 하지 않음.

## 남은 항목 / 재개

### 후속 재시도 경계 점검

- 보관 성공→다른 관리자 제목 변경→원래 보관 재시도에서 409를 재현했다. 서버 재조회 payload가 아니라 HTTP 요청의 id/version/operation으로 멱등 지문을 계산하도록 수정하고 회귀 테스트를 추가했다.
- 코스 등록 목록/정렬은 보유 항목마다 DB 원장을 읽던 부분을 요청당 한 번으로 변경했다. 호출 횟수 검사 추가. 기존 미추적 `test_vercel_course_order.py`의 mock도 새 조회 경계에 맞춰 수정했으나 이전 사용자 파일 전체를 함께 커밋하지 않는다.
- API 전체 재실행: **241 passed**, 기존 경고82. 실제 PostgreSQL 검증으로 대체하지 않는다.
- 로컬 Docker Desktop 실행을 시도했으나 실제 Linux engine pipe가 없고 backend 로그 상태는 stopped였다. Docker CLI 시작도 반환이 지연되어 실DB 검증 환경이 아직 확보되지 않았다.
- 사용자가 임시 강력 비밀번호 자동 생성/보호 파일 전달을 승인했다. 생성 정보는 `build/temp/private-content-admin/admin.credential.clixml`에 Windows DPAPI 암호화, 현재 SID만 ACL 허용으로 보존했다. 비밀번호·토큰은 출력하지 않았다.
- 실제 canary `/auth/username/check`: `admin`은 이미 사용 중. 새 생성 자격증명으로 `/auth/login` 실패. **계정 생성 성공/로그인 검증/권한 부여라고 보고하지 않음**. 보호 파일 State는 `existing-admin-login-not-verified`; 작동하는 관리자 비밀번호 파일이 아니다. 기존 계정 초기화 없음. 기존 계정 소유 확인·로그인 또는 새 관리자 아이디 지정 필요.

1. admin 계정 비밀번호: 사용자 지정값은 기존 가입 정책(영문·숫자 8~20자)에 부적합. 정책을 약화하거나 임의 비밀번호로 계정을 만들지 않음. 사용자 안전 입력 필요.
2. Supabase 추가 SQL 검토/적용, 정확한 admin 계정 UUID membership 등록 및 전용 API key 설정 필요. 현재 실서비스는 이 기능 비활성 상태다.
3. 실제 PostgreSQL 복수 연결 충돌/멱등·권한, canary 보유 시험지 열기/새로고침, 관리자 로그인+CRUD 검증 필요.
4. 이번 작업은 아직 Vercel 배포/alias 변경하지 않음. 현재 canary 배포가 새 UI라고 주장하지 않는다. 배포 요청 후 동일 D: hotfix 산출물로 고유 후보 검증→alias/bundle 확인.
5. Flutter 관련 파일에는 이전 미검토 dirty 변경이 섞여 있으므로 일괄 커밋하지 않음. 독립 관리자/API 파일만 검토 후 체크포인트 커밋한다.
