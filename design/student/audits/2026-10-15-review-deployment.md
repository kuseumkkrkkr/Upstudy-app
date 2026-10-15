# 재검증용 배포 — 2026-10-15 KST

- 사용자 요청: 우선 배포 주소를 보고 재검증. 새로운 UI/기능 수정은 하지 않았다.
- D: `Upstudy-hotfix` / `hotfix`; 배포 기준 HEAD `35f051369b691edb8a62f8e3b6d8d2daaa1c2cc4`. tracked dirty 172개를 보존했고 metadata에 gitDirty=1을 명시했다. HEAD만으로 전체 미커밋 Flutter 소스를 재현한다고 주장하지 않는다.
- 현재 D: 소스에서 Flutter release 웹을 새로 빌드했다. `API_BASE_URL=https://aiflow-web-canary.vercel.app`, 학생서비스/상점 데모 define true. 빌드 179.1초, 성공. 기존 CupertinoIcons font 경고는 남아 있다. SDK 업그레이드는 하지 않았다.
- 기존 public은 `build/temp/public-before-review-20261015`에 보존하고 빈 public에 새 build/web만 복사했다. 소스 참고 archive `build/temp/review-source-20261015.zip`(lib/web/pubspec/lock), SHA-256 `BB9C47029673420B332871C3A35DA45BB1160999DAD3BE6FEB4E0C8FF3C4E668`.
- 고유 배포: `dpl_8sLgch42L6eXgxU6vghi5PaYNkQq`, Production READY, `--skip-domain` 사용.
- 확인 주소: https://aiflow-web-canary-illzezx1c-cw20208021-9200s-projects.vercel.app/#/wrong_answers
- 해당 배포 main.dart.js를 인증된 Vercel CLI curl의 raw output으로 다운로드해 로컬과 hash 일치를 확인했다: `D633B5302948B4C06CAE70DA07CCC2FC1C1750322A69B1FFC775240DC715B6A7`. 재빌드 결과가 이전 D: 빌드와 같은 hash였으며 기존 파일을 빌드 대신 재사용한 것은 아니다.
- API 테스트 234 passed / 기존 warnings 82개. 후보 `/health/ready` JSON: student API, 표시된 모든 level-test 저장소 check true.
- 실제 브라우저에서 고유 배포의 `/wrong_answers`가 복습센터로 부팅되는 것을 확인했다. 화면의 복습 데이터 로딩 오류/다시 시도 필요 상태도 그대로 기록했다. 로그인·저장·OCR·채점 전체 여정 통과를 주장하지 않는다.
- 화면 증거: `evidence/2026-10-15-review-deploy/candidate-wrong-answers.png`.
- 지정 canonical canary는 배포 전후 모두 `dpl_21dPQZ955gTxpcwWGgBxsgwcHXZS`; 이 주소의 alias를 전환하지 않았다. CLI가 generated project alias를 자동 할당했지만 지정 canary와 구분한다.
- 이 확인용 웹 번들의 API 주소는 canonical canary다. 따라서 고유 주소에서 화면이 열린다는 사실은 중앙화 후보 API의 사용자 여정 통과 근거가 아니다. Vercel 접근 보호는 유지했고 새 origin에서 앱 로그인이 별도로 필요할 수 있다.
- Lightning callback의 비공개 후보 주소 문제 및 실제 OCR/채점 검증은 앞선 2026-10-13 원장 그대로 미해결이다. 상용 준비/일원화 완료나 최종 canary 승격으로 판정하지 않는다.
