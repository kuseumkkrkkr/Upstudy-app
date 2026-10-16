# 남은 교재 제작·출판 체크포인트

기준일: 2026-10-17
상태: 26개 카탈로그 성취기준 대조 진행 · tag 기반 후보 원고 확장 중 · 출판 경로 미검증

## 2026-10-17 최신 재검증

직전 전체 tag generation pipeline은 76단계와 원본 BookData 105개 참조를 통과했다. 이후 EqEdit 배치 생성 단계 2개를 파이프라인에 추가했고, 이번에는 두 과목의 배치 생성기·통합기·coverage 원장·Python 문법을 범위 지정 실행했다. 현재 78단계가 구성돼 있으나 전체 재실행은 아직 하지 않았다. 현재 scope 원장은 원본 BookData 107개를 집계한다.
- 커버리지 원장은 이제 `standard_codes`/`standard_code`와 tags의 exact official-code token을 검사한다. 판본은 `curriculum_version` 또는 명시적인 판본 태그에서만 확인하고, 파일명으로 추정하지 않는다. 이에 따라 2015 중학교 학년군 태그 27개, 2022 중학교 학년군 태그 30개가 각각 확인됐지만, 이 기준은 학기별·상품별로 배분하지 않았다.
- 범위 표기 재점검: #1–#12의 27/30은 학년군 코드 태그 원고 인벤토리이며 6개 학기 상품 각각의 coverage가 아니다. #13–#14는 공식 `<수학>`의 41개 코드를 함께 기준선으로 표시할 뿐 상·하권 배분이 승인되지 않았으므로 두 상품의 태그 수를 `분권 미확정`으로 표기한다. 상품별 본문 충족 수치는 어느 행에도 승인된 것이 없다.
- Official-code candidate tags: #15 수학Ⅰ(2015) 19/19, #16 수학Ⅱ(2015) 21/21, #17 확률과 통계(2015) 17/17, #18 미적분(2015) 27/27, #19 Geometry (2015) 16/16, #20 공통수학1(2022) 19/19, #21 공통수학2(2022) 20/20, #22 대수(2022) 18/18, #23 미적분Ⅰ(2022) 20/20, #24 확률과 통계(2022) 16/16, #25 미적분Ⅱ(2022) 23/23, #26 기하(2022) 14/14. Counts are tag candidates, not content-completion claims.
- Mathematics II (2015): authored 18 original modules/90 pages for the 18 standards without current candidate tags. Existing four tagged modules/12 source pages were retained; the integrated draft contains 22 modules/102 pages. Numeric spot checks, unique page IDs, official code set, the 72-step pipeline, and guarded app `BookData.fromJson` import passed. New content remains pending independent teacher review and rights clearance; publication is ineligible.
- 공통수학2 신규 후보는 Batch1 14모듈/70쪽/quiz 14개와 Batch2 3모듈/15쪽/quiz 3개다. Batch2는 원본 HWP raw `EqEdit`에서 `10공수2-01-07`의 x, y, y=x; `10공수2-03-04`의 유리함수 기본형; `10공수2-03-05`의 무리함수 기본형을 복구해 기록했다. 기존 두 BookData를 포함한 단원 그룹 초안은 19모듈, 원본 지면 94개를 보존했으며, 태그 후보는 공식 20/20이다. 배치별 예제 검산과 페이지 보존 검사는 통과했지만 전체 과목 범위·수학 내용·교사 검수·권리 결정은 미완료다. 출판 부적격이며 앱 통합/배포는 하지 않았다.
- 수학Ⅰ(2015) 기존 4개 BookData의 코드 후보 10개를 예비 연결하고, 누락 9개 공식 코드와 기존 삼각함수 원고의 탄젠트 그래프 보완 1모듈을 신규 V2 10모듈/50쪽/quiz 10개로 작성했다. 2015 원문 지면은 23쪽 보존, 기존+신규 14모듈/73쪽이 3개 단원 통합 초안에 들어갔다. strict importer가 기존 4개와 신규 V2 1개를 모두 통과했고, validator HEAD `d64f05551e69bbb1b31f262b91d41f163abad66`; 신규 SHA-256 `bfaff24de6d646a90a44177ea462a46987d03a4a657d77846a25c3dfccb1cb33`다. 이 19/19는 후보 태그 수이며, 01-04/01-06, 02-02, 03-07/03-08의 본문은 부분 후보라 독립 교사 검수·권리 결정 전 출판 부적격이다. 기존 HTML은 독립 자산으로 남아 앱 parity 미검증이다.
- 2022 공식 HWP raw record에서 EqEdit 스크립트를 직접 복구해 16개 기준 행에 기록했다. 추출 XHTML은 해당 객체를 시각적 수식으로 표현하지 않지만 JSON에는 원문 script가 있다. 원고 작성 시 script를 추적하고, 해석·표기 검토는 교과 검토 단계에서 한다.
이전 parser-only 27개 파일 검사는 activity 왕복 보존을 증명하지 못했다. 이후 `BookContentBlock.activity` 직렬화와 공용 quiz UI/reader 렌더를 구현했다. Algebra V2 14개, Geometry 2015 V2 12개, Geometry 2022 space/vector V2 9개 등 총 35개 quiz payload의 `fromJson→toJson` 동일성, 학생 BookWidget 선택/피드백, 실제 2022 Geometry V2 원고를 teacher course-reader에서 스크롤·선택·제출하는 동작이 통과했다. 전용 Flutter 테스트 9건 및 변경 Dart 파일 analyzer 통과. 서버/DB 저장 API와 독립 HTML 실행·화면 패리티는 검증하지 않았으며 수학·교사·권리 검토와 게시 승인은 대기 중이다. 운영 반입/배포는 하지 않았다.

- 미적분Ⅰ(2022) 공식 HWP 본표에서 20개 코드를 확인했다. 새 V2 후보는 기존에 미태그였던 13개 기준을 13모듈/65쪽/quiz 13개로 보완했다. 별도 기존 BookData 5개에는 02-01~05 후보 태그가 이미 있었으나 판본/공식 `standard_codes` 메타데이터가 비어 원장에서 제외되고 있었다. 공식 기준 인덱스 및 상품 목차 후보와 대조해 해당 필드를 기록했으며 원장은 20/20 candidate tags로 재생성됐다. 이는 본문 충족 승인이 아니다. 통합 초안은 기존 6모듈/18쪽과 신규 13모듈/65쪽을 보존한다. 숫자 예제 산술 assert와 65개 페이지 ID 중복 검사는 통과했다. guarded Flutter importer 확인은 Dart VM 컴파일 단계에서 내부 FFI 변환 crash가 나서 미확인 상태다. 신규 SHA-256 `7AC68EC35CEDBE963827EB2245A394E348837F73F5E37D95F4A7465A231A8CE1`; 수학 교사 검토·권리 결정 대기 중이며 출판 부적격이다.

- Calculus (2015): generated original candidate content for 27 official standards (27 modules/135 pages); the existing 3-page source remains preserved separately. Unit integration preserves 138 source pages. Arithmetic spot checks, official-code set check, unique IDs, pipeline, and guarded app parser passed. Rights clearance and independent math review are still pending, so it is not publish eligible.
- Geometry (2015): mapped 4 existing vector sources to 4 provisional, partial standard candidates and authored 12 V2 modules/60 pages for the remaining codes. Integration preserves 78 original pages across 18 modules and adds 18 source-label pages. Unit counts: conics 4 modules, vector applications 1, spatial geometry 7. All 12 quiz payloads round-trip exactly; student and active teacher course-reader quiz interaction passed. Five related HTML assets remain separate from BookData; HTML execution/parity, rights and teacher review remain open.
- 대수(2022): Batch1 14 modules/70 pages and EqEdit Batch2 3 modules/15 pages with 3 quizzes each; existing arithmetic-sequence candidate included in the integrated draft makes 18 modules/89 original source pages plus 18 integration labels. Candidate tags cover 18/18 official codes. Batch2 records raw HWP scripts for `12대수03-03/04/05`; all 17 generated Algebra V2 quiz payloads round-trip through the app model, and the 10-test compatibility suite passes. Direct Algebra Batch2 teacher-reader execution, server/database persistence, related HTML runtime/parity, source rights and independent content review remain unverified; deployment is ineligible.
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
| 17 | 확률과 통계 · 2015 | partial | 기존 조건부확률·이항분포 2모듈/6쪽 및 신규 V2 후보 17모듈/85쪽; 17개 공식 코드 모두 tag 후보 연결 | `12확통02-05`, `12확통03-03`; 15개 기준과 상품 범위 대조 필요 | V2 quiz 17개 importer 통과; 기존 HTML 자산은 별도이며 parity 미확인 | 교사·권리 검토 대기 |
| 18 | Calculus · 2015 | partial | Existing sequence-limit sample/3 pages + new V2 27 modules/135 pages; integrated 28 modules/138 source pages; 27/27 code tag candidates | 2015 Appendix 8 codes checked; full product scope and content quality review remain pending | Guarded `BookData.fromJson` passed at `e0bc17074481259c6f8d4c63894da07dd6c2e814`; interactive HTML parity unverified | Independent teacher review and rights decision pending; not publish eligible |
| 19 | Geometry · 2015 | partial | Existing vector 6 modules/18 pages + new V2 12 modules/60 pages; integrated 18 modules/78 original pages; 16/16 candidate codes | 2015 Appendix 8 checked; existing vector mappings partial; all 12 absent/untagged standards newly drafted | Guarded app parser passed for 4 existing sources and V2 batch; 5 related HTML files retained separately; no HTML runtime/parity claim | Independent teacher review pending; existing-source rights unverified; new draft rights decision pending; not publish eligible |
| 20 | 공통수학1 · 2022 | partial | 기존 7모듈/37쪽 및 별도 후보 19모듈/98쪽(3+16); 19개 공식 기준에 태그 후보 연결, 전체 과목 범위 대조는 미완성 | 2022 본표 공식 기준 19개와 대조 | Batch2 16개 quiz importer 통과; 기존 HTML 매핑 미확인 | 권리 미결; 교사·수학 검토 pending; 통합본 미병합 |
| 21 | 공통수학2 · 2022 | partial | 신규 V2 17모듈/85쪽 및 기존 후보 포함 통합 19모듈/94 원본 지면; 20/20 공식 코드 태그 후보, 전체 범위·내용 매칭 검수 미완료 | 공식 코드 및 세 EqEdit 스크립트를 원본 HWP raw record에서 복구·대조 | quiz 17개 후보; 페이지 보존 검사 통과; 앱 reader/HTML parity 미검증 | 독립 교사 검수·권리 결정 대기; 출판 부적격 |
| 22 | 대수 · 2022 | partial | Batch1 14모듈/70쪽 + EqEdit Batch2 3모듈/15쪽과 기존 등차수열 후보; 통합 18모듈/89 원본 지면; 공식 코드 18/18 태그 후보 | 원본 HWP raw EqEdit 스크립트 03-03/04/05 복구; 상품 전체 범위 및 본문 매칭 검수 미완료 | Batch2 quiz 3개 후보; reader 상호작용 및 HTML parity 미검증 | 교사·수학 검토 및 권리 결정 대기; 출판 부적격 |
| 23 | 미적분Ⅰ · 2022 | partial | 기존 6모듈/18쪽 + 신규 V2 13모듈/65쪽; 20/20 공식 코드 후보 태그, 본문 충족·상품 통합 검토 미완 | 공식 HWP 본표 20개 확인; 코드 태그는 연결 후보이지 내용 검수 완료가 아님 | 예제 산술/페이지 ID 검사 통과; guarded importer VM crash로 미확인; HTML parity 미검증 | 독립 교사 검수·권리 결정 대기; 출판 부적격 |
| 24 | 확률과 통계 · 2022 | partial | 기존 통계적 확률 1모듈/3쪽, 보완 1모듈/5쪽 및 V2 후보 16모듈/80쪽; 과목 전체는 미완 | 공식 본표 기준 16개 코드 모두 후보에 연결 | V2 importer 통과; 03-07 mean/proportion statisticsEstimator 후보 QA 통과, 교사·권리 승인 대기 | 통합본 미병합; 상품 전체 대조 미완 |
| 25 | 미적분Ⅱ · 2022 | partial | 기존 삼각함수 미분 2차시/6쪽 및 수열·급수 V2 5모듈/25쪽; 과목 전체 범위 필요 | 공식 본표 23개 중 01-01~05 다섯 코드 매핑 | V2 퀴즈 5개 guarded importer 통과; 과목 통합/화면 검수 미완 | 교사 검토·권리 승인 대기 |
| 26 | 기하 · 2022 | partial | 7개 BookData의 14모듈/62 원본 쪽을 3영역 부분 통합초안으로 묶었고 기준 라벨 14쪽을 추가; 앱 reader 통합과 교과서별 전체 범위 대조 미완 | 교육부 HWP 본표 14개 코드 모두 tag 후보 연결(공간도형 4, 벡터 5 신규); 태그는 내용 충족 승인 아님 | 9개 quiz payload 포함; 두 신규 V2 패키지 manifest에 importer 통과 기록; 독립 HTML parity 미검증 | 교사·수학 검토, 권리 확인, 앱 통합 전; 출판 부적격 |

현재 카탈로그 기준 집계: partial 26, missing 0, matched 0. 이는 파일의 교육적 승인 수가 아니다. `student-facing completeness`, `official curriculum match`, `math review`, `rights clearance`, `runtime compatibility`, `publish eligibility`를 별도 단계로 올려야 한다.

## 제작·배포 판단

- 26개를 이름만 만들어 완료로 세지 않는다. 원고 생성은 공식 별책 8의 판본·학기별 성취기준을 추출하고 각 항목을 다루는 새 개념 설명·예시/정답·연습/해설에 연결해 진행한다. 상업 교재의 문장·문제·그림을 복사하지 않는다.
- 초기 자료는 부분 초안 21종, 미작성 5종이었다. 현재 #8–#12에 각각 4개 후보 모듈을 추가했으나 책 전체 완성이나 전국 공통 학기 정렬을 뜻하지 않는다. 전체 26개는 모두 partial이며 학기별 근거가 있는 기준표와 전 범위 원고가 남아 있다.
- 공공 교육과정 문서는 출처 표기와 이용 조건을 각각 확인한다. 원고 문장·문제·그림은 독자 집필 여부 또는 허가/라이선스를 기록한다. 현재 각 파일의 권리 근거가 없어 공개 출판 적격으로 판정하지 않았다.
- 작업 경계: 이 저장소는 원고 원본이다. 학생 앱 변경·웹 빌드·Vercel 배포는 `Upstudy-hotfix`의 승인 브랜치에서만 진행하며 해당 저장소의 AGENTS와 `tools/verify-hotfix-worktree.ps1` 가드를 먼저 따라야 한다. 파일 복사는 현재 승인 원고를 정한 뒤 경로/해시/출처를 명시해 처리한다.
- 이번 실행은 학생 앱을 수정·빌드·배포하지 않았다. `createTextbook()` 스텁 때문에 현재 저장소에서 게시 성공을 주장할 수 없다. origin/main은 remote head 확인 결과 비어 있고, 미커밋 dirty files와 assessment 생성 프로세스는 그대로 보존한다.

## 재개 순서

1. 두 교육과정 공식 원문을 이용해 26개 상품별 기준표(기준 코드·학기·범위·출처)를 만들고 기존 86개 입력 BookData와 학생용 원고를 매핑한다. 학기 배정이 공식 문서에 없는 상품은 편집 후보와 공식 기준 상태를 분리한다.
2. `partial` 26종은 기준표의 빈칸을 오리지널 집필한다. 계산·정답은 자동 검산과 구간 검산을 남긴다.
3. 84개 HTML 자산을 상품별로 연결하고, 디자이너 세션의 선언형 인터랙션/퀴즈 계약으로 기능을 보존한다.
4. 원고별 출처·저작권/라이선스 근거와 수학·교육과정 리뷰 상태를 기록한다. 모든 자동/공식 근거 점검을 통과한 원고는 적격 후보로 분리한다.
5. hotfix 저장소 가드 안에서만 승인 원고를 전달·실제 렌더 검증한다. 공개 배포 적격 항목만 deploy하고 URL/ID/해시/모바일·데스크톱 스크린샷을 확인한다.

재현 명령: `python tool/build_tagged_textbook_drafts.py`
