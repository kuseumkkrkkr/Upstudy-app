# Vercel + Supabase + Lightning AI 카나리 배포

이 브랜치는 무거운 TexTeller를 Vercel에 넣지 않는다. Vercel은 카나리 학생 인증과 OCR 큐 API를
제공하고, Supabase가 사용자·24시간짜리 큐를 보관하며, Lightning 공개 앱이 기존
`omj/analysis_service.py`를 실행한다.

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

## 2. Lightning AI

이 저장소를 Studio에 clone한 뒤 `omj/requirements.txt`를 설치한다. `lightning.env.example`의 값을
Studio Secret에 넣고 아래 공개 앱을 실행한다.

```bash
python -m pip install -r omj/requirements.txt
bash deploy/lightning/start.sh
```

`deploy/lightning/on_start.sh`의 내용을 Studio 홈의 `.lightning_studio/on_start.sh`로 등록하면
Studio가 자동 시작될 때 worker도 함께 복구된다. 공개 포트는 8000이며 Auto start를 활성화한다.

공개 포트 URL 끝에 `/wake`를 붙인 값을 Vercel의 `LIGHTNING_WAKE_URL`로 사용한다. `/health`가
200인지 먼저 확인한다. 첫 호출은 Studio/모델 콜드 스타트 때문에 수 분 걸릴 수 있다.

### 레벨테스트 초기 문제·템플릿 이관

레벨테스트 시작 API는 PostgreSQL의 `problem_payload`, `level_test_template`,
`level_test_template_item`을 사용한다. 새 Supabase 프로젝트에는 이 테이블의 기본 문제와
템플릿이 없으므로, Lightning Studio에서 worker를 공개하기 전에 아래 작업을 한 번 실행한다.
이관은 UPSERT 방식이므로 같은 명령을 다시 실행해도 안전하다.

```bash
cd /teamspace/studios/this_studio/aiflow-worker/omj
python scripts/seed_level_test_static_db.py --db /tmp/aiflow-level-test-static.db
python scripts/migrate_level_test_to_postgres.py --source /tmp/aiflow-level-test-static.db
```

첫 명령은 검수된 정적 문제 98개와 50문항짜리 템플릿 5개를 만들고 무결성을 검증한다.
둘째 명령은 Studio Secret의 `DATABASE_URL`을 사용해 이를 Supabase PostgreSQL에 넣는다.
완료 뒤 `POST /level-tests/placement/start`가 50개 문항을 반환하는지 확인한다. 생성한
`/tmp` 파일은 이관 뒤 보관할 필요가 없으며 Git에 추가하지 않는다.

## 3. Vercel

Vercel에서 이 저장소의 `vercel` 브랜치와 저장소 루트를 선택한다. Framework Preset은 `Other`로 두고
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

현재 구성에서 Vercel은 OCR 큐 전용이다. 로그인·문제·코스·마켓·복습을 포함한 일반 앱 API는
Lightning 공개 FastAPI 주소를 사용하고, OCR 분석만 Vercel 큐를 거쳐 Lightning worker로 전달한다.
두 주소를 바꾸면 일반 기능이 빈 Vercel 경량 응답으로 향하므로 반드시 분리해 설정한다.

```powershell
flutter build apk `
  --dart-define=API_BASE_URL=https://YOUR-LIGHTNING-PUBLIC-URL `
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

`OCR_QUEUE_BASE_URL`을 생략하면 `ApiClient.submitSolveAnalysis()`는 기존 `/analysis/solve`를 호출한다.
지정하면 앱이 Vercel에 작업을 등록하고 최대 4분간 폴링한 뒤 기존 `SolveAnalysisResponse`를 반환한다.

## 운영 경계

- Vercel 요청 제한을 고려해 큐 JSON은 기본 4MB를 넘기지 못한다.
- 큐 선점은 PostgreSQL `FOR UPDATE SKIP LOCKED`이며 최대 3회 재시도한다.
- 완료 시 원본 payload는 즉시 비우고 결과 행도 기본 24시간 후 삭제한다.
- 이 구성은 20명 미만 카나리용이다. 2,000 동접 운영 구성은 별도 상시 worker와 정식 메시지 큐가 필요하다.
