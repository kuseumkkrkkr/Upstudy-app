# Vercel + Supabase + Lightning AI 카나리 배포

학생 앱의 API 진입점과 제품 기능은 Vercel이다. Supabase는 사용자·제품 데이터·비동기 큐를
보관하고, Lightning 공개 앱은 TexTeller 필기 OCR만 수행한다. Lightning은 인증·레벨테스트·채팅·채점·
진도·평점·대결 API를 제공하지 않는다.

현재 이관 중인 기존 라우트가 남아 있으므로 이 문서의 목표 아키텍처 문구만으로 이관 완료를
판정하지 않는다. 특히 `api/index.py`의 Lightning 제품 프록시와 `mode=solve` 큐 흐름이 제거·검증되기
전에는 OCR 전용 worker 변경을 배포하지 않는다.

## 1. Supabase

SQL Editor에서 `supabase_ocr_queue.sql`과 `supabase_auth.sql`을 각각 한 번 실행한다. 테이블은 RLS가 켜져 있고
`anon`/`authenticated` 직접 접근 권한이 없다. Vercel과 Lightning에만 service role key를 Secret으로 둔다.
SQL이 `delete_expired_ocr_jobs()`를 매시간 호출하는 `aiflow-ocr-cleanup` Cron도 함께 등록한다.

S11 학생 데모/API를 함께 사용할 때는 `omj/migrations/postgres/010_student_demo_services_store.sql`을
SQL Editor에서 추가 실행한다. 이 migration은 수학 내신 계획의 optimistic version과 canary 전용
포인트 상점의 지갑 잠금·멱등 주문·차감 원장을 생성한다. 학원·과외 데이터는 서버에 저장하지 않고
Flutter fixture만 사용한다.

`canary_users`에는 기존 앱과 호환되는 PBKDF2 비밀번호 해시만 저장한다. 카나리 종료 시
`select public.delete_all_canary_users();`로 가입 정보를 전부 파기할 수 있다.

## 2. Lightning AI — 필기 OCR 전용

이 저장소를 Studio에 clone한 뒤 `omj/requirements.txt`를 설치한다. `lightning.env.example`의 값을
Studio Secret에 넣고 아래 OCR worker를 실행한다. 제품 FastAPI 전체 앱을 실행하지 않는다.

```bash
python -m pip install -r omj/requirements.txt
bash deploy/lightning/start.sh
```

`deploy/lightning/on_start.sh`의 내용을 Studio 홈의 `.lightning_studio/on_start.sh`로 등록하면
Studio가 자동 시작될 때 worker도 함께 복구된다. 공개 포트는 8000이며 Auto start를 활성화한다.

공개 포트 URL 끝에 `/wake`를 붙인 값을 Vercel의 `LIGHTNING_WAKE_URL`로 사용한다. `/health`가
200인지 먼저 확인한다. 첫 호출은 Studio/모델 콜드 스타트 때문에 수 분 걸릴 수 있다.

### 레벨테스트 초기 문제·템플릿 데이터

레벨테스트 시작 API는 Vercel이 제공하고, 데이터는 Supabase PostgreSQL의
`problem_payload`, `level_test_template`, `level_test_template_item`을 사용한다. 새 Supabase
프로젝트에 이 테이블의 기본 문제와 템플릿이 없으면, 앱 공개 전에 아래 데이터 준비 작업을 실행한다.
이 작업은 Lightning API를 배포하거나 실행하는 절차가 아니다. UPSERT 방식이므로 재실행할 수 있다.

```bash
cd /teamspace/studios/this_studio/aiflow-worker/omj
python scripts/seed_level_test_static_db.py --db /tmp/aiflow-level-test-static.db
python scripts/migrate_level_test_to_postgres.py --source /tmp/aiflow-level-test-static.db
```

첫 명령은 검수된 정적 문제 98개와 50문항짜리 템플릿 5개를 만들고 무결성을 검증한다.
둘째 명령은 `DATABASE_URL`을 사용해 이를 Supabase PostgreSQL에 넣는다.
완료 뒤 Vercel의 `POST /level-tests/placement/start`가 문항을 반환하는지 확인한다. 생성한
`/tmp` 파일은 이관 뒤 보관할 필요가 없으며 Git에 추가하지 않는다.

## 3. Vercel

Vercel에서 이 저장소의 `hotfix` 브랜치와 저장소 루트를 선택한다. Framework Preset은 `Other`로 두고
`vercel.env.example`의 값을 Project Environment Variables에 등록한 뒤 배포한다.

```text
GET https://YOUR-PROJECT.vercel.app/health
POST https://YOUR-PROJECT.vercel.app/auth/register
POST https://YOUR-PROJECT.vercel.app/auth/login
GET https://YOUR-PROJECT.vercel.app/auth/me
GET https://YOUR-PROJECT.vercel.app/arena/summary
GET https://YOUR-PROJECT.vercel.app/arena/rankings?queue_type=duel_exam
POST https://YOUR-PROJECT.vercel.app/api/ocr/jobs
GET https://YOUR-PROJECT.vercel.app/api/ocr/jobs/{job_id}
```

`SUPABASE_SERVICE_ROLE_KEY`, `OMJ_JWT_SECRET`, `LIGHTNING_WAKE_SECRET`은 앱 빌드 값이나 Git에 넣지 않는다.
콜드 스타트는 Vercel이 `LIGHTNING_API_AUTH`로 기존 Studio를 `cpu-4`에서만 재개한다. GPU 머신 이름은
코드에 허용하지 않아 wake 요청으로 유료 GPU를 시작할 수 없다.

대결장 요약·랭킹은 카나리 UI가 404 없이 열리기 위한 초기 계약만 제공한다. Vercel 함수는
실시간 WebSocket 매칭 서버가 아니므로 두 큐는 `coming_soon` 상태이며, 실제 매칭은 별도 상시
Arena 서버를 연결하기 전까지 활성화하지 않는다.

## 4. Flutter 앱

앱 API 기본 주소는 Vercel이다. `API_BASE_URL`을 Lightning 공개 URL로 지정하지 않는다. OCR 큐도
같은 Vercel origin의 `/api/ocr` 아래에서 등록·조회하고, Vercel이 승인된 OCR 작업만 Lightning에
전달한다.

```powershell
flutter build apk `
  --dart-define=API_BASE_URL=https://YOUR-VERCEL-PROJECT.vercel.app `
  --dart-define=OCR_QUEUE_BASE_URL=https://YOUR-VERCEL-PROJECT.vercel.app/api/ocr
```

학생서비스/포인트 상점 데모를 canary에서만 보이게 하려면 웹 빌드에 아래 define을 추가한다.

```powershell
flutter build web --release `
  --dart-define=STUDENT_SERVICES_DEMO=true `
  --dart-define=STUDENT_STORE_DEMO=true `
  --dart-define=OSM_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

두 flag를 생략하면 서비스·상점 메뉴와 전역 검색 결과는 숨겨진다. 상점 API는
`STUDENT_STORE_DEMO=true` 환경변수일 때만 노출하며, 구독 버튼은 결제 UI 확인만 수행한다.

`OCR_QUEUE_BASE_URL`은 이미지 필기 인식 작업 주소다. 풀이 채점은 별도의 Vercel 제품 API가 담당해야
하며, OCR 전용 worker가 `mode=solve`를 채점하는 경로로 사용해서는 안 된다. 현재 Vercel 채점
이관이 끝나기 전에는 이 설정으로 새 빌드를 배포하지 않는다.

## 운영 경계

- Vercel 요청 제한을 고려해 큐 JSON은 기본 4MB를 넘기지 못한다.
- 큐 선점은 PostgreSQL `FOR UPDATE SKIP LOCKED`이며 최대 3회 재시도한다.
- 완료 시 원본 payload는 즉시 비우고 결과 행도 기본 24시간 후 삭제한다.
- 이 구성은 20명 미만 카나리용이다. 2,000 동접 운영 구성은 별도 상시 worker와 정식 메시지 큐가 필요하다.
