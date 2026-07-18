---
type: api-architecture
date: 2026-07-15
route-prefix: /courses/v2/runtime
status: postgresql-code-ready
---

# 학생 학습 API

```mermaid
flowchart LR
    Student["학생 Flutter 앱"] --> Contract["ApiContract 단일 base URL"]
    Contract --> Catalog["GET /courses/v2"]
    Contract --> Load["POST /courses/v2/runtime/problem-solve/load"]
    Contract --> Next["POST /courses/v2/runtime/next"]
    Contract --> State["GET /courses/v2/runtime/state/{course_id}"]
    Contract --> Submit["POST /courses/v2/runtime/submit"]
    Contract --> Textbook["textbook-view start heartbeat complete"]
    Catalog --> Course[("course_v2")]
    Load --> Runtime[("course_v2_runtime")]
    Next --> Runtime
    State --> Runtime
    Submit --> Runtime
    Textbook --> Runtime
    Load --> Pg[("PostgreSQL problem payload")]
    Load --> Redis[("Redis reservation cache")]
```

| 계열 | 용도 | 사용자 |
|---|---|---|
| `/courses/v2` | 코스 CRUD·조회·학원 그룹 연결 | 강사·관리자 중심, 학생 조회 |
| `/courses/v2/runtime` | 문제 로드·다음 단계·상태·제출·교재 열람 | 학생 중심 |
| `/courses` | 기존 코스 API | 레거시 호환 |
| `/user/storage/{key}` | 학생별 비정형 상태 | 인증 사용자 |

```mermaid
sequenceDiagram
    participant App as Student App
    participant API as Course Runtime API
    participant State as Course Runtime Store
    participant Cache as PostgreSQL and Redis
    App->>API: problem-solve/load
    API->>State: load course state
    API->>Cache: claim approved problem
    Cache-->>API: unique problem payload
    API-->>App: problem and state
    App->>API: submit
    API->>State: atomic state update
    API-->>App: result and next action
```

문제·레이팅·코스 v2 운영 연결은 PostgreSQL로 전환했다. 교재와 레거시 코스 등 보조 저장소는 별도 전환 검증이 필요하다.

