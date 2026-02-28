# s11

Flutter 클라이언트와 로컬 Python(FastAPI) 백엔드가 연동되는 프로젝트입니다.

## 실행/환경 변수
- API 서버 주소: `API_BASE_URL` (기본값 `http://localhost:8000`)
  ```bash
  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
  ```
- 로그인/회원가입 경로(필요 시 서버 스펙에 맞게 재정의):
  - `API_LOGIN_PATH` (기본 `/auth/login`)
  - `API_REGISTER_PATH` (기본 `/auth/register`)
  ```bash
  flutter run -d chrome \
    --dart-define=API_BASE_URL=http://localhost:8000 \
    --dart-define=API_LOGIN_PATH=/login \
    --dart-define=API_REGISTER_PATH=/signup
  ```

## 인증 흐름 요약
1) `LandingPage` → 로그인 버튼 → `LoginPage`.
2) 로그인 성공 시 토큰을 `ApiClient`에 저장하고 `BuildboxCopyWidget`(학생 대시보드)로 이동.
3) 로그인 화면에서 “회원가입”을 선택하면 `SignupPage`로 이동, 가입 후 동일하게 대시보드로 진입.

## 개발 노트
- `lib/services/auth_service.dart`에서 로그인/회원가입 요청을 담당하며, 위의 dart-define 값으로 경로를 주입할 수 있습니다.
- 기본 경로로 404가 난다면 서버 스펙에 맞춰 `API_LOGIN_PATH`, `API_REGISTER_PATH`를 지정해 주세요.
