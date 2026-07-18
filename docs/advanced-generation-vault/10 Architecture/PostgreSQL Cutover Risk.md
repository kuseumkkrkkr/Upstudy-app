---
type: risk-analysis
date: 2026-07-15
decision: release-blocked
---

# PostgreSQL 전환 리스크 분석

> [!danger] 현재 판정: 배포 차단
> 로컬 `.env`에 `DATABASE_URL`, `PROBLEM_CACHE_BACKEND`, `PROBLEM_CACHE_VERIFIED`, `REDIS_URL`이 없다. 이전 실검증은 문제 payload·풀이 이력 범위의 카나리 검증이며 전체 서비스 데이터 이관 완료가 아니다.

## 이번 변경

- `user_kv`를 PostgreSQL 전용으로 변경했다.
- 인증·학원·코스 v2 연결을 PostgreSQL 풀로 변경했다.
- 레이팅은 `DATABASE_URL` 미설정 시 시작 실패한다.
- `/health/ready`는 PostgreSQL·Redis·이관 감사가 모두 정상일 때만 준비 완료다.
- 학생 문제 캐시는 PostgreSQL 장애 시 로컬 DB 읽기로 우회하지 않는다.

## 남은 차단 항목

| 위험 | 영향 | 필요한 조치 |
|---|---|---|
| 학원 데이터 이관 미검증 | 기존 학원 데이터 누락 | 전 행 이관·해시 검증 |
| 코스 v2 이관 미검증 | 기존 학습 상태 누락 | 사용자별 상태 비교 |
| 인증 이관 미검증 | 기존 계정 로그인 실패 | 사용자 수·ID·비밀번호 해시 비교 |
| 레거시 저장소 다수 | 기능별 부분 장애 | 사용 라우트 기준 PostgreSQL화 또는 제거 |
| 로컬 DB 산출물 | 저장소 비대화·데이터 혼입 | 운영 산출물과 감사 표본 분리 |
| KV 무제한 값 | DB 팽창 | 키/값 제한과 사용자 quota |

```mermaid
flowchart LR
    Schema["PostgreSQL 스키마 적용"] --> Migrate["테이블별 데이터 이관"]
    Migrate --> Verify["행 수와 해시 검증"]
    Verify --> Gate["readiness PostgreSQL only"]
    Gate --> Soak["2,000명 부하와 장애 실험"]
    Soak --> Delete["운영 SQLite 코드와 DB 제거"]
```

SQLite 파일부터 삭제하면 PostgreSQL에 없는 데이터의 복구 수단만 사라진다. 운영 fallback은 차단하되 기존 DB 파일은 이관 해시 일치 후 백업 정책에 따라 제거해야 한다.

```text
DATABASE_URL=<deployment secret>
REDIS_URL=<deployment secret>
PROBLEM_CACHE_BACKEND=postgres
PROBLEM_CACHE_VERIFIED=true
```

시크릿은 저장소 `.env`에 커밋하지 않고 배포 플랫폼에서 주입한다.
