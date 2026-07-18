# 레벨테스트 PostgreSQL 운영 계약

Placement 레벨테스트는 PostgreSQL의 `problem_payload`, `level_test_template`, `level_test_template_item`, `level_test_session`, `level_test_answer`를 사용한다. 런타임은 SQLite 파일이나 일반 `quests.db`를 조회하지 않는다.

기존 `level_test_static.db`는 PostgreSQL 이관 스크립트의 일회성 입력 형식으로만 유지한다.

## 문항 구성

- 직접 검수한 고유 문제 풀: 98개
- 고정 시험지: 5개 폼
- 폼별 문항: 중복 없는 50개
- 난이도 분포: 티어 2/3/4/5를 10/20/15/5개
- 교과 분포: 공통수학Ⅰ/공통수학Ⅱ/대수/미적분Ⅰ을 12/13/12/13개
- 보정 문제 레이팅: 1000~1675

각 문제에는 `placement_rating`이 고정되어 있다. 레벨테스트 채점은 일반 문제 난도 휴리스틱보다 이 값을 우선하며, 클라이언트가 보낸 문제 ID나 태그는 신뢰하지 않고 배정된 정적 슬롯과 대조한다.

## 빌드와 전환

프로젝트 루트에서 UTF-8 Python 환경으로 실행한다.

```powershell
python omj/scripts/seed_level_test_static_db.py
python omj/scripts/migrate_level_test_to_static_db.py
```

첫 명령은 임시 SQLite 파일을 완전히 검증한 뒤 원자 교체한다. 두 번째 명령은 `quests.db.bak_before_level-test-static-v1`을 만든 뒤 구형 `level_test_template`·`level_test_template_item`만 제거하고 세션·답안은 보존한다.

경로를 바꿀 때만 `LEVEL_TEST_STATIC_DB_PATH`를 설정한다. 미설정 시 `omj/data/level_test_static.db`를 사용한다.

## 런타임 특성

- PostgreSQL 공유 연결 풀과 트랜잭션을 사용한다.
- 학생 요청에서는 일반 문제은행이나 문제 생성 모델로 폴백하지 않는다.
- `008_level_test.sql`이 적용되지 않으면 readiness가 실패한다.
