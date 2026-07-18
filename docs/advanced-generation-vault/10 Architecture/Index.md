---
type: architecture-index
date: 2026-07-15
status: active
---

# API·데이터 아키텍처

- [[KV Storage|KV 테이블과 사용자 저장 API]]
- [[Academy API|학원 운영 API]]
- [[Student API|학생 학습 API]]
- [[PostgreSQL Cutover Risk|PostgreSQL 전환 리스크 분석]]

> [!important] 엔드포인트 경계
> 서버 주소는 `API_BASE_URL` 하나다. `/academy`와 `/courses/v2/runtime`는 서로 다른 서버가 아니라 같은 FastAPI 애플리케이션에 등록된 라우트 계열이다.

