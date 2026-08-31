# AIFlow 첫 실행 설정

이 문서는 Windows PowerShell에서 주 제품인 `Upstudy-app`을 처음 실행하는 절차를 정리한다. 일반 제품 개발은 `Upstudy-main`이 아니라 이 디렉터리를 사용한다.

## 1. 필수 도구

- Git
- Flutter SDK (이 프로젝트는 Dart `3.9.0` 이상 필요)
- Python과 `venv`, `pip`
- Docker Desktop (PostgreSQL 16, Redis 7 실행용)
- Chrome (웹 클라이언트 실행 시)

설치 상태를 먼저 확인한다.

```powershell
flutter doctor
python --version
docker version
```

## 2. 백엔드 가상환경과 패키지

저장소 루트의 `Upstudy-app\omj`에서 실행한다.

```powershell
cd Upstudy-app\omj
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python -m pip install pytest
```

PowerShell이 활성화 스크립트를 막으면 현재 프로세스에만 정책을 완화한 뒤 다시 실행한다.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

## 3. UTF-8 환경 설정

예제 파일을 UTF-8로 복사한다. `.env`에는 비밀값이 들어가므로 커밋하지 않는다.

```powershell
Copy-Item .env.example .env
```

`.env`에서 최소한 다음 값을 로컬 환경에 맞게 수정한다.

```dotenv
POSTGRES_PASSWORD=충분히_긴_로컬_비밀번호
DATABASE_URL=postgresql://omj:위와_같은_비밀번호@127.0.0.1:5432/omj
REDIS_URL=redis://127.0.0.1:6379/0
PROBLEM_CACHE_BACKEND=postgres
MARKETPLACE_BACKEND=postgres
PROBLEM_CACHE_VERIFIED=false
RUN_EMBEDDED_BACKGROUND_WORKERS=false
```

`POSTGRES_PASSWORD`와 `DATABASE_URL`의 비밀번호는 반드시 같아야 한다. URL 예약 문자가 포함된 비밀번호는 URL 인코딩해야 하므로, 로컬 첫 실행에서는 영문·숫자로 된 긴 값을 권장한다.

백엔드 서버는 `omj/.env`를 UTF-8로 자동 읽는다. 단, 초기화용 Python 스크립트는 현재 PowerShell 환경변수를 사용하므로 같은 터미널에서 아래 명령으로 `.env`를 불러온다.

```powershell
Get-Content .env -Encoding UTF8 |
  Where-Object { $_ -match '^\s*[^#][^=]*=' } |
  ForEach-Object {
    $name, $value = $_ -split '=', 2
    Set-Item -Path "Env:$($name.Trim())" -Value $value.Trim().Trim('"').Trim("'")
  }
$env:PYTHONUTF8 = '1'
```

AI 생성·OCR 기능까지 사용할 때는 `.env.example`의 모델 설정을 유지하고, 사용하는 공급자의 API 키를 별도로 추가한다. 키는 문서나 Git에 기록하지 않는다.

## 4. PostgreSQL과 Redis 초기화

Docker Desktop을 실행한 뒤 `Upstudy-app\omj`에서 다음 순서로 진행한다.

```powershell
docker compose -f docker-compose.runtime.yml up -d
docker compose -f docker-compose.runtime.yml ps
python scripts/apply_postgres_schema.py
python scripts/migrate_problem_cache_to_postgres.py --apply
if (-not (Test-Path .\data\level_test_static.db)) {
  python scripts/seed_level_test_static_db.py
}
python scripts/migrate_level_test_to_postgres.py
```

문제 캐시 이관 결과의 검증 항목이 성공한 경우에만 `.env`의 값을 아래처럼 바꾸고, 현재 터미널에도 반영한다.

```dotenv
PROBLEM_CACHE_VERIFIED=true
```

```powershell
$env:PROBLEM_CACHE_VERIFIED = 'true'
```

레벨테스트 정적 DB는 파일이 없을 때만 결정적 seed로 만든다. 기존 데이터는 다시 만들거나 삭제하지 않는다. 이미 초기화된 개발 DB를 받은 경우에는 데이터 이관 명령을 반복하기 전에 담당자에게 확인한다. 스키마 적용기는 같은 마이그레이션을 다시 실행할 수 있도록 작성되어 있다.

## 5. FastAPI 실행

`Upstudy-app\omj`에서 가상환경이 활성화된 상태로 실행한다.

```powershell
uvicorn server:app --reload --host 127.0.0.1 --port 8000
```

다른 PowerShell 창에서 상태를 확인한다.

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health/ready
```

응답의 `ready`가 `true`여야 한다. `false`이면 함께 반환되는 `postgres`, `redis`, `migration_audit`, `level_test_postgres` 값을 먼저 확인한다.

백그라운드 생성 작업이 필요하면 별도 PowerShell 창에서 같은 가상환경과 환경변수를 사용해 worker를 실행한다. 웹 서버 내부 worker는 중복 실행 위험 때문에 켜지 않는다.

```powershell
cd Upstudy-app\omj
.\.venv\Scripts\Activate.ps1
python -m services.jobs.worker_main
```

## 6. 학생 앱 실행

새 PowerShell 창에서 `Upstudy-app`로 이동한다.

```powershell
cd Upstudy-app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

실기기나 에뮬레이터에서는 `127.0.0.1`이 개발 PC가 아닐 수 있다. 이때 `API_BASE_URL`을 개발 PC의 접근 가능한 LAN 주소 또는 에뮬레이터용 호스트 주소로 바꾼다.

## 7. 교사 앱 실행(선택)

교사 앱은 별도 Flutter 프로젝트다.

```powershell
cd Upstudy-app\s11_teacher
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## 8. 첫 실행 점검

```powershell
# 백엔드
cd Upstudy-app\omj
.\.venv\Scripts\Activate.ps1
python -m pytest tests

# 학생 앱
cd ..
flutter analyze
flutter test

# 교사 앱(사용할 때)
cd s11_teacher
flutter analyze
flutter test
```

전체 검증이 오래 걸리면 변경 영역과 같은 테스트부터 실행한다. 첫 실행 완료 기준은 Docker의 PostgreSQL·Redis가 healthy이고, `/health/ready`가 `ready: true`이며, 필요한 Flutter 앱이 백엔드에 연결되는 것이다.

## 자주 발생하는 문제

- `DATABASE_URL is required`: 3장의 `.env` 환경변수 로드 명령을 현재 PowerShell에서 다시 실행한다.
- PostgreSQL 인증 실패: `POSTGRES_PASSWORD`와 `DATABASE_URL`의 비밀번호가 같은지 확인한다. 기존 Docker 볼륨은 최초 비밀번호를 유지하므로 함부로 삭제하지 말고 담당자에게 확인한다.
- `/health/ready`가 `migration_audit: false`: 문제 캐시 이관 또는 검증이 완료되지 않았다. `PROBLEM_CACHE_VERIFIED=true`만 강제로 설정하지 않는다.
- `/health/ready`가 `level_test_postgres: false`: 스키마 적용과 `migrate_level_test_to_postgres.py` 실행 결과를 확인한다.
- Flutter 웹에서 API 연결 실패: 백엔드 포트와 `API_BASE_URL`이 일치하는지 확인한다.
- OCR 첫 시작이 느림: TexTeller 모델 준비와 가중치 다운로드가 필요할 수 있다. 일반 UI/API 개발만 확인할 때는 OCR 기능 점검을 별도로 진행한다.
