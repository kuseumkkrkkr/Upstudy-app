# 남은 교재 제작·출판 체크포인트

기준일: 2026-10-17
상태: 26개 카탈로그 성취기준 대조 진행 · tag 기반 후보 원고 확장 중 · 출판 경로 미검증

## 2026-10-17 현재 작업트리 재검증

- 현재 앱 테스트를 다시 실행했다: BookData 인벤토리 왕복과 activity compatibility 합계 127 tests passed. Upstudy-hotfix 공개/가져오기/저자 호환/그래프 보안 회귀도 51 passed, Starlette/httpx deprecation warning 1개다. 이는 전체 standalone HTML의 화면·동작 parity 검증이 아니다.
- 현재 BookData로 범위 원장을 재생성했다: 26개 상품, 1,038 product-standard 행, 115 root source BookData. 재귀 원고는 178 BookData이며 이전 분류 기준으로 33 `not_eligible`, 145 eligibility 미지정이다. 106 HTML의 전체 앱 패리티도 미확인이다. 원장 출력은 작업 산출물 폴더의 `REMAINING_TEXTBOOKS_CURRENT_SCOPE_COVERAGE.md`에 보관했다.
- 공식 판본-코드 392쌍 모두 코드/태그 신호가 있다. 이 중 342쌍은 chapter exact code, 21쌍은 단일 코드·단일 chapter 연결, 75쌍은 candidate chapter mapping이다. exact 또는 candidate 구조 신호가 전혀 없는 쌍은 0이지만, candidate 75쌍의 대조와 모든 실질 내용 충족 검토는 승인되지 않았다.
- 재귀 `REVIEW_MANIFEST.json` 30개는 모두 `publication_eligibility=not_eligible`다. 단일 원본 SHA를 선언한 25개 중 21개는 CRLF를 LF로 정규화한 뒤 SHA가 일치하고 4개는 불일치한다. 나머지 5개는 여러 원본을 선언하는 형식이라 단일 `bookdata_file` 방식으로는 비교되지 않았다. 원본 교정·manifest 동기화 전까지 기존 runtime status를 현재 후보 SHA의 증거로 간주하지 않는다.
- 저장소 HEAD와 `origin/main`은 `5e78eaae2864f76abf4baec51f7ed0a40c439ad3`로 일치한다. 현재 작업트리에는 별도 변경 파일이 있으므로 이 검증을 HEAD 산출물 또는 배포물 검증으로 표현하지 않는다.
- 모든 검수 manifest가 출판 부적격이고 권리·교사·독립 수학·교육과정 검토가 완료되지 않아 배포하지 않았다. 교육부 첨부별 권리 근거, 4개 SHA 불일치 원인, 5개 다중 원본 hash map, 75개 후보 매핑 및 내용의 실질 범위 대조가 후속 차단 항목이다.

## 2026-10-17 공식 권리·게시 승인 경로 재확인

- 교육부 공식 [2015-74 고시 페이지](https://www.moe.go.kr/boardCnts/view.do?boardID=141&boardSeq=60747&lev=0&m=0404)는 수학과 교육과정을 별책 8로 지정하고 ZIP 첨부를 제공한다. [2022-33 고시 페이지](https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=141&boardSeq=93458&lev=0&m=0404)도 같은 별책 8과 첨부 ZIP을 명시한다. 현재 확인한 페이지 본문에는 첨부 자료의 공공누리 유형이 표시되지 않는다. 이것만으로 ZIP/HWP/PDF 자체의 표시 유무를 단정하지 않는다.
- 교육부 [저작권 정책](https://www.moe.go.kr/sub/infoRenew.do?m=070105&page=070105&s=moe)은 공공누리 부착 자료의 유형별 조건을 적용하고, 미부착 자료는 공공저작물 실무담당자와 사전 협의하도록 안내한다. 상업 이용은 제2유형에서 금지되고, 변경 이용은 제3유형에서 금지된다. 따라서 현 원고의 교육과정 원문·기존 HTML 재사용 권리는 확인 전까지 pending으로 유지한다.
- 별도 `Upstudy-hotfix`는 위 누락을 반영해 HEAD `ad4a763`에서 공개 manifest와 runtime 모두 `curriculum_review_status=approved`를 요구한다. 공개 release 필수 승인에는 publication/rights/teacher/math/curriculum이 포함되며, manifest는 원문 SHA와 함께 승인 metadata를 보존한다. origin/hotfix와 HEAD 일치 및 관련 파일의 clean 상태를 읽기 전용으로 확인했다. 담당 스레드는 관련 30개 테스트 통과를 보고했다. 이는 권리 승인 자체가 아니며, 실제 DB/RLS 상태와 운영 배포 검증은 pending이다.
- 위 근거는 권리 승인이나 배포 승인이 아니다. 현재 이 저장소 원장상 공개 적격 BookData는 0개이며, 공식 별첨의 개별 이용허락 및 독립 교육과정 검토를 추가 확인해야 한다.

## 2026-10-17 2015 중학교 기하 배치 2 수학 검사·재귀 패키지 참조

- `9수04-11`–`9수04-20`의 10개 후보(50쪽, native quiz 10개)를 공식 2015 코드 추출물과 대조했다. 생성기 산술 검사를 보강해 10개 예제 풀이·10개 연습 해설·10개 quiz 정답 키가 계산 결과와 기대 답에 포함되는지 확인한다. 이전 검사에서 practice 답 두 개가 관계 설명/판별 문제였는데 수치 답으로 잘못 기대한 점을 고쳐 현재 문항의 답과 맞췄다.
- 생성 패키지에 개별 `README.md`를 추가하고 BookData V2를 재생성했다. 학년군 기준이며 학기 배정 미확정, 교사·독립 수학·권리 검토 pending, publication `not_eligible` 상태를 유지한다.
- `build_tagged_textbook_drafts.py --from-stage build_textbook_scope_coverage.py`를 현재 체크아웃에서 실행했다. 94–95단계 후반 산출과 package-reference 검사를 완료했으며, 기존 검사 범위가 root BookData 115개에 한정됨을 확인해 재귀 BookData 전체를 나열하는 `REMAINING_TEXTBOOKS_DRAFT_PACKAGE_INDEX.md`를 추가했다. 재귀 BookData 178개 전체 참조 확인 통과; 이전 누락 12개 filename 참조도 색인에서 확인된다.
- `py_compile`(두 생성기), BookData inventory roundtrip(3 tests), activity compatibility(124 tests) 통과. 검증은 데이터 계약·선택된 reader interaction에 한정되며 전체 HTML parity·독립 수학/교사 승인·권리 판정을 대신하지 않는다.

## 2026-10-17 vectorOperation + resumable pipeline 재검증

- 기존 vector source tag 생성 stage에 `고등수학_기하_벡터의덧셈과실수배_BookData_V2_시범.json` 생성을 추가했다. 원본 3쪽을 보존하며 `vectorOperation` 조작 activity와 HTML의 2개 Socratic 확인·연습을 quiz 3개로 연결했다. 후보에는 independent teacher/math review와 rights 확인 전 상태를 유지했다.
- 새 V2의 네 activity 모두 app `BookData` importer 왕복을 통과했다. 실제 후보 전체를 학생 `BookWidget`에 올려 add/subtract/scalar 선택, 결과 확인, scalar 슬라이더의 음수 방향 전환을 테스트했고 Socratic quiz 선택·채점도 확인했다. 기존 vectorInnerProduct BookWidget 검사 포함 compatibility suite 16/16 통과, 변경 Dart 파일 analyzer `No issues found`, Python generator syntax와 V2 재생성 SHA-256 동일(`9404BC0826F8D5C6F1D1DAF15B685682EB86B72A35E3A3852808006062E9E0FE`).
- 공식 원문 입력이 있는 C: 격리 worktree에서 전체 tag pipeline 78/78 단계를 성공적으로 다시 실행했다. 마지막 검증은 26 products, 1,038 product-standard rows, top-level 109 BookData source files의 package references 통과; HTML index는 standalone HTML 106개와 recursive BookData 145개를 집계했다. 재개 실행도 새 stage 이후 50/50 suffix와 109개 참조 검사를 통과했다.
- HTML 원장에서는 vectorInnerProduct 및 vectorOperation을 `ported_pending_review`로 표시한다. 이는 선택된 native 동작 검증을 뜻하며 독립 HTML 전체 화면·시간 동작 parity를 뜻하지 않는다. Geometry(2015) 성취기준 본문 매핑은 여전히 partial; 권리, 독립 수학/교사 검수, 배포 승인은 대기 중이다. 26개 상품은 모두 출판 eligible이 아니므로 배포하지 않았다.
- 다음 미충족 기준 `12기하02-01 벡터의 뜻을 안다`에 대해 정의, 풀이 예제, 거리와 변위 비교, 3개 연습과 해설, native quiz를 담은 5쪽 V2 부분 후보를 생성했다. BookData round-trip과 후보 quiz의 학생 BookWidget 상호작용을 테스트했다. 이 기준의 본문 적합성은 독립 검토 전이며, Geometry(2015) 전체 기준 매핑, 교사·수학 검토와 rights는 pending이다.
- 이어서 `12기하02-03 위치벡터의 뜻을 알고, 평면벡터와 좌표의 대응을 이해한다` 부분 후보 4쪽을 작성했다. 기준점과 위치벡터 정의, 점 좌표↔성분 대응, 두 점 사이 벡터 예제와 연습 3개·해설, native quiz를 포함한다. importer round-trip 및 실제 후보 quiz의 학생 BookWidget 제출·피드백이 통과했다. 전체 파이프라인 80/80 단계와 111개 BookData package-reference 검사가 성공했고 HTML index는 106 standalone HTML/147 recursive BookData를 집계했다. 내용 적합성의 독립 수학·교사 검수와 rights는 pending; 출판 부적격이다.
- 두 V2 생성기는 현재 후보 SHA가 직전 검증 SHA와 같을 때만 `passed_flutter_activity_compatibility_suite` 결과·검증 HEAD·명령을 다음 생성에도 보존하고, 내용 해시가 달라지면 재검증 대기로 되돌린다. 이 결과는 지정된 importer 왕복과 퀴즈 상호작용 범위만 기록하며 전체 BookWidget 과정, 교육과정 내용 적합성, 독립 수학·교사 승인으로 확장하지 않는다.
- 2015 기하 V2 12모듈의 질문·풀이를 전수 대조해 `12기하02-05`뿐 아니라 여러 모듈에서 문제와 무관한 풀이 예시가 재사용된 것을 확인했다. 생성기에서 12개 풀이를 각 질문에 맞게 수정하고 모든 정답 키가 풀이에 포함되는 assertion을 추가했다. 02-05 직선 매개식과 원 방정식도 별도 조건·검산을 갖추도록 고쳤다. importer 왕복 및 02-05 학생 `BookWidget` 선택·피드백을 포함한 Flutter compatibility test 21/21이 통과했다. manifest 검증은 새 후보 SHA-256 `63F8D7302884E26A76CC76CE2AC44FF35F775AA5B71C288B4E6E00390474A88F`에 고정한다. 이는 자동 assertion과 저자 수준 점검이며 독립 수학·교사 검토, 전체 교재/교사 화면 및 HTML 패리티는 여전히 대기 중이다.

## 2026-10-17 미적분Ⅰ(2022) V2 내용·activity 호환성 재검토

- 미적분Ⅰ 신규 13모듈의 각 질문과 풀이를 대조해 기존 풀이 문장이 다른 예제를 가리키던 불일치를 수정했다. 정답 설명을 보강하고 생성 단계에 13개 해설-정답 일치, 퀴즈 키 구조 및 주요 극한·연속·평균값정리·미분·적분 산술 검사를 추가했다.
- 기존 `type: quiz` payload를 현재 BookData `type: activity`/`kind: quiz` 계약으로 변경했다. compatibility suite가 13개 payload 왕복 보존을 확인하고, 실제 c1-0101 퀴즈의 학생 `BookWidget` 선택·피드백을 검증했다. 전체 Flutter compatibility suite 23/23 통과. 후보 SHA-256 `B8C48B468A849EB1D775C95309ED19A2BE5A42185CAAF05FA3F582EB5B355851`로 검증 결과를 고정했다.
- 이는 저자 점검과 선택된 activity 동작 검증이다. 독립 수학·교사 검토, 학기·전체 상품 범위 검토, 기존 HTML 패리티와 권리 확인은 pending이며 출판 부적격이다.

## 2026-10-17 vectorInnerProduct reader 연결 업데이트

- hotfix의 한정된 `BookActivity` 모델·네이티브 activity renderer를 main에 가져와 `TextbookActivityBlock`이 `vectorOperation`/`vectorInnerProduct`를 안전한 parser 통과 시 실행하도록 연결했다. 알 수 없거나 잘못된 payload는 기존 unsupported fallback에 남는다. 서버/시험 점수 저장은 추가하지 않았다.
- 기존 평면벡터 내적 BookData는 보존하고 `고등수학_기하_평면벡터내적_BookData_V2_시범.json` 후보를 추가했다. 내적 activity는 기존 실험 페이지에 연결했으며 앱 importer 왕복과 학생 `BookWidget`의 u=3, v=4, θ=60° 값(6.00), 부호 선택, 단계 및 힌트 상호작용이 검증됐다. `html-2a9ff578cf62178d`는 `ported_pending_review`로 갱신했다.
- 이는 standalone HTML 전체 parity 증명이나 교사/독립 수학 검수, 권리 허가가 아니다. 독립 HTML 원본을 보존했고 26개 상품은 계속 `partial`, 출판/배포 부적격이다. 이후 업데이트에서 `vectorOperation` V2 후보와 네이티브 조작을 확인했으나 HTML 전체 parity는 미확인이다.

## 2026-10-17 최신 재검증

기준 커밋 `fb8f4cae67b615a291166483e282632055850a59`의 격리 worktree에서 `python tool/build_tagged_textbook_drafts.py` 전체 실행을 완료했다. 78/78 단계가 성공했고, 생성 패키지 참조 검증은 원본 BookData 107개 전체에서 통과했다. 공식 교육과정 입력을 복사한 별도 worktree에서 실행했으며 원본 체크아웃의 미관련 dirty files는 보존했다. 파이프라인 로그: 34 unit books, 109 subunits, 199 concepts, 1,594 existing pages; 최신 coverage ledger: 26 products, 1,038 product-standard rows, 107 source BookData; HTML index: 106 standalone assets, 143 BookData files. 후보 생성/태그 집계는 수학·교사·권리 승인이나 전체범위 충족을 뜻하지 않는다.
- 재실행·재개 점검: 같은 입력으로 격리 worktree에서 전체 파이프라인을 다시 실행했고, 실행 전후 추적 diff는 134,078 bytes 및 SHA-256 `4a77338a3961da8c8a0e3d8d489e9903e98583e8644fd13bc5c71db2ad3d6156`로 동일했다. `--list-stages`는 78단계를 출력했고 `--from-stage build_html_asset_inventory.py`는 마지막 단계부터 재개해 107개 BookData 참조 검사를 통과했다. 중간 단계부터 이어가는 수동 재개 옵션이며 stage 완료 상태를 자동 저장하는 매니페스트는 아니다.
- 커버리지 원장은 이제 `standard_codes`/`standard_code`와 tags의 exact official-code token을 검사한다. 판본은 `curriculum_version` 또는 명시적인 판본 태그에서만 확인하고, 파일명으로 추정하지 않는다. 이에 따라 2015 중학교 학년군 태그 27개, 2022 중학교 학년군 태그 43개가 각각 확인됐지만, 이 기준은 학기별·상품별로 배분하지 않았다.
- 범위 표기 재점검: #1–#12의 27/35는 학년군 코드 태그 원고 인벤토리이며 6개 학기 상품 각각의 coverage가 아니다. #13–#14는 공식 `<수학>`의 41개 코드를 함께 기준선으로 표시할 뿐 상·하권 배분이 승인되지 않았으므로 두 상품의 태그 수를 `분권 미확정`으로 표기한다. 상품별 본문 충족 수치는 어느 행에도 승인된 것이 없다.
- Official-code candidate tags: #15 수학Ⅰ(2015) 19/19, #16 수학Ⅱ(2015) 21/21, #17 확률과 통계(2015) 17/17, #18 미적분(2015) 27/27, #19 Geometry (2015) 16/16, #20 공통수학1(2022) 19/19, #21 공통수학2(2022) 20/20, #22 대수(2022) 18/18, #23 미적분Ⅰ(2022) 20/20, #24 확률과 통계(2022) 16/16, #25 미적분Ⅱ(2022) 23/23, #26 기하(2022) 14/14. Counts are tag candidates, not content-completion claims.
- 권리 근거 확인: 교육부 [2022 개정 교육과정 고시 게시물](https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=141&boardSeq=93458)은 별책 ZIP 첨부를 제공하지만 본문에는 해당 파일의 공공누리 유형이 표시되지 않는다. 교육부 [저작권 정책](https://www.moe.go.kr/sub/infoRenew.do?m=070105&page=070105&s=moe)은 공공누리 표시가 있는 자료에 한해 유형별 자유이용을 안내하고, 표시가 없는 자료는 실무 담당자와 사전 협의하도록 안내한다. 현 로컬 2022 HWP SHA-256은 `AAB8EED59ECF244223D04AFAD75F4CF5AC5085FADCFC3CF52C2F6D54DDFC7856`이며 원문 스크립트를 재사용하는 새 원고의 허가·출처표기 범위는 확인되지 않았다. 2015 PDF/기존 HTML의 출처별 권리도 미확인이다. 따라서 모든 상품의 상업 출판 권리 판정은 계속 pending이며, 배포 가능 자료로 세지 않는다. 공공누리 [유형 안내](https://www.copyright.or.kr/gov/nuri/guide/index.do)는 제2유형의 상업 이용 금지와 제3유형의 변경 금지를 구분한다.
- 공식 파일 표시 재점검: 로컬 2015 Appendix 8 PDF 첫 표지를 렌더해 확인했으며 해당 표지에서 공공누리/KOGL 표시를 확인하지 못했다. 이는 PDF 전체나 원 배포 ZIP의 권리표시 부재를 증명하지 않으므로 rights clearance는 계속 pending이다. 2022 원문 HWP와 출처별 기존 HTML도 상업적 재사용·변경 권한이 확인되지 않았다.
- 2026-10-17 교육부 공식 게시물 재확인: [2015-74 별책 1–15 ZIP 게시물](https://www.moe.go.kr/boardCnts/view.do?boardID=141&boardSeq=60747&lev=0&m=040401&opType=N&page=5&s=moe&searchType=S)은 별책 8을 수학과 교육과정으로 명시하지만 게시물 본문에서 별책 첨부의 공공누리 유형을 확인할 수 없다. 별도의 [2015 개정 교육과정 안내 게시물](https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=316&boardSeq=62381&lev=0&m=0302&opType=N&page=1&s=moe&searchType=null&statusYN=C)은 게시물 저작물을 공공누리 제2유형(출처표시·상업적 이용금지)으로 표시하나, 이 표시가 2015-74 별책 ZIP에도 적용된다고 간주하지 않는다. [2022-33 고시 게시물](https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=141&boardSeq=93458&lev=0&m=0404)은 별책 ZIP에 수학을 포함하지만 본문에는 공공누리 유형 표시가 없다. 교육부 [저작권 정책](https://www.moe.go.kr/sub/infoRenew.do?m=070105&page=070105&s=moe)은 공공누리가 붙은 저작물만 표시 조건에 따라 별도 허락 없이 이용할 수 있다고 안내하고, 미부착 자료는 공공저작물 실무 담당자와 사전 협의를 요청한다. 따라서 2015/2022 교육과정 원문 재사용 및 상업 출판 권리는 모두 미확정이며 사전 확인 전 출판에 사용하지 않는다.
- Mathematics II (2015): authored 18 original modules/90 pages for the 18 standards without current candidate tags. Existing four tagged modules/12 source pages were retained; the integrated draft contains 22 modules/102 pages. Numeric spot checks, unique page IDs, official code set, the 72-step pipeline, and guarded app `BookData.fromJson` import passed. New content remains pending independent teacher review and rights clearance; publication is ineligible.
- 공통수학2 신규 후보는 Batch1 14모듈/70쪽/quiz 14개와 Batch2 3모듈/15쪽/quiz 3개다. Batch2는 원본 HWP raw `EqEdit`에서 `10공수2-01-07`의 x, y, y=x; `10공수2-03-04`의 유리함수 기본형; `10공수2-03-05`의 무리함수 기본형을 복구해 기록했다. 기존 두 BookData를 포함한 단원 그룹 초안은 19모듈, 원본 지면 94개를 보존했으며, 태그 후보는 공식 20/20이다. 배치별 예제 검산과 페이지 보존 검사는 통과했지만 전체 과목 범위·수학 내용·교사 검수·권리 결정은 미완료다. 출판 부적격이며 앱 통합/배포는 하지 않았다.
- 수학Ⅰ(2015) 기존 4개 BookData의 코드 후보 10개를 예비 연결하고, 누락 9개 공식 코드와 기존 삼각함수 원고의 탄젠트 그래프 보완 1모듈을 신규 V2 10모듈/50쪽/quiz 10개로 작성했다. 2015 원문 지면은 23쪽 보존, 기존+신규 14모듈/73쪽이 3개 단원 통합 초안에 들어갔다. strict importer가 기존 4개와 신규 V2 1개를 모두 통과했고, validator HEAD `d64f05551e69bbb1b31f262b91d41f163abad66`; 신규 SHA-256 `bfaff24de6d646a90a44177ea462a46987d03a4a657d77846a25c3dfccb1cb33`다. 이 19/19는 후보 태그 수이며, 01-04/01-06, 02-02, 03-07/03-08의 본문은 부분 후보라 독립 교사 검수·권리 결정 전 출판 부적격이다. 기존 HTML은 독립 자산으로 남아 앱 parity 미검증이다.
- 2022 공식 HWP raw record에서 EqEdit 스크립트를 직접 복구해 16개 기준 행에 기록했다. 추출 XHTML은 해당 객체를 시각적 수식으로 표현하지 않지만 JSON에는 원문 script가 있다. 원고 작성 시 script를 추적하고, 해석·표기 검토는 교과 검토 단계에서 한다.
- 이전 interactive-source 검증 시점에는 hotfix `vectorOperation` 원본 HTML 2개(`html-002d8074c7ebb2fb`, `html-5f1d5700e9fa1fc1`)와 `vectorInnerProduct` 원본 HTML 1개(`html-2a9ff578cf62178d`)가 이관되지 않았고 main reader도 해당 kind를 실행하지 않았다. 이후 `vectorInnerProduct`와 `vectorOperation` 모두 V2 후보에 연결되었으며 native BookWidget 동작을 부분 검증했다. 독립 HTML 전체 화면·시간 동작 parity는 여전히 미확인이다.
- 앱 범위 회귀: 원고 폴더의 파일 수를 재집계해 Markdown 107, BookData 이름을 포함한 JSON 107, 전체 JSON 112, HTML 86으로 대시보드 요약과 16개 first-tag 집계를 갱신했다. `flutter test --reporter compact test/concept_textbook_prototype_json_test.dart test/textbook_bookdata_inventory_roundtrip_test.dart` 154/154 통과. 그중 기존 스위트에 열거된 86개 BookData의 모든 지면이 앱 모델을 통과하고 BookWidget에서 데스크톱/모바일 렌더됐다. 신규 왕복 테스트는 107개 전체 BookData의 `fromJson→toJson→fromJson` 및 전체 모델 JSON 동일성을 확인했다. 이는 미지원 vector 활동의 실행 검증이 아니며 교사 수학검토와 개별 HTML 동작 패리티도 남아 있다.
이전 parser-only 27개 파일 검사는 activity 왕복 보존을 증명하지 못했다. 이후 `BookContentBlock.activity` 직렬화와 공용 quiz UI/reader 렌더를 구현했다. Algebra V2 14개, Geometry 2015 V2 12개, Geometry 2022 space/vector V2 9개 등 총 35개 quiz payload의 `fromJson→toJson` 동일성, 학생 BookWidget 선택/피드백, 실제 2022 Geometry V2 원고를 teacher course-reader에서 스크롤·선택·제출하는 동작이 통과했다. 전용 Flutter 테스트 9건 및 변경 Dart 파일 analyzer 통과. 서버/DB 저장 API와 독립 HTML 실행·화면 패리티는 검증하지 않았으며 수학·교사·권리 검토와 게시 승인은 대기 중이다. 운영 반입/배포는 하지 않았다.

- 미적분Ⅰ(2022) 공식 HWP 본표에서 20개 코드를 확인했다. 새 V2 후보는 기존에 미태그였던 13개 기준을 13모듈/65쪽/quiz 13개로 보완했다. 별도 기존 BookData 5개에는 02-01~05 후보 태그가 이미 있었으나 판본/공식 `standard_codes` 메타데이터가 비어 원장에서 제외되고 있었다. 공식 기준 인덱스 및 상품 목차 후보와 대조해 해당 필드를 기록했으며 원장은 20/20 candidate tags로 재생성됐다. 이는 본문 충족 승인이 아니다. 통합 초안은 기존 6모듈/18쪽과 신규 13모듈/65쪽을 보존한다. 숫자 예제 산술 assert와 65개 페이지 ID 중복 검사는 통과했다. guarded Flutter importer 확인은 Dart VM 컴파일 단계에서 내부 FFI 변환 crash가 나서 미확인 상태다. 신규 SHA-256 `7AC68EC35CEDBE963827EB2245A394E348837F73F5E37D95F4A7465A231A8CE1`; 수학 교사 검토·권리 결정 대기 중이며 출판 부적격이다.

- Calculus (2015): generated original candidate content for 27 official standards (27 modules/135 pages); the existing 3-page source remains preserved separately. Unit integration preserves 138 source pages. Arithmetic spot checks, official-code set check, unique IDs, pipeline, and guarded app parser passed. Rights clearance and independent math review are still pending, so it is not publish eligible.
- Geometry (2015): mapped 4 existing vector sources to 4 provisional, partial standard candidates and authored 12 V2 modules/60 pages for the remaining codes. Integration preserves 78 original pages across 18 modules and adds 18 source-label pages. Unit counts: conics 4 modules, vector applications 1, spatial geometry 7. All 12 quiz payloads round-trip exactly; student and active teacher course-reader quiz interaction passed. Five related HTML assets remain separate from BookData; HTML execution/parity, rights and teacher review remain open.
- 대수(2022): Batch1 14 modules/70 pages and EqEdit Batch2 3 modules/15 pages with 3 quizzes each; existing arithmetic-sequence candidate included in the integrated draft makes 18 modules/89 original source pages plus 18 integration labels. Candidate tags cover 18/18 official codes. Batch2 records raw HWP scripts for `12대수03-03/04/05`; all 17 generated Algebra V2 quiz payloads round-trip through the app model, and the 11-test compatibility suite loads the actual Batch2 BookData in the teacher reader, submits its quiz and checks feedback. Server/database persistence, related HTML runtime/parity, source rights and independent content review remain unverified; deployment is ineligible.
- 이어서 2022 중등 공식 기준 `9수02-14`, `9수02-17`, `9수02-18`에 대해 재실행 가능한 후보 생성기를 추가했다. 3개 모듈/18쪽/native quiz 3개이며 학기 미배정, 본문·수학·교사 검수 및 권리 판정 대기 상태다. 공식 기준 인덱스 문자열 비교, 예제 계산 assert, 출력 SHA-256 재생성 일치(`92F9E2D44B985B53E623A86A0C420109552230F98B6A65473FC353576D234F98`)를 확인했다. 학생 BookWidget 퀴즈 제출/피드백과 BookData activity round-trip 테스트가 통과했다; 2022 중등 학년군 tag inventory는 35/60이며 이를 6개 학기 상품에 배분하지 않는다. 후보 코드는 커버리지 원장에 tag evidence로 연결했으나 전체 범위 충족이나 출판 승인을 뜻하지 않는다.

- 추가로 2022 중등 대수·부등식·연립방정식 공식 기준 `9수02-08~13` 6개를 6개 모듈/36쪽/native quiz 6개로 작성했다. 공식 코드 인덱스 연결, 지수·다항식·부등식·연립방정식 산술 assert와 출력 재생성을 확인했고, 실제 학생 BookWidget 퀴즈와 activity round-trip 검증을 추가했다. 이 배치는 2022 중등 학년군 tag 후보를 41/60으로 올리지만, 학기 배정이나 내용 충족 승인은 아니다. 권리·교사·독립 수학 검토 대기 상태는 유지한다.

- 2022 중등 `9수02-08~13` 6개 기준에 대한 대수·부등식·연립방정식 후보를 추가했다(6모듈/36쪽/native quiz 6개). 생성기는 공식 코드 유무와 지수법칙·다항식·분배법칙·부등식 풀이·연립방정식 및 문장제 계산을 assert하고, 실제 reader 퀴즈 피드백과 BookData activity 왕복 테스트를 통과했다. 전체 tag 기반 재생성기의 stage 목록에 두 신규 2022 후보 배치 생성기를 등록해 현재 82단계이며, 이번에는 전체 pipeline 실행은 하지 않았다. 2022 중등 학년군 tag 후보는 41/60; 이 수는 6개 학기 상품에 분배하지 않는다. rights, 독립 수학·교사 검수는 pending이다.

- 2022 중등 `9수02-20/21` 이차방정식·이차함수 부분 후보를 추가했다(2모듈/12쪽/native quiz 2개). 직사각형 넓이 문장제와 함숫값 계산을 포함하고 해·값 대입 계산 assert 및 reader 퀴즈/BookData round-trip 검증을 통과했다. 생성기를 전체 83단계 pipeline에 등록했다. 학기 배정, 독립 교사·수학 검토, 권리 판정은 대기 중이다. 2022 중등 학년군 exact tag inventory는 43/60이며 나머지 17개 코드는 여전히 미태그다.

## 2026-10-16 이전 재검증

- 파이프라인 66단계 성공, 원본 BookData 98개 참조 확인. 교재 원고 폴더 실측: BookData 파일 134개, JSON 223개, 하위 폴더 40개, HTML 106개. HTML 인덱스 재생성 완료.
- 선언형 activity 인벤토리: quiz 104개, statisticsEstimator 2개, discreteExperiment 1개. 이는 저작물 기능 수이며 실제 화면별 동작·교과 적합성 검토 완료를 뜻하지 않는다.
- 공통수학1 2022 공식 성취기준 19개 전부 후보 태그에 연결됐다. 신규 Batch2는 16모듈/80쪽/quiz 16개이며 importer 통과; 기존 후보 3모듈과 합쳐 19개 기준 태그 후보다. 신규 매니페스트는 guarded Upstudy-hotfix HEAD `b310fd112e0b3e1e92f0b571d5ecd586bbe54a76` 검증을 기록했다. 교사·수학·권리 검토와 상품 전체 범위 대조는 미완료이며 게시 부적격이다.
- 매니페스트에 등록된 BookData 후보 12개를 같은 guarded HEAD의 importer로 SHA-256 포함 검증했다.
- 2015 확률과 통계 공식 기준 17개 중 기존 2개에 이어 미연결 15개를 Batch2 후보로 작성했다(15모듈/75쪽/quiz 15개). 공식 텍스트 코드 집합과의 일치, 예제 산술 spot-check, 저자 자가 수학검토를 기록했고, 신규 BookData는 guarded HEAD `b310fd112e0b3e1e92f0b571d5ecd586bbe54a76` importer 통과. 원장 tag 후보는 17/17이지만 문항별 독립 교사 검토, 과목 범위 승인과 권리 결정은 미완료다.

## 2026-10-16 이어서 확인한 사항

- 2022 공식 HWP 본문을 pyhwp XHTML로 변환한 결과에서 성취기준 표 190개 고유 코드를 추출했다. 이 중 중학교 9수 60개, 고등학교 해당 과목 기준 130개다. 추출 JSON은 `work/official-curriculum/2022_math_standards.json`; 현재 생성 파이프라인은 63단계다.
- 26개 상품 기준 장부는 2015 PDF 및 2022 HWP 표의 공식 코드를 baseline으로 집계한다. BookData exact tag는 내용 충족이 아니며 학기 배정·상품 전체 coverage·검수는 별도다. 상세 행은 [REMAINING_TEXTBOOKS_CONTENT_COVERAGE.md](REMAINING_TEXTBOOKS_CONTENT_COVERAGE.md) 참조.
- 공통수학1 추가 3단원 원고의 `10공수1-02-07`, `-02-08`, `-04-02`는 본표 표 23/25의 정식 기준 및 문구와 대조되어 BookData `standard_codes`로 기록했다. guarded hotfix HEAD `79af5fbd9cd7ee54a5cfac77df74670d6751f729` importer 통과, 3모듈/18쪽/quiz 3개. 교사·수학 검토 대기, 권리 상태 unknown, master 미병합, 게시 부적격.
- 중학수학 2-2 확률 후보에 `discreteExperiment`를 추가했다: 공정 주사위 6면·짝수 성공·누적 상대도수·최대 10,000회. 해당 V2 원고는 importer 통과(4모듈/24쪽/quiz 4개+실험 1개). 원본 HTML은 보존하며 기능 부분 대응이다. HTML↔native 실제 화면 parity와 학기 배정은 미검증이다.
- 확률과 통계 2022는 추가 V2 후보 16모듈/80쪽(16개 기준)을 작성했다. Batch1–3의 15모듈/75쪽과 Batch4 `12확통02-01` 기본 확률 보완 1모듈/5쪽을 포함한다. 02-01의 예전 통계적 확률 후보는 상대도수 중심이라 기본 성질을 직접 다루지 않아 보완 원고를 추가했다. Batch3 8모듈 중 7개는 본문과 기준을 예비 대조했고, `12확통03-07`에는 mean/proportion `statisticsEstimator` 활동 두 개를 추가했다. 현재 guarded hotfix HEAD `06790094dcfbe226b3106e0ebf371b26dd9f0f59`의 importer, Python 32개 activity/import 테스트, Flutter 9개 estimator/V2 reader 테스트가 통과했다. 원고 JSON의 페이지 ID는 `ps0307-practice`, 정규화 BookData SHA-256은 `28EDFE3363CC976BF899F41AFBCE31C1CE10FF71B547F262915D5449DE4276FA`다 (Windows raw SHA-256 `45CC9070270D74D21E9AF92F2748CAC80E150CA3CF9D5B0AEF0DFC1148C46DBC`는 CRLF 때문에 다르며 API/importer와 manifest는 CRLF→LF canonical digest를 사용한다). 이는 후보 importer/reader widget 검증이며 라이브 배포/실제 브라우저 페이지 캡처 증거가 아니다. 전 모듈 교사 검토·권리 결정·상품 전체 대조는 여전히 대기 중.
- 이전 스냅샷의 파이프라인은 62단계·93개 원본 BookData 참조·BookData 129개였다. 이후 배치별 현행 값은 아래 최신 실행 결과를 기준으로 한다. 2015+2022 상품 반복 집계 1,038은 중복을 포함한 상품-기준 행 수다.

- 미적분Ⅱ 2022 수열·급수 기준 `12미적Ⅱ-01-01~05`는 Batch1 5모듈/25쪽/quiz 5개로, 미분·적분 기준 `12미적Ⅱ-02-01~11`, `03-01~07`은 Batch2 18모듈/90쪽/quiz 18개로 후보 원고를 작성했다. 전 23개 코드가 tag 후보에 연결되고 importer를 통과했다. 단, `12미적Ⅱ-03-01` 공식 HWP 텍스트 추출에서 문구 앞 수식이 누락되어 보이므로 이 원고는 확인 가능한 지수·삼각함수 적분만 다루며 기준 전체 충족으로 보지 않는다. 전 과목 내용 검토와 교사·권리 검토도 미완료다.

- Coverage 재검증은 공식 기준 16개 전체 tag 행과 Batch1 미적분Ⅱ 5개 기준 행을 분리해 확인했다. 이전 임시 assertion은 prefix 전체가 5개라고 잘못 가정해 실패했으며, 판정식을 원장 행/파일 참조 기준으로 고쳐 재검증했다.

- 2015 확률과 통계 공식 코드 `12확통02-05` 조건부확률, `12확통03-03` 이항분포를 기준 원문과 대조해 새 오리지널 V2 후보 2모듈/10쪽/퀴즈 2개를 추가했다. importer 통과, 17개 기준 중 2개만 매핑이며 전체 과목·교사·권리 검토는 미완료다.
- 2022 기하에서 앞서 미작성으로 기록된 9개 공식 기준 `12기하02-01~03`, `02-05`, `03-01~05`에 V2 후보 9모듈/45쪽/quiz 9개를 추가했다. guarded hotfix HEAD `aaf65ac3c3a70f0321ccb5ca66799930484686ac`에서 재귀 schema-v2 BookData 14개 importer 통과; 새 2개 후보 manifest의 runtime importer 상태를 pass로 기록했다. 기하 14개 기준 모두 tag 후보가 있으나 본문 충분성·교사 검토·권리 판단은 미완료다.
- 직전 스냅샷의 파이프라인은 64단계·원본 BookData 96개 참조, BookData 132개, 폴더 38개, JSON 217개였다. 최신 수치는 위 최신 재검증을 따른다. 2015+2022 상품 반복 집계는 1,038 상품-기준 행이며 고유 기준 수가 아니다.
- canonical BookData SHA-256 매니페스트 10개와 schema-v2 후보 15개를 대조했다. guarded hotfix HEAD `b310fd112e0b3e1e92f0b571d5ecd586bbe54a76`에서 schema-v2 후보 15개 importer 통과했다.
- Reader 회귀 근거: `build/temp/bookdata-resize-test.log`의 초기 실패는 `Section prose survives` 보충 설명이 reader에 나타나지 않은 오류였다. 이후 guarded hotfix HEAD `b310fd1`의 현재 working tree에서 `test/bookdata_import_preservation_test.dart` 4/4 및 `test/book_activity_v2_test.dart` 6/6을 재실행해 통과했다. 첫 테스트는 섹션 텍스트·페이지 전환, 두 번째는 일반 V2 activity reader 경로를 확인한다. 두 테스트는 dirty working tree의 reader 변경도 포함하며 새 18모듈 전체 화면별 검수나 깨끗한 HEAD 빌드를 뜻하지 않는다.

## 현재 근거

- 목표 집합은 [개념서 체험콘텐츠 제작규격](개념서_체험콘텐츠_제작규격.md)의 판본별 26종(중등 12, 고등 14)이다. 아래 23개 폴더는 작업 산출물 위치이지 목표 집합이 아니다.
- 최초 인벤토리: 폴더 23개, BookData JSON 117개, JSON 187개, 체험형 HTML 84개. 최신 재귀 실측은 폴더 44개, BookData JSON 136개, JSON 231개, HTML 106개다.
- `python tool/build_tagged_textbook_drafts.py`: 최신 70단계 성공, 원본 BookData 100개 참조 확인. 기존 태그 패키징 수치: 단원 34, 소단원 109, 개념 199, 보존 지면 1,594. 추가 후보 BookData는 기존 통합본 범위를 늘린 것으로 세지 않는다.
- #8·#9·#10·#11 후보 BookData는 schema v2, 각각 4개 선언형 quiz activity다. 2026-10-16 guarded Upstudy-hotfix HEAD `169a2d4bb533229c3032052cf9fe5724119100cd`에서 네 파일 모두 SHA-256 검증을 포함한 importer 통과(각 4모듈/24쪽/4활동). 원고 테스트 #8–#11 각 2건, 총 8건 통과; guarded hotfix `test/book_activity_v2_test.dart` 6건 통과(실제 reader 390px/1280px 포함).
- #9–#11 HTML 12개를 브라우저에서 열어 직접 조작했다. #9는 원뿔 단면, 이등변삼각형 채점, 직사각형 대각선 성질, 상대도수 비교를 확인했다. #10은 피타고라스 빗변, 삼각비 비율, 곱의 법칙 결과 갱신, 주사위 시행/상대도수 누적을 확인했다. #11은 제곱근 근삿값, 다항식 곱·인수분해 결과, 이차함수 극값 방향 전환을 확인했다. 캡처는 로컬 검수 증거이며 공개 배포 증거가 아니다.
- #12 schema v2 BookData는 guarded Upstudy-hotfix HEAD `e9028f9da180835d642863d49c09ebdf81341e5d`의 SHA-256 importer 통과(SHA-256 `926AF3444B0DC9BC0C0C621638A30E8958EBD62F9FE3BB6CFF09FFE3D74D533D`); 원고 테스트 2건 통과, guarded hotfix V2 reader 회귀 6건 통과. 네 HTML 페이지의 화면을 캡처하고 조작 확인했다: 조사 인원 20→26명, 제3사분위수 80→81(사분위 범위 25→26), 상관 방향 양→음, 이상값 변경 시 평균·중앙값·최빈값 갱신. 모든 확인은 로컬 후보 검수이며 공개 배포 증거가 아니다.
- 입력 BookData 86개 가운데 그래프 포함 37개, 시각자료 포함 24개. 질문/정답 블록은 있지만 전용 `quiz`/`interaction` 직렬화 필드는 없다. `BookContentBlock`은 `visual`/`graph`까지만 직렬화한다.
- 기하 포물선 시범은 BookData 3쪽에 매개변수 그래프를 담고, 거리 측정·채점형 입력은 별도 `고등수학_기하_포물선_체험형_시범.html`에 있다. 앱 모델이 지원하지 않는 기능은 HTML/태그 자산을 보존하고 지원된다고 주장하지 않는다.
- 원격 게시 경로 `ApiClient.createTextbook()`은 빈 Map을 반환한다. 실제 서버 저장 계약과 UI 게시 동작은 미확인이다.
- 2022 HWP TXT 추출 ID는 `(가) 성취기준 해설` 참고이며 본표 ID와 구분한다. XHTML로 본표 190개 고유 기준을 추가 복구했다. HWP SHA-256 `AAB8EED59ECF244223D04AFAD75F4CF5AC5085FADCFC3CF52C2F6D54DDFC7856`; 공식 묶음 SHA-256 `B37A372A90D6D00BB3985888BBB41CAAE7A35F28877DC243A6F4B28861C53146`. 원본과 변환 파일은 `work/`에 보존한다.
- 2015 교육부 고시 제2015-74호 별책8 수학 PDF/공식 ZIP도 내려받아 코드 인덱스를 추출했다(PDF SHA-256 `4BD2B84E978865A71D90577D8EB6240F0ECF24A9884642D627CDE460D71AB88E`; ZIP SHA-256 `556C3045B7DCEFF1442049D3B84E6DD0A34FDEE420356305E7802E7070AFA212`). `tool/build_curriculum_code_inventory.py`가 26종을 과목/학년군 prefix에 연결했다. 단, 2022 HWP XHTML 본표에서 190개 고유 코드를 복구했으며, 일부 EqEdit 수식 개체는 변환물에서 내용이 빠져 별도 한계로 원장에 표시한다. 기존 본문이 각 코드를 충족하는지도 아직 대조하지 않았다.
- [26종 성취기준·콘텐츠 적용 범위 원장](REMAINING_TEXTBOOKS_CONTENT_COVERAGE.md)은 2015 PDF 및 2022 HWP XHTML 본표 기준 코드와 원고 tag를 edition 일치 조건으로 대조한다. 2015 수학(상)/(하) 분권 경계와 모든 학기 배정은 미확정이며, tag는 내용 coverage 승인이 아니다.
- guarded `Upstudy-hotfix` HEAD `1c28c3038c0eac48de5f3e6bd2581dbf7d486b24`의 실제 V2 계약에서 `discreteExperiment` 네이티브 importer/widget을 확인했다. 독립 HTML은 activity로 자동 임베드되지 않으며, 확률 원본에 discreteExperiment를 부분 대응했다. 실제 UI parity 검수는 미완료다. 서버 저장·교사/권리 승인·배포 근거는 없다.
- 기존 대수 초안의 `[12대수03-02]`는 XHTML 본표에 존재한다. 코드의 유무는 확인됐지만 초안 내용이 그 기준을 충족하는지는 별도 대조해야 한다.

## 26개 카탈로그 진행표

`partial`은 초안·모듈이 있으나 상품 범위가 완성되지 않음을 뜻한다. `missing`은 지정 학기 자료를 찾지 못했다는 뜻이다. 모든 항목은 공식 별책 8 성취기준 직접 대조, 권리 근거 기록, 상품별 인터랙션 연결, 승인 상태를 별도로 추적한다.

| # | 상품 | 상태 | 현재 근거와 남은 내용 | 판본/기준 | 기능 자산 | 권리/제작 상태 |
|---:|---|---|---|---|---|---|
| 1 | 중학수학 1-1 · 2015 | partial | 2015 중등 27모듈/3영역 초안; 공식 9수 학년군 61개 코드 중 이 상품에서 다루는 기준 및 학기 범위 미대조 | 별책8 9수01–05 공식 코드 인덱스 있음; 공식 학기 미배정 | 그래프/HTML 상품별 연결 미확인 | 권리 미기록; 초안 |
| 2 | 중학수학 1-2 · 2015 | partial | 같은 27모듈의 학기 미분류 자료; 61개 코드 중 이 상품 기준 범위 미대조 | 별책8 9수01–05; 공식 학기 미배정 | 상품별 연결 미확인 | 권리 미기록; 초안 |
| 3 | 중학수학 2-1 · 2015 | partial | 같은 27모듈의 학기 미분류 자료; 61개 코드 중 이 상품 기준 범위 미대조 | 별책8 9수01–05; 공식 학기 미배정 | 상품별 연결 미확인 | 권리 미기록; 초안 |
| 4 | 중학수학 2-2 · 2015 | partial | 같은 27모듈의 학기 미분류 자료; 61개 코드 중 이 상품 기준 범위 미대조 | 별책8 9수01–05; 공식 학기 미배정 | 상품별 연결 미확인 | 권리 미기록; 초안 |
| 5 | 중학수학 3-1 · 2015 | partial | 같은 27모듈의 학기 미분류 자료; 61개 코드 중 이 상품 기준 범위 미대조 | 별책8 9수01–05; 공식 학기 미배정 | 상품별 연결 미확인 | 권리 미기록; 초안 |
| 6 | 중학수학 3-2 · 2015 | partial | 같은 27모듈의 학기 미분류 자료; 61개 코드 중 이 상품 기준 범위 미대조 | 별책8 9수01–05; 공식 학기 미배정 | 상품별 연결 미확인 | 권리 미기록; 초안 |
| 7 | 중학수학 1-1 · 2022 | partial | 교육청 학기 예시 기반 11 BookData/33쪽 통합; 공식 원문 대조·나머지 범위 필요 | 2022 후보, 교육부 기준 미대조 | 1-1 시범 자료; 별도 HTML 연결 일부 | 권리 미기록; 초안 |
| 8 | 중학수학 1-2 · 2022 | partial | 4개 모듈/24쪽 오리지널 후보 원고 생성: 점·선·면·각, 삼각형 작도, 다각형 각·대각선, 대푯값. 전 상품 범위는 아님 | 공식 기준 후보 9수03-01/03/05, 9수04-01; 학기 귀속은 공식 원문에 없어 편집 후보 | BookData V2 quiz 4개 importer 검증; 원본 조작/채점 HTML 4개 보존; 앱 실제 탑재는 보류 | 새 집필 초안; 프로젝트 권리 결정 대기; 교사 검수 대기 |
| 9 | 중학수학 2-1 · 2022 | partial | 새 오리지널 4모듈/24쪽 작성: 입체 단면, 이등변삼각형 증명, 사각형 대각선, 상대도수. 전체 범위는 미완성 | 별책8에서 9수03-07/09/11, 9수04-03 코드 확인; 학기 귀속은 공식 미제공 | V2 퀴즈 4개 importer 검증; 체험 HTML 4개 브라우저 조작 확인; 앱 실제 탑재는 보류 | 신규 초안; 교사 검수·프로젝트 권리 결정 대기 |
| 10 | 중학수학 2-2 · 2022 | partial | 새 오리지널 4모듈/24쪽: 피타고라스 정리, 삼각비, 기본 경우의 수, 확률; 전체 상품 범위는 미완성 | HWP 본표에서 9수03-15/17, 9수04-05/06 확인; 학기 귀속은 공식 미제공 | guarded importer: quiz 4 + `discreteExperiment` 1 통과; 독립 조작 HTML 4개 보존, 확률은 네이티브 부분 대응·화면 parity 미검증 | 신규 초안; 교사 검수·프로젝트 권리 결정 대기 |
| 11 | 중학수학 3-1 · 2022 | partial | 새 오리지널 4모듈/24쪽: 제곱근, 다항식 곱셈·인수분해, 이차함수 극값; 전 상품 범위는 미완성 | 별책8에서 9수01-08, 9수02-19, 9수02-22 코드 확인; 학기 귀속 공식 미제공 | V2 퀴즈 4개 importer 검증; 독립 조작 HTML 4개 브라우저 확인; 앱 실제 탑재는 보류 | 신규 초안; 교사 검수·프로젝트 권리 결정 대기 |
| 12 | 중학수학 3-2 · 2022 | partial | 새 오리지널 4모듈/24쪽 후보: 통계 탐구, 상자그림, 상관관계, 대푯값; 전 상품 범위는 미완성 | 별책8의 9수04-01/04/08/09 코드 존재 확인; 공식 학년군 기준, 학기 귀속 미제공 | V2 퀴즈 4개 importer 검증; 독립 HTML 4개 브라우저 화면·조작 확인; 앱 실제 탑재는 보류 | 신규 초안; 교사 검수·프로젝트 권리 결정 대기 |
| 13 | 수학(상) · 2015 | partial | 다항식 덧셈·뺄셈 4쪽 시범 및 분권 경계 초안; 공식 `<수학>` 41개 코드의 상·하권 배분표와 나머지 본문 필요 | 별책8 10수학01–05 인덱스; 자체 분권 범위 미승인 | BookData 정적 지면; 체험 자산 미확인 | 권리 미기록; 초안 |
| 14 | 수학(하) · 2015 | partial | 집합 합집합·교집합 4쪽 등 일부 시범; 공식 `<수학>` 41개 코드 중 하권 배분 및 나머지 집합·명제·함수·경우의 수 필요 | 별책8 10수학01–05 인덱스; 자체 분권 범위 미승인 | BookData 지면; 체험 자산 미확인 | 권리 미기록; 초안 |
| 15 | 수학Ⅰ · 2015 | partial | 기존 4 BookData/23쪽 + 신규 V2 10모듈/50쪽; 14모듈/73 원본 지면, 19/19 코드 후보 태그 | 별책8 12수학Ⅰ01–03의 19개 코드 대조; 일부 후보 내용은 부분 매핑 | 신규 quiz 10개 importer 통과; 기존 HTML 보존, 앱 parity 미검증 | 교사·수학/권리 검토 대기; 출판 부적격 |
| 16 | Mathematics II · 2015 | partial | Existing 4 modules/12 pages + new V2 18 modules/90 pages; integrated 22 modules/102 pages; 21/21 code tag candidates | All 21 standards checked against 2015 Appendix 8; some source mappings remain partial | Guarded BookData.fromJson passed for V2 candidate at `e0bc17074481259c6f8d4c63894da07dd6c2e814`; existing graph/HTML parity unverified | Teacher review and rights decision pending; not publish eligible |
| 17 | 확률과 통계 · 2015 | partial | 기존 조건부확률·이항분포 2모듈/6쪽 및 신규 V2 후보 15모듈/75쪽; 17개 공식 코드 모두 tag 후보 연결 | 기존 두 기준과 신규 15개 기준 공식 텍스트 연결; `12확통02-03` 퀴즈 사건 조건을 답 2/3에 맞게 바로잡음; 전체 상품 범위 대조 필요 | 전체 15개 후보 BookData round-trip, 01-01 quiz student BookWidget 실행, 02-03 조건-정답 회귀검사 통과; 기존 HTML 자산 parity 미확인 | 독립 교사·수학 검수와 권리 결정 대기; 출판 부적격 |
| 18 | Calculus · 2015 | partial | Existing sequence-limit sample/3 pages + new V2 27 modules/135 pages; integrated 28 modules/138 source pages; 27/27 code tag candidates. New generator revision aligns each module's example and practice prompt; scoped check covers all 27 prompt/answer/activity links. | 2015 Appendix 8 codes checked; full product scope and content quality review remain pending | BookData round-trip passed; quiz 01-01 ran in student BookWidget; independent HTML parity unverified | Independent teacher review and rights decision pending; not publish eligible |
| 19 | Geometry · 2015 | partial | Existing vector 6 modules/18 pages + new V2 12 modules/60 pages; integrated 18 modules/78 original pages; 16/16 candidate codes | 2015 Appendix 8 checked; existing vector mappings partial; all 12 absent/untagged standards newly drafted | Guarded app parser passed for 4 existing sources and V2 batch; 5 related HTML files retained separately; no HTML runtime/parity claim | Independent teacher review pending; existing-source rights unverified; new draft rights decision pending; not publish eligible |
| 20 | 공통수학1 · 2022 | partial | 기존 7모듈/37쪽 및 별도 후보 19모듈/98쪽(3+16); 19개 공식 기준에 태그 후보 연결, 전체 과목 범위 대조는 미완성 | 2022 본표 공식 기준 19개와 대조 | Batch2 16개 quiz importer 통과; 기존 HTML 매핑 미확인 | 권리 미결; 교사·수학 검토 pending; 통합본 미병합 |
| 21 | 공통수학2 · 2022 | partial | 신규 V2 17모듈/85쪽 및 기존 후보 포함 통합 19모듈/94 원본 지면; 20/20 공식 코드 태그 후보, 전체 범위·내용 매칭 검수 미완료 | 공식 코드 및 세 EqEdit 스크립트를 원본 HWP raw record에서 복구·대조 | quiz 17개 후보; 페이지 보존 검사 통과; 앱 reader/HTML parity 미검증 | 독립 교사 검수·권리 결정 대기; 출판 부적격 |
| 22 | 대수 · 2022 | partial | Batch1 14모듈/70쪽 + EqEdit Batch2 3모듈/15쪽과 기존 등차수열 후보; 통합 18모듈/89 원본 지면; 공식 코드 18/18 태그 후보 | 원본 HWP raw EqEdit 스크립트 03-03/04/05 복구; 상품 전체 범위 및 본문 매칭 검수 미완료 | Batch2 quiz 3개 후보; reader 상호작용 및 HTML parity 미검증 | 교사·수학 검토 및 권리 결정 대기; 출판 부적격 |
| 23 | 미적분Ⅰ · 2022 | partial | 기존 6모듈/18쪽 + 신규 V2 13모듈/65쪽; 20/20 공식 코드 후보 태그, 본문 충족·상품 통합 검토 미완 | 공식 HWP 본표 20개 확인; 코드 태그는 연결 후보이지 내용 검수 완료가 아님 | 현재 compatibility suite BookData round-trip 통과; c1-0101 퀴즈 student BookWidget 실행 통과; HTML parity 미검증 | 독립 교사 검수·권리 결정 대기; 출판 부적격 |
| 24 | 확률과 통계 · 2022 | partial | 기존 통계적 확률 1모듈/3쪽, 보완 1모듈/5쪽 및 V2 후보 16모듈/80쪽; 과목 전체는 미완 | 공식 본표 기준 16개 코드 모두 후보에 연결 | V2 importer 통과; 03-07 mean/proportion statisticsEstimator 후보 QA 통과, 교사·권리 승인 대기 | 통합본 미병합; 상품 전체 대조 미완 |
| 25 | 미적분Ⅱ · 2022 | partial | 기존 삼각함수 미분 2차시/6쪽 + 수열·급수 V2 5모듈/25쪽 + 미분·적분 V2 18모듈/90쪽; 23개 기준 후보 태그 연결, 과목 전체 범위 대조 필요 | 공식 본표 23개 중 23개 tag 후보; 03-01 선행 수식은 HWP 텍스트 추출에서 유실된 상태 | 두 후보 BookData round-trip 통과; Batch2의 02-01 quiz student BookWidget 실행 통과; 03-01 기준 전체 충족·HTML parity는 미확인 | 독립 교사 검토·권리 결정 대기; 출판 부적격 |
| 26 | 기하 · 2022 | partial | 7개 BookData의 14모듈/62 원본 쪽을 3영역 부분 통합초안으로 묶었고 기준 라벨 14쪽을 추가; 앱 reader 통합과 교과서별 전체 범위 대조 미완 | 교육부 HWP 본표 14개 코드 모두 tag 후보 연결(공간도형 4, 벡터 5 신규); 태그는 내용 충족 승인 아님 | 9개 quiz payload 포함; 두 신규 V2 패키지 manifest에 importer 통과 기록; 독립 HTML parity 미검증 | 교사·수학 검토, 권리 확인, 앱 통합 전; 출판 부적격 |

현재 카탈로그 기준 집계: partial 26, missing 0, matched 0. 이는 파일의 교육적 승인 수가 아니다. `student-facing completeness`, `official curriculum match`, `math review`, `rights clearance`, `runtime compatibility`, `publish eligibility`를 별도 단계로 올려야 한다.

## 제작·배포 판단

- 26개를 이름만 만들어 완료로 세지 않는다. 원고 생성은 공식 별책 8의 판본·학기별 성취기준을 추출하고 각 항목을 다루는 새 개념 설명·예시/정답·연습/해설에 연결해 진행한다. 상업 교재의 문장·문제·그림을 복사하지 않는다.
- 초기 자료는 부분 초안 21종, 미작성 5종이었다. 현재 #8–#12에 각각 4개 후보 모듈을 추가했으나 책 전체 완성이나 전국 공통 학기 정렬을 뜻하지 않는다. 전체 26개는 모두 partial이며 학기별 근거가 있는 기준표와 전 범위 원고가 남아 있다.
- 공공 교육과정 문서는 출처 표기와 이용 조건을 각각 확인한다. 원고 문장·문제·그림은 독자 집필 여부 또는 허가/라이선스를 기록한다. 현재 각 파일의 권리 근거가 없어 공개 출판 적격으로 판정하지 않았다.
- 작업 경계: 이 저장소는 원고 원본이다. 학생 앱 변경·웹 빌드·Vercel 배포는 `Upstudy-hotfix`의 승인 브랜치에서만 진행하며 해당 저장소의 AGENTS와 `tools/verify-hotfix-worktree.ps1` 가드를 먼저 따라야 한다. 파일 복사는 현재 승인 원고를 정한 뒤 경로/해시/출처를 명시해 처리한다.
- 이번 원고 수정은 학생 앱을 수정·빌드·배포하지 않았다. `createTextbook()` 스텁 때문에 현재 저장소에서 게시 성공을 주장할 수 없다. 앱 작업과 무관한 기존 dirty files는 그대로 보존한다. 원격 배포 근거는 없다.

## 재개 순서

1. 두 교육과정 공식 원문을 이용해 26개 상품별 기준표(기준 코드·학기·범위·출처)를 만들고 기존 86개 입력 BookData와 학생용 원고를 매핑한다. 학기 배정이 공식 문서에 없는 상품은 편집 후보와 공식 기준 상태를 분리한다.
2. `partial` 26종은 기준표의 빈칸을 오리지널 집필한다. 계산·정답은 자동 검산과 구간 검산을 남긴다.
3. 84개 HTML 자산을 상품별로 연결하고, 디자이너 세션의 선언형 인터랙션/퀴즈 계약으로 기능을 보존한다.
4. 원고별 출처·저작권/라이선스 근거와 수학·교육과정 리뷰 상태를 기록한다. 모든 자동/공식 근거 점검을 통과한 원고는 적격 후보로 분리한다.
5. hotfix 저장소 가드 안에서만 승인 원고를 전달·실제 렌더 검증한다. 공개 배포 적격 항목만 deploy하고 URL/ID/해시/모바일·데스크톱 스크린샷을 확인한다.

재현 명령: `python tool/build_tagged_textbook_drafts.py`

## 2026-10-17 이어서 확인한 사항

- 현행 HEAD/origin은 `99120e885b1cdc2c3e77e144944853ee6b7bf8c5`로 일치했다. 기존 무관 dirty 파일은 유지했다.
- 2022 중등 공식 기준 중 태그가 없던 13개(`9수03-02/04/06/08/10/12/13/14/16/18/19`, `9수04-02/07`)에 도형·통계 후보 13모듈/78쪽/native quiz 13개를 추가했다. 공식 JSON 코드 대조와 각 예시 산술 assert를 생성기에 넣었다. activity round-trip 및 학생 BookWidget 퀴즈 테스트 통과.
- 2022 중등 학년군 기준 exact-tag 인벤토리는 60/60이지만 이는 내용 충족, 상품별 학기 배정 또는 승인 증거가 아니다. 26종 상품은 여전히 partial. 교사·독립 수학·권리 검토 pending.
- 생성기를 pipeline stage 11/85에 등록. 전체 pipeline은 실행하지 않았고 배포도 하지 않았다.
- 이 배치의 HTML 원본 대응/시각 parity는 검증하지 않았으며 BookData에는 native quiz만 연결했다. 외부 HTML 호환/패리티를 주장하지 않는다.

## 2026-10-17 추가 이어서 확인한 사항

- 원장 기준 2015 중등 `9수03-05~10` 6개 함수 기준이 미태그였다. 오리지널 후보 6모듈/36쪽/6 quiz와 native graph 6개를 추가했다. 공식 2015 추출 코드 대조, 함수 대입·교점·포물선 산술 assert, BookData round-trip, 실제 graph builder 생성과 학생 퀴즈 테스트를 통과했다.
- 재생성 원장 기준 2015 중등 학년군 exact tag inventory는 27/61에서 33/61로 증가했다. 나머지 28개는 미태그이며 학기 상품 배정은 확인되지 않았다. 2022 중등은 60/60 후보 태그 상태를 유지한다.
- 파이프라인은 86 stage이며 신규 후보는 stage 12. 전체 pipeline 실행과 배포는 하지 않았다. 신규 manifest는 rights, 교사, 독립 수학 검토 pending, 출판 부적격이다.

## 2026-10-17 2015 중등 도형 배치 1

- 2015 중등 `9수04-01~10` 도형 기준 10개 후보를 10모듈/50쪽/native quiz 10개로 작성했다. 공식 코드 존재 검사, 삼각형 부등식·다각형 각/대각선·부채꼴·다면체 오일러 관계·원뿔 부피·이등변삼각형 산술 assert 통과. BookData round-trip 및 학생 BookWidget 퀴즈 테스트 통과.
- 원장 exact-tag 후보는 2015 중등 33/61에서 43/61로 갱신됐다. 18개 코드가 미태그로 남는다. 2022 중등 60/60 후보 태그 유지. 어느 수치도 학기별 상품 귀속이나 본문 완료 승인이 아니다.
- 파이프라인 87단계, 신규 배치 stage 13. 전체 pipeline 실행/배포 없음. 새 BookData의 권리·교사·독립 수학 검토 pending, 출판 부적격.

## 2026-10-17 2015 중등 통계 완료 태그 배치

- 2015 중등 마지막 미태그 기준 `9수05-01~08` 8개를 통계 후보 8모듈/40쪽/native quiz 8개로 작성했다. 공식 코드 일치와 도수·상대도수·경우의 수·확률·대표값·분산/표준편차 계산 assert를 통과했다. BookData activity round-trip과 학생 퀴즈 테스트 통과.
- 원장 exact-tag 후보는 2015 중등 53/61에서 61/61로 갱신됐다. 2022 중등은 60/60. 양 판본 중등 12개 상품의 코드 인벤토리는 기준 전체에 태그가 있으나, 학기 배정·본문 충족은 여전히 승인되지 않았다.
- 파이프라인 89단계, 신규 통계 후보 stage 15. BookData 전체 metadata 게이트 집계 156개: not_eligible 9, unspecified 147; 검토/권리 근거가 없는 자료는 승인 취급하지 않는다. 전체 pipeline 실행 및 배포 없음.

## 2026-10-17 최신 원장·재개 검증

- 검증 기준 HEAD와 `origin/main`은 `936e4ca528da993c9adf9b0db7eec2b1ecb65034`로 일치한다. 현재 체크아웃의 무관 dirty 작업은 보존했다.
- `python tool/build_textbook_scope_coverage.py` 및 `python tool/audit_2015_upper_lower_scope.py` 재생성: 26개 상품, 1,038 product-standard 행, 2015 고교 기준 41개(기존 제목 후보 23, 부분 후보 8, 신규 V2 10, chapter 후보 없음 0). 태그 없는 행 31개는 2015 상·하권에 중복 표시된 같은 코드이며, 공식 분권 배정은 미승인이다.
- `python tool/build_tagged_textbook_drafts.py --from-stage build_math_2015_missing_criteria_v2.py`로 90단계 중 마지막 5단계를 실행했다. 고교 2015 V2 후보 10개 재생성, 원본 BookData 111개 패키지 참조 검증 통과, HTML 색인 106 standalone HTML 및 재귀 BookData 166개.
- 원장 인벤토리: 공식 판본-코드 쌍 392개, same-edition 태그 361개, exact chapter 코드 315개, 단일 코드·단일 chapter 연결 21개, 구조 신호 없음 60개. 재귀 BookData 166개 중 V2 45개, 선언형 activity 311개.
- scoped Flutter 검증: `textbook_activity_compatibility_test.dart` 97/97 통과, `textbook_bookdata_inventory_roundtrip_test.dart` 3/3 통과. 두 테스트는 공유 캐시 때문에 병렬 실행하지 않고 순차 재실행해 성공 결과를 확인했다.
- 게시/권리/사람 검토 metadata는 166개 중 `not_eligible` 21, `unspecified` 145; 권리·교사 검토는 `pending` 21, `unspecified` 145; 수학 검토는 저자 점검 기록·독립 검토 대기 20, `pending` 1, `unspecified` 145. 승인 증거가 없어 배포하지 않았다.
- 2015 고교 상·하 scope audit를 page-level로 보강했다. 기존 41개 코드·제목 대조는 유지하고, 8개 부분 후보의 실제 4쪽 본문 인용을 생성 시 검증하며 확인된 범위와 미확인 기준 요소를 기록한다. 이는 저자 대조이며 독립 수학·교사 검토를 대체하지 않는다.

## 2026-10-17 공식 원문 권리표시 재확인

- 현재 기준 HEAD와 `origin/main`: `37eb4ca963b08d5655c95580e6c33e3877d6b00d`.
- 로컬 `2015_appendix8_math.pdf`는 2015 교육부 ZIP의 별책 8 파일과 SHA-256이 일치한다(`4bd2b84e978865a71d90577d8eb6240f0ecf24a9884642d627cde460d71ab88e`). 156쪽 전체 PDF 텍스트에서 `공공누리`, `KOGL`, `저작권`, `이용허락` 등 표시 용어는 0건이며 표지와 마지막 PDF 페이지 렌더에서도 라이선스 표시는 보이지 않았다. 이미지 전체의 법적 표시는 이 검사만으로 단정하지 않는다.
- 로컬 `2022_appendix8_math.hwp`도 2022 교육부 ZIP의 별책 8 파일과 SHA-256이 일치한다(`aab8eed59ecf244223d04afad75f4cf5ac5085fadcfc3cf52c2f6d54ddfc7856`). HWP 텍스트 추출에서 `공공누리`/`KOGL`은 0건이다. `저작권` 1건은 학습자료 출처를 밝히라는 교육과정 문맥이지 이용허락 표시가 아니다. 이미지·시각 요소는 별도 권리 표시 증거로 검증되지 않았다.
- 교육부 [2015-74 고시 게시물](https://www.moe.go.kr/boardCnts/view.do?boardID=141&boardSeq=60747&lev=0&m=0404)은 별책 1–15 ZIP을 제공하고 별책 8이 수학과임을 명시하지만, 첨부 ZIP에 적용되는 개별 KOGL 표시를 게시물 본문에서 확인하지 못했다. 별도 [2015 교육과정 안내 페이지](https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=316&boardSeq=62381&lev=0&m=0302&opType=N&page=1&s=moe&searchType=null&statusYN=C)의 KOGL 제2유형은 그 안내 저작물에 붙은 표시라 별책 ZIP에 전이하지 않는다.
- 교육부 [2022-33 고시 게시물](https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=141&boardSeq=93458&lev=0&m=0404)은 수학과 별책 8을 포함하는 ZIP을 제공하지만 첨부별 KOGL 조건은 본문에서 확인되지 않았다. 별도 [2022 개정 교육과정 발표자료](https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=294&boardSeq=93459&lev=0)의 제1유형 표시도 그 발표자료의 저작물 표시이므로 고시 ZIP의 권리 근거로 사용하지 않는다.
- 교육부 [저작권 정책](https://www.moe.go.kr/sub/infoRenew.do?m=070105&page=070105&s=moe)은 KOGL 부착 자료의 유형별 이용조건을 확인하도록 하고, 표시 없는 자료는 공공저작물 실무 담당자와 사전 협의하도록 안내한다. 따라서 2015·2022 원문과 기존 HTML/외부 요소의 상업 이용·변형 권한은 계속 pending이다. 별책 재사용에 대한 서면 권리 확인 전 배포하지 않는다.

## 2026-10-17 HTML 자산 정적 참조 문맥

- `tool/build_html_asset_inventory.py`와 `REMAINING_TEXTBOOKS_HTML_ASSET_INDEX.md`를 보강해 HTML 파일명이 언급된 JSON 경로, 같은 chapter의 native activity 종류를 기록한다. 재생성 결과는 106 HTML/166 BookData, 정확한 파일명 참조 27개, `external_interactive_assets` metadata 명시 1개, 같은 chapter에 선언형 activity가 있는 자산 20개다.
- 이 표는 정적 참조만 분류한다. 파일명 언급이나 native activity 병존을 실행 연결 또는 인터랙션 parity 증거로 간주하지 않는다. 권리·교사·독립 수학 검토는 계속 미완료이며 배포하지 않는다.

## 2026-10-17 2015 고교 부분 기준 보충 V2

- 기존 본문 대조에서 범위 요소가 빠진 8개 기준(`10수학01-10/11/12/16`, `02-02/09`, `03-01/04`)을 각각 4쪽 보충 BookData와 native quiz로 작성했다. 주제는 포물선-직선 교점, 이차함수 최댓값·최솟값 활용, 치환을 이용한 사차방정식, 이차함수 관계와 연립이차부등식, 내·외분점, `y=x` 대칭, 집합 정의·표현, 전칭·존재 명제다.
- 생성기 `tool/build_math_2015_partial_criteria_completion_v2.py`를 resumable draft pipeline stage 87/91에 추가하고, 2015 고교 audit에 보충 파일/코드/대상 범위 표를 추가했다. 보충은 기존 통합본과 분리돼 있으며 자동으로 상품 완료 처리하지 않는다.
- 생성기 산술·집합·명제 assert와 4쪽·코드·quiz 구조 검증 통과. `flutter test --reporter compact test/textbook_bookdata_inventory_roundtrip_test.dart` 3/3 통과; `flutter test --reporter compact test/textbook_activity_compatibility_test.dart` 113/113 통과. 두 테스트에 새 BookData 왕복과 학생 BookWidget quiz 제출/피드백을 포함했다.
- 최신 재생성 원장: 26개 상품/1,038 product-standard 행/111 root source BookData; 392 official edition-code 쌍 중 same-edition tag 369, chapter exact-code 323, 단일-code 단일-chapter 21, 구조 신호 없음 52. 재귀 BookData 174개 중 출판 부적격 29, 권리·교사 검토 pending 29, 미지정 145; 신규 8개 포함. 독립 수학검토·권리 확인이 남아 배포하지 않았다.

## 2026-10-17 수학Ⅰ 로그·함수 보충 V2

- 최신 코드-챕터 원장에서 2015 수학Ⅰ `12수학Ⅰ01-04`, `01-06`은 기존 BookData의 root code tag는 있으나 chapter code anchor가 없었다. 기존 로그 시범은 로그의 뜻·밑 조건을 다루지만 로그 성질의 연습은 부족했고, 지수·로그함수의 정의역·치역과 역함수 관계를 별도 chapter에서 제시하지 않았다. 공식 PDF 추출문구와 기존 본문을 대조해 두 기준의 보충 필요를 확인했다.
- 두 기준별 5쪽 native BookData chapter를 생성했다. 로그의 곱·몫·거듭제곱 성질과 정의역 조건을 설명하고, 지수함수·로그함수 정의·정의역/치역·역함수 관계를 예제와 연습으로 보강했다. 두 chapter에는 native quiz, 함수 관계 chapter에는 `y=2^x`, `y=log₂x`, `y=x`의 native graph를 넣었다. 기존 HTML visual parity는 주장하지 않는다.
- `tool/build_math1_2015_log_completion_v2.py`를 resumable pipeline stage로 등록했다(총 92단계). 공식 코드 문구, 로그 항등식·역함수, 정의역 조건 assert 및 BookData 구조 검사 통과. 재귀 전체 왕복·그래프 검사 3/3; student BookWidget quiz 제출·피드백 포함 activity 호환성 115/115 통과.
- scope 원장 최신 수치: 26개 상품/1,038 product-standard 행/112 root source BookData/175 재귀 BookData. 392 판본-기준 쌍 중 same-edition tag 369, chapter exact-code 325, 단일-code 단일-chapter 21, 구조 신호 없음 50. 게시 부적격 30, 권리·교사 검토 pending 30, 미지정 145. 새 후보는 독립 수학·교사·권리 검토 대기이며 배포하지 않았다.

## 2026-10-17 2015 수학Ⅰ 지수·로그 기준 보완 Batch2

- 실제 내용 gap인 `12수학Ⅰ01-04`(로그 성질) 및 `12수학Ⅰ01-06`(지수·로그함수 정의/역관계)을 대상으로 2개 장, 10쪽, 퀴즈 2개, native graph 1개, HTML 체험 조작을 옮긴 `logarithmPowerExplorer` 1개를 생성했다. 생성기를 두 번 실행한 BookData SHA-256은 동일했다.
- 새 activity payload는 제한된 숫자 설정만 허용하며, 학생 뷰에서 밑 선택·지수 조절·단계별 그래프 안내·힌트·초기화를 제공한다. 원 HTML의 구체적인 밑/지수 범위, 퀴즈 및 독립 연습을 대응시켰다. 화면 시각 parity는 승인 검토 전이다.
- 호환성: BookData round-trip 3/3, 전체 textbook activity compatibility 116/116 통과. Python 생성기 compile, `git diff --check` 통과. scope ledger는 26개 상품/1,038 기준 행, 재귀 BookData 175개/선언형 activity 322개이며 구조 신호 없음 50개다.
- pipeline stage 44/92에 등록했다. 신규 원고는 publication `not_eligible`, rights·teacher review pending이며 배포하지 않았다. 독립 수학 검토도 남아 있다.

## 2026-10-17 2015 수학(상) 다항식 사칙연산 보완

- 2015 기준 `10수학01-01`의 기존 챕터 본문을 확인했다. 해당 후보는 동류항 덧셈·뺄셈만 다루고, 공식 기준의 곱셈·나눗셈을 다루지 않아 실질 공백으로 판정했다. 비슷한 2022 후보는 판본 연결을 대체하지 않는다.
- 보충 V2 1개 장/6쪽을 추가해 분배법칙, 나눗셈의 몫·나머지, 곱셈 퀴즈를 다룬다. 공식 2015 기준 문구와 chapter code를 검증하고 계산 assert를 둔다. 새 원고는 별도 파일이며 기존 후보를 덮어쓰지 않는다.
- Pipeline 45/93에 등록. 최신 재귀 inventory 176 BookData, 113 root source BookData, 106 HTML. 교사·독립 수학·권리 검토 대기 및 출판 부적격.

## 2026-10-17 2022 공통수학Ⅱ 유리함수 그래프 보완

- 2022 기준 `10공수2-03-04`의 기존 V2 챕터를 본문 단위로 대조했다. 정의역과 점근선 설명은 있으나 실제 그래프 작도·그래프 성질 탐구가 없어 부분 충족으로 판정했다. 공식 기준은 그래프와 성질 탐구를 요구한다.
- 연결된 `공통수학2_유리함수_체험형_시범.html`의 a 선택, h/k 슬라이더, 단계 안내, 초기화, 정의역/점근선 퀴즈, 힌트 동작을 확인하고 native `rationalFunctionExplorer`·quiz로 대응했다. 7쪽 보충은 정의역, 두 점근선, 두 점의 함수값, a 부호에 따른 가지 위치를 설명한다. 시각 parity는 사람 검토 전이다.
- 새 activity는 수치 payload만 허용하고 `y=a/(x-h)+k`를 안전하게 렌더한다. BookData 왕복 3/3, 전체 activity compatibility 121/121 통과; 개별 매개변수·단계·힌트·초기화 widget test 포함. 생성기 두 번 실행 SHA-256 동일.
- Pipeline stage 46/94. 원장: 26 상품/1,038 기준 행/114 root source/177 recursive BookData/325 activities/106 HTML; official edition-code 392 중 same-edition tags 370, chapter anchor 327, unlinked structural pairs 48. metadata 상태는 publication `not_eligible` 32, rights/teacher pending 32, author math checks with independent review pending 31, math pending 1, unspecified 145.
- 권리·독립 수학·교사 검토 및 시각 대조는 남아 출판/배포하지 않는다.

## 2026-10-17 2022 공통수학Ⅱ 무리함수 그래프 보완

- 2022 기준 `10공수2-03-05`의 기존 V2 장을 대조했다. 정의역과 시작점 예는 있지만 그래프 데이터나 그래프 작도·성질 탐구가 없어 해당 기준을 부분 충족으로 판정했다. 이름이 맞는 별도 HTML 인터랙션은 현재 106개 asset 색인에서 확인되지 않아, 출처 없는 외부 parity를 주장하지 않는다.
- native `radicalFunctionExplorer` 및 quiz를 포함한 별도 7쪽 보충 생성. a/b/c 수치 제어, 그래프, 정의역, 시작점, 치역 안내, 단계별 설명, 힌트, 초기화를 구현했다. 입력은 범위가 제한된 숫자만 받는다.
- 생성기 공식 기준·식·시작점 계산 assert 통과. BookData round-trip 3/3, 전체 activity compatibility 124/124 통과. 위젯 테스트에서 a/b/c 변경, 정의역 변화, 단계 안내, 초기화 검증. Pipeline stage 47/95.
- 원장: 26개 상품/1,038 기준 행/115 root source/178 recursive BookData/327 activities/106 HTML; official edition-code 392 중 same-edition tag 370, chapter anchor 328, 구조 신호 없음 47. metadata 집계: publication not_eligible 33, rights/teacher pending 33, author math checks with independent review pending 32, math pending 1, unspecified 145.
- 사람의 독립 수학·교사 검토와 권리 확인 전 출판하지 않는다.


## 2026-10-17 태그별 초안 파이프라인 48–50단계 재개

- `build_math_1_2015_draft.py` 단계를 다시 실행했다. 16개 모듈에 원본 83쪽을 보존하고 page ID 중복 검사를 통과했다. 기존 dirty README는 실행 전후 바이트를 비교해 그대로 복원했다.
- 2015 수학Ⅱ 미연결 기준 Batch1 생성기는 공식 기준 18개, 18모듈·90쪽·18퀴즈 후보를 생성했다. BookData SHA-256은 `17635B9E58B0A4D706453A2D6AB20A535631C194DFC1CCC136608D5E26E02601`이다. 통합 결과는 22모듈, 보존 지면 102쪽이며 페이지 ID가 고유하다.
- BookData 왕복 및 활동 호환성 테스트가 통과했다. 범위 원장은 26개 상품·1,038 기준 행·115 root source BookData, 392 공식 판본-코드 쌍 중 same-edition tag 370, exact chapter anchor 328, 단일 코드·단일 chapter 연결 21, 구조 신호 없음 47을 기록한다. 재귀 BookData 178개 중 33개 `not_eligible`, 145개 eligibility 미지정; 권리·교사 검토는 33 pending/145 unspecified, 수학 검토는 32 author checks with independent review pending, 1 pending, 145 unspecified다. HTML 인벤토리는 106개다.
- 이 단계들은 생성·구조 검증이며 수학 독립검토, 교사 승인, 권리 결정, 사용자 화면 전체 parity를 대체하지 않는다. 배포하지 않았다. 전체 95단계 파이프라인은 미완료다.


## 2026-10-17 2015 확률과 통계 후보 단원 통합 보완

- 2015 확률·통계 V2 후보가 기존 태그 통합기에서 빠지는 것을 확인했다. 통합기는 제한된 파일명만 읽고, 후보의 일반 상태 태그를 단원명으로 오인했다.
- 통합기 입력을 V2 파일까지 포함하도록 넓히고, `12확통01/02/03` 공식 코드로 각각 순열과 조합·확률·통계 단원을 연결했다. 기존의 명시 단원 태그는 그대로 유지한다.
- Batch1 2모듈·10쪽, Batch2 15모듈·75쪽 후보를 포함해 19모듈·91개 원본 쪽을 5개 단원으로 통합했다. page signature 보존 및 고유 ID 검사가 통과했다.
- BookData 왕복 테스트, 전체 activity compatibility 124/124, 26상품 범위 장부, 106 HTML 인벤토리, 115 root BookData 패키지 참조 검증이 통과했다. 재귀 BookData는 178개이며 392 공식 판본-코드 쌍 중 same-edition tag 370, chapter anchor 328, 구조 신호 없음 47이다.
- 교사·독립 수학·권리 검토는 여전히 대기 상태다. 이 통합은 초안 생성과 페이지 보존을 확인한 것이며 검수 승인이나 배포 자격을 뜻하지 않는다.


## 2026-10-17 2015 미적분 태그별 단원 통합

- 미적분 2015 V2 생성기가 공식 기준 후보 27개에 대해 27모듈·135쪽을 생성했다. 생성기 산술 검사와 code 후보 검사가 통과했다.
- 단원 통합기는 기존 수열 원고와 새 후보를 28모듈·138개 원본 쪽으로 정리했고, 페이지 서명 보존과 고유 ID 검사를 통과했다. 기존 HTML/그래프 parity와 전체 과목 상품 범위는 별도 미검증이다.
- BookData 왕복과 전체 activity compatibility 124/124 통과. 현재 인벤토리는 26상품/1,038 기준 행/115 root BookData/178 재귀 BookData/106 HTML이며 392 공식 판본-코드 중 same-edition tag 370, chapter anchor 328, 구조 신호 없음 47이다.
- 이 원고도 독립 수학·교사·권리 검토 대기 및 출판 부적격이다.


## 2026-10-17 판본 미확인 태그 샘플 패키징 단계 56–57

- 판본이 명시되지 않은 정수 단원 3쪽을 `중1수학_판본미확인_태그초안`으로 패키징했다. 페이지 ID 고유성 및 원본 블록 보존 검사를 통과했다.
- 나머지 태그 기반 샘플 6그룹도 각각 보존 검사를 통과했다: 2022 후보 일차함수 7쪽, 판본 미확인 중학교 9쪽, 공통수학2 6쪽, 2022 후보 대수 4쪽, 판본 미확인 대수 3쪽, 판본 불명 확률과 통계 3쪽.
- 현재 BookData 패키지 참조 검증은 root source 115개 전체에서 통과했고, BookData 왕복 테스트도 통과했다.
- Stage 57의 기존 tag 기대값이 현재 일차함수 source의 공식 `2022 개정` 태그와 달라 중단되던 검사를 수정했다. 이제 기준 코드와 판본 정보가 있는 source는 해당 판본 후보로 패키징하고 판본 미확인 묶음에 중복 배치하지 않는다.
- 샘플은 범위·교사·수학·권리 검토 및 앱 통합 승인이 아니다.


## 2026-10-17 2015 수학 상·하 태그 샘플 단계 58–69 재검증

- 2015 수학(상) 다항식 연산·나머지정리·인수분해 및 수학(하) 집합·명제·함수·경우의 수·순열·조합·유리함수·무리함수 샘플 생성기를 순서대로 재실행했다. 각 생성기는 4쪽 구조와 고유 page ID를 확인했다.
- 두 공유 README의 기존 29개 및 18개 하위 제목이 전부 유지되는 것을 확인했다. 재실행 시 README 전체를 덮어쓰던 다항식 연산·집합 생성기를 각자 섹션만 갱신하도록 수정했다.
- BookData 왕복, 전체 activity compatibility 124/124, 범위/HTML 원장, 115 root BookData 패키지 참조 검증이 통과했다. 원장은 26상품/1,038 기준 행/178 재귀 BookData/106 HTML이며, 392 공식 쌍 중 same-edition tag 370, chapter anchor 328, 구조 신호 없음 47이다.
- 이 샘플은 공식 코드 대조, 교사·독립 수학·권리 검토 및 학생 파일럿의 대체물이 아니다.


## 2026-10-17 2022 공통수학Ⅰ 태그 통합 단계 70–72 재검증

- 공통수학Ⅰ 2022 누락 기준 V2 3모듈·18쪽과 미연결 기준 Batch2 16모듈·80쪽 생성기를 재실행했다. 통합기는 26개 모듈을 4개 단원으로 분류하고 135개 원본 쪽을 보존했으며 page ID 검사를 통과했다.
- BookData 왕복, 전체 activity compatibility 124/124, 26상품 범위/106 HTML 원장, 115 root BookData 패키지 참조 검증이 통과했다. 이 단계 산출물은 현재 커밋과 동일해 새 파일 변경은 없다.
- 재귀 BookData 178개 가운데 출판 eligibility not_eligible 33, unspecified 145; 교사/권리 pending 33·unspecified 145; 수학 검토 author checks with independent review pending 32·pending 1·unspecified 145다. 따라서 배포하지 않았다.


## 2026-10-17 2015 수학 상·하 보완 및 전체 재개 파이프라인 검증

- Stage 73–89의 17개 수학(상) 태그 샘플을 재실행했다. Stage 90의 2015 기준 10개 신규 후보, stage 91의 부분 충족 기준 8개 보완 후보, stage 92의 상·하 단원 통합기를 각각 실행했다. 통합 결과는 수학(상) 3개 단원·23개 소단원·92쪽, 수학(하) 3개 단원·16개 소단원·64쪽이다.
- Stage 93–95를 pipeline resume로 연속 실행했다. 공식 기준 지도는 26개 상품, 범위 원장은 26개 상품·1,038 product-standard 행·115 root BookData, HTML 인벤토리는 106 HTML·178 recursive BookData를 기록했다. 패키지 참조 검증은 root BookData 115개 전체에서 통과했다.
- BookData 왕복 및 전체 activity compatibility 124/124 통과. 동일 원장 기준 392 공식 판본-코드 쌍 중 same-edition tag 370, exact chapter anchor 328, 단일 코드·단일 chapter anchor 21, 구조 신호 없음 47이다. 이 수치는 내용 충족이나 승인 수가 아니다.
- 검수 inventory: 33 BookData `not_eligible`, eligibility·권리·교사 검토 미지정 145, 권리 및 교사 pending 33, author math checks with independent review pending 32, math pending 1. 47 구조 미연결 쌍과 수학·교사·권리 gate가 남아 있어 배포하지 않았다.
- 전체 생성기 95단계는 기존 체크포인트의 1–47단계와 이번 재개의 48–95단계를 합쳐 완료했다. 다음 작업은 구조 미연결 기준을 코드별로 대조해 실제 공백과 불확실 매핑을 구분하고, 검수 게이트를 해소하는 것이다.

## 2026-10-17 코드 미연결 원본 43개 보수적 대조

- 재귀 BookData 중 공식 코드 토큰이 없는 43개 원본을 분류했다. 31개에는 검토 대기 후보 코드 연결, 3개는 현재 상·하 감사표와 직접 연결할 수 없었고, 9개는 판본 또는 기준 근거가 부족해 미분류로 남겼다.
- 별도 [미연결 BookData 감사표](REMAINING_TEXTBOOKS_UNTAGGED_BOOKDATA_AUDIT.md)에 각 원본, 후보 코드, 부분 범위 및 근거 한계를 기록했다. 원본 태그는 바꾸지 않았다. 후보는 내용 충족·승인·출판 자격을 뜻하지 않는다.
- 명시적 2015 수학Ⅱ 정적분 면적 후보는 공식 `12수학Ⅱ03-05`로 바로잡았다. 2015 상·하 후보는 별도의 chapter 후보 대조표를 근거로 했다.
- 이번에는 coverage audit generator 단계만 재실행했다: 26상품·1,038 상품-기준 행·115 root / 178 recursive BookData. 재귀 178개 중 exact field/tag code 135, 출판 `not_eligible` 33, unspecified 145, 독립 승인 인정 0. 전체 95단계 파이프라인을 다시 돌린 것은 아니다.
- 최신 범위 원장은 392개 공식 판본-코드 쌍 모두에 field/tag 신호, 342개 exact chapter anchor, 21개 단일코드·단일chapter 연결, 75개 검토 대기 candidate chapter mapping, exact/candidate 구조 신호 누락 0개를 기록한다. 이 최신 구조 신호 집계가 위 Stage 95 시점의 47개 누락 기록을 갱신하며, 내용 충족·승인을 뜻하지 않는다.

## 2026-10-17 현재 체크아웃 교재 호환성 재검증

- `flutter test --reporter compact test/textbook_bookdata_inventory_roundtrip_test.dart test/textbook_activity_compatibility_test.dart` 종료 코드 0, 127개 테스트 통과. 왕복 테스트는 재귀 BookData 178개 모두를 검사하고, activity suite는 현재 지정된 후보 파일의 payload 보존과 학생·교사 리더 상호작용을 확인한다.
- 이는 BookData 직렬화와 선택된 네이티브 활동 렌더링 검증이다. 106개 HTML 전체 화면 동등성, 실제 저장 API/DB, 실사용자 검증을 증명하지 않는다.
- 외부 릴리스 경로 `Upstudy-hotfix`의 현재 `HEAD`와 `origin/hotfix`는 모두 `ad4a763`이며, manifest builder와 runtime 모두 publication, cleared rights, teacher, math, curriculum approval을 요구한다. 현재 원장상 네 게이트가 모두 승인된 교재는 0개이므로 교재 배포는 진행하지 않았다.
- 릴리스 계약 회귀 검증: 현재 `Upstudy-hotfix`의 `ad4a763`에서 bookdata create contract/import, public-textbook release gates, author compatibility, graph math security 5개 suite가 `51 passed`로 통과했다. Starlette/httpx deprecation warning 1건이 있다. 이는 승인 누락 거부 동작을 검증하며, 승인 대상이 생겼거나 배포·DB·실사용이 완료됐다는 증거는 아니다.
- 미연결 원본 중 명시적 2015 후보 5개를 source-level 산술·범위 기준으로 점검했다: 벡터 내적의 −5/6, 수열극한 1·3, 직사각형 합 12와 삼각형 넓이 18, 이항확률 3/8·평균 2, 조건부확률 2/3은 기재 계산과 일치한다. 수열극한·면적·이항분포는 기준 범위가 부분만 확인되어 감사표에 partial candidate로 남겼다.
- 5개 중 native `vectorInnerProduct`만 학생 리더 activity로 확인됐다. 나머지 4개의 시각 조작은 별도 HTML이며 BookData에서 자동 실행되지 않는다. HTML 전체 화면·동작 패리티는 미검증이다. 이 산술 점검은 교사·독립 수학검수가 아니다.

- 추가 페이지 대조로 2015 수학(하) 여집합·차집합 원본을 `10수학03-03` 부분 후보로 연결했다. 표본 계산은 맞지만 합집합·교집합 범위는 이 파일에 없어 partial로 유지한다. 따라서 43개 중 candidate link는 32, 상·하 감사표 직접 후보 없음은 2, 판본/기준 미확정은 9로 갱신했다.

## 2026-10-17 패키지 검수 manifest 증거 대조

- 재귀 검색한 `REVIEW_MANIFEST.json` 30개를 확인했다. 전부 `publication_eligibility=not_eligible`이며, publication/rights/teacher/math/curriculum 전 항목이 모두 승인으로 표기된 record는 0개다.
- manifest가 지목하는 BookData 및 source BookData 32개 SHA-256 참조를 현재 파일과 대조했다. CRLF 정규화 해시 또는 raw 해시 기준 32/32 일치했다. 해시 일치는 현재 파일의 내용 식별만 증명하며, manifest의 미승인 상태를 승인으로 바꾸지 않는다.
- 원고 인벤토리 178개 중 manifest를 가진 패키지가 30개뿐이라는 점도 구분한다. 나머지 148개는 manifest 승인 증거가 없으며 BookData metadata 역시 승인으로 확인되지 않는다.
- 런타임 검증 provenance도 분리했다: 30개 manifest 중 11개는 `runtime_validator_candidate_sha256`가 현재 BookData manifest SHA와 일치하는 pass, 10개는 pass 표시는 있으나 후보 SHA 결속이 없다. 나머지 9개는 pending 또는 unspecified다. 전부 `not_eligible`이며, hash-bound pass도 사람/권리 승인으로 승격되지 않는다.
