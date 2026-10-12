# API 일원화 후보 배포 — 2026-10-13 KST

- 사용자 승인: canary 배포 및 OCR 전용 연결키 설정. 기존 CPU-4 Studio만 사용하며 새 유료 앱/GPU는 만들지 않는다.
- 작업: D: `Upstudy-hotfix`, `hotfix`, 제품 API checkpoint `c85c60f78e8231b34cb067a2a7635580878f305d`. 기존 미커밋 Flutter 수정은 보존했다.
- 테스트: `python -m pytest tests -q`: 234 passed / 82 existing warnings. `flutter build web --release` 성공. API 주소는 canary, 학생서비스/상점 demo flag true. CupertinoIcons font 경고는 미해결이며 UI 접근성/전체 여정 합격을 뜻하지 않는다.
- 로컬 기존 public과 live 번들이 달라 이전 public을 재사용하지 않았다. 현재 D: 소스로 rebuild 후 public을 새 디렉터리로 반영했다. 기존 public은 `build/temp/public-before-api-20261013`에 recoverable 보존했다. 파일 복사 과정에서 확인한 nested assets/CanvasKit 중복도 새 public 구성으로 제외했다.
- Flutter source snapshot: `build/temp/api-candidate-flutter-source-20261013.zip`; SHA-256 `BB4890C13F31C93D96CF4675AEF7077921EC3518712107A6DC0E38E975F0E63E`. 미커밋 Flutter 상태가 포함되므로 backend Git SHA만으로 Flutter source를 재현한다고 주장하지 않는다.
- candidate ID `dpl_3mJ4hocPMEBuZSr8ab7Er6ekbgJU`, URL `https://aiflow-web-canary-qy54g3qcc-cw20208021-9200s-projects.vercel.app`, Production / READY. `--prod --skip-domain`으로 생성했다. CLI가 지정 사용자 alias와 다른 generated project alias를 할당했으며, 지정 canary는 변경되지 않았다.
- 지정 canary `https://aiflow-web-canary.vercel.app`은 여전히 `dpl_21dPQZ955gTxpcwWGgBxsgwcHXZS`다. 후보를 지정 alias에 승격하지 않았다.
- 실제 후보 번들을 raw 파일로 다운로드해 `public/main.dart.js`와 SHA-256이 정확히 일치함을 확인했다: `D633B5302948B4C06CAE70DA07CCC2FC1C1750322A69B1FFC775240DC715B6A7`. PowerShell stdout redirect는 byte 변환이 생겨 비교용으로 쓰지 않고 curl `--output`으로 다시 확인했다.
- 후보 `/health/ready`: student API, 모든 표시된 level-test storage checks true. `/level-tests/placement/stats`: pool 776, 일반 25 / quick 10문항. 인증 없는 정상 형식 `/internal/ocr/claim`: `invalid worker secret`으로 거부.
- Vercel Production에 새 `LIGHTNING_WAKE_SECRET`, `VERCEL_OCR_WORKER_SECRET`를 Sensitive로 등록했다. 기존 Supabase/JWT/Kiln 값은 바꾸지 않았다. Supabase 키는 Lightning에 전달하지 않았다. 생성된 전용키의 재개용 파일은 Git 제외 `build/temp/.ocr-link-keys.json`에 있으며 채팅/감사/번들에 값은 넣지 않았다.
- 아직 `LIGHTNING_WAKE_URL` 설정 및 remote 전용키 반영/worker 실행/실제 TexTeller OCR→채점 왕복은 **미완료**다. Lightning 브라우저는 재개 버튼 후 CDP 응답 실패, 기존 탭 재연결 실패, 새 탭 attach 실패가 이어졌다. Windows Lightning CLI도 `termios` 없는 Windows 미지원으로 종료했으며 로컬 CLI credential은 없다. 브라우저 로그인만으로 SDK credential을 추출하거나 인증을 우회하지 않았다.
- `open_in_codex`로 해당 Studio를 열도록 요청했으나 calling thread에 `queued` 상태다. 사용자에게 현재 채팅과 Lightning 탭을 열어달라고 요청했다. 이 UI 연결이 복구되기 전에는 현재 canary의 제품 proxy를 후보로 교체하지 않는다.
- 후보 메타데이터에는 Git ref/SHA가 없으므로 source attribution을 배포 메타만으로 입증하지 않는다. 코드 checkpoint, source archive, 배포 file inventory와 raw bundle hash를 별도로 보존한다.

## 다음 한 작업

1. 이 채팅의 Lightning 탭이 보이면 기존 Studio 원격 `.env`에 Vercel URL과 이미 생성한 OCR 전용키만 추가한다. 기존 SAM 설정을 보존한다. 새 키를 무조건 재발급하지 않는다.
2. existing `start.sh`의 worker를 실행하고 실제 forwarded HTTPS `/health`/인증된 `/wake`를 확인한다. 관찰한 URL만 Vercel `LIGHTNING_WAKE_URL`에 넣는다.
3. 새 환경을 포함한 후보를 생성해 실제 필기 OCR·Vercel 채점·DB 상태를 확인한다. UI/인증/핵심 자료 여정 및 hash 검증 후 지정 canary alias만 전환한다. 실패하면 현재 alias를 유지한다.
4. 전용키가 두 서비스에 안전히 저장되면 재개용 로컬 key artifact를 정확한 경로에서 제거한다. source/public backup은 보존한다.
