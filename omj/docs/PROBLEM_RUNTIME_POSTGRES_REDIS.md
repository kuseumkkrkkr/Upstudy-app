# 문제 런타임 저장소 전환

문제 제공 경로는 PostgreSQL을 영속 저장소, Redis를 단기 상태와 실시간 통계로 사용한다.

## Redis 키

- `problem:payload:{quest_id}`: 문제 payload, TTL 15분
- `problem:served:{user_id}`: 사용자에게 제공·풀이된 `codebase_id:seed`, TTL 60일
- `problem:active:{quest_id}`: 최근 30분 내 문제를 제공받은 사용자 ZSET
- `problem:trending:{minute}`: 분 단위 문제 제공량 ZSET, TTL 1시간

`GET /problems/trending?minutes=15`는 최근 분 버킷을 합산해 제공량과 활성 사용자를 반환한다.

## 시작 순서

1. `docker compose -f docker-compose.runtime.yml up -d`로 PostgreSQL과 Redis를 시작한다.
2. `.env.example`을 참고해 `DATABASE_URL`, `REDIS_URL`을 서버 환경 변수로 설정한다.
3. `migrations/postgres/001_problem_runtime.sql`을 PostgreSQL에 적용한다.
4. SQLite의 기존 문제 payload와 풀이 이력을 PostgreSQL로 이관한다.

전환 중에는 기존 SQLite 기록 성공 후 PostgreSQL에도 이중 기록한다. 이관·검증이 끝난 뒤에만 `PROBLEM_CACHE_BACKEND=postgres`를 설정한다. PostgreSQL 또는 Redis 장애는 학생 문제 풀이를 막지 않으며, 기존 경로로 계속 처리한다.
