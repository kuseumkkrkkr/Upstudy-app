# OCR 연결 및 배포 재시도 — 2026-10-13 KST

- D: `Upstudy-hotfix` / `hotfix` / 시작 HEAD `479a939378e63705a07c2fab9532440989b1f250`. 미커밋 UI는 수정하지 않았고 기존 D: release bundle을 유지했다.
- 기존 Studio의 새로운 CPU-4 실행 인스턴스 `01m4rksc8mq6br5kbyf1m0a32m`에 연결했다. 이전 편집기는 오래된 CPU instance ID 때문에 Cannot reconnect 상태였다. 별도로 브라우저 실제 폭 0을 확인하고 1280×900으로 복구했다. 새 유료 앱/GPU를 만들지 않았다.
- remote `omj/.env`의 기존 SAM 설정을 보존하며 이미 발급한 `VERCEL_OCR_WORKER_SECRET`, `LIGHTNING_WAKE_SECRET` 및 후보 API 주소를 추가했다. 붙여 넣은 내용과 clipboard의 LF 정규화 일치를 확인한 후 저장하고 secret editor를 닫고 clipboard를 비웠다. Supabase 키는 전달하지 않았다.
- 기존 OCR worker PID 2469/2488을 식별해 그 프로세스만 재시작했다. 새 worker 5621은 8000에서 `scope=handwriting_ocr_only`를 반환한다. `ss` 조회에서 8001 listener는 없었다. 기존 공개 8001 endpoint 등록 자체는 제거하지 않았다.
- 기존 SDK의 `Studio(create_ok=False).list_ports()`로 실제 8000 HTTPS 주소를 확인했다. 해당 `/health` 실제 응답 및 전용키를 넣은 `/wake` 202를 확인했다. Vercel Production `LIGHTNING_WAKE_URL`을 이 실제 `/wake` URL로 등록했다.
- remote `texteller_grid.py`와 D: 파일은 LF 정규화 후 정확히 일치했다(20,029 chars). 첫 warmup 명령은 존재하지 않는 함수명 `warmup_texteller`를 사용해 ImportError였다. 이는 모델 로드 실패의 증거가 아니다. 실제 함수는 `warm_texteller_runtime`다. 이 잘못된 검사를 통과/모델 미설치로 분류하지 않는다.
- 실제 합성 stroke `x=2` 모델 검사는 `tools/verify_texteller_sample.py`를 원격 CPU에서 실행했다. 기존 HF cache만 사용하고 offline, CUDA off로 설정했다. 이후 브라우저 CDP 연결이 다시 실패해 결과 log는 아직 회수하지 못했다. 따라서 실제 OCR 인식 성공은 **미확인**이다.
- 새 후보 `dpl_BUaE6DZGVfRbaFB3TCPgVTRuoFV3`: `https://aiflow-web-canary-gdgjfga1g-cw20208021-9200s-projects.vercel.app`, Production/READY. `--skip-domain` 사용. truthful metadata로 hotfix, 시작 source SHA, gitDirty=1, bundle SHA를 지정했다. 미커밋 Flutter source archive는 이전 배포 원장에 기록돼 있다.
- Vercel CLI의 인증된 curl로 후보 `/health/ready`를 확인했다. student API 및 표시된 모든 DB check true. 반면 일반 urllib는 후보 `/health`에서 redirect 후 Vercel HTML 로그인 페이지를 받는다. HTTP 200만 보고 API 성공으로 분류하면 안 된다.
- **새로 확인한 연결 차단:** 고유 후보에 Vercel Deployment Protection이 적용돼 있다. 현재 remote `VERCEL_API_BASE_URL`은 이전 고유 후보 `qy54g3qcc…`를 가리키므로 worker callback도 보호에 막힐 수 있다. 이전 보고서의 단순 urllib 200은 실제 API JSON 검증이 없었던 불충분한 검사였다. 새 API journey의 첫 `/auth/register`가 보호 단계 401로 중지됐으며 QA credential 파일/후속 OCR 요청을 생성하지 않았다. 앱의 Supabase 비밀번호 검증 실패와 구분한다.
- 보호를 풀거나 Vercel protection bypass key를 Lightning에 전달하지 않았다. 새 진단 도구는 auth redirect를 거부해 bearer token을 로그인 페이지로 넘기지 않는다. 전체 로그인/가입 UI QA를 API 검사로 대체했다고 주장하지 않는다.
- 지정 canary alias는 재확인 시 `dpl_21dPQZ955gTxpcwWGgBxsgwcHXZS`를 유지한다. 새 후보를 지정 alias로 승격하지 않았다. 실제 callback/인식을 확인하지 못한 상태에서 정상 제품 경로를 끊지 않기 위한 보류다.

## 다음 작업 및 완료 조건

1. 현재 Studio 원격 편집기를 다시 연결해 `texteller-smoke-20261013.log`를 회수한다. 실제 accepted/formula/warnings를 기록하고 실패면 원인만 고친다. 다른 모델로 대체하지 않는다.
2. remote callback base를 공개 canonical canary 주소로 바꾼 뒤 worker 재시작과 후보 검수/alias 전환을 하나의 짧은 canary cutover로 조정한다. 비공개 후보를 callback 주소로 유지하거나 보호 우회키를 worker에 제공하지 않는다. 전환 전 실제 모델 로드/인식을 확인해야 한다.
3. candidate→canary 승격 후 실제 테스트 계정의 이미지 제출/조회/채점 및 재시도, 이력·약점 저장을 검증한다. 실패면 검증된 이전 alias로 복구하고 주문/학생 원장을 삭제하지 않는다.
4. `verify_ocr_cutover_live.py`는 진단용 계정 생성 가능성을 명시한 API-only 보조 도구다. 현재 run은 보호 401 전에 중지됐고 성공으로 기록하지 않는다. 요청한 사용자 UI 검증은 별도로 computer-use로 수행한다.
