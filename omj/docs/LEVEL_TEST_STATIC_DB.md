# 레벨테스트 정적 DB 운영 계약

레벨테스트 문제 원본은 `omj/data/level_test_static.db` 하나만 사용한다. 일반 문제은행 `quests.db`에는 세션·답안·최종 레이팅 같은 사용자 운영 데이터만 저장하며, 레벨테스트 문제와 시험지 슬롯은 저장하지 않는다.

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

- SQLite `mode=ro`와 `PRAGMA query_only=ON`을 함께 사용한다.
- 서버 시작 시 무결성·버전·JSON payload를 검증하고 메모리에 한 번 적재한다.
- 학생 요청에서는 일반 문제은행이나 문제 생성 모델로 폴백하지 않는다.
- 정적 DB가 없거나 손상되면 서버 준비 단계가 실패하며, 임의 문제를 대신 생성하지 않는다.
