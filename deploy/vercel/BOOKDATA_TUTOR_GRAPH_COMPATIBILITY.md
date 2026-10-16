# BookData 튜터와 그래프 호환성

> 이후 변경: 아래 진단은 `b22cd34` 작업본을 기록한 것이다. 최근 대화 전달은 이 파일 마지막의 ‘대화 이력 구현 체크포인트’에서 별도로 확장했다. 그래프 현재 조작값 전달과 운영 배포는 여전히 미완료다.

2026-10-17, D: `Upstudy-hotfix`의 `hotfix` 작업본 기준. **그래프는 선언형 `graph` JSON으로 실행하고, 튜터는 리더의 현재 페이지 질문 동작에서 서버 채팅으로 연결한다.** 임의 JSX 컴포넌트나 교재 HTML 스크립트를 실행하는 구조가 아니다.

## 저장과 실제 실행

| 대상 | BookData 표현과 실행 경로 | 현재 제한 |
|---|---|---|
| 본문과 질문 | `chapters[].pages[].blocks[]`의 `question`, `thinking`, `hint`, `answer` 등 | 표시용이다. 질문 블록만 저장해도 AI가 호출되는 것은 아니다. |
| 그래프 | `BookContentBlock.graph` 또는 `BookSection.graph` → `_TextbookGraphCard` → `buildJsxGraphEmbed` | 함수·선·산점도 및 유한 범위 매개변수만 지원한다. `jsx_graph`, HTML, JS 문자열 필드는 가져오기 허용 필드가 아니다. |
| 등록된 체험 | V2 `type: activity`와 검증된 `activity.kind` → `BookActivityView` | `quiz`·`steps` 등 로컬 동작은 AI 대화가 아니다. 미등록 kind는 서버가 거절한다. |
| 페이지 튜터 | `_askAboutCurrentPage` → `ServerChatPage(initialMode: socratic)` → `/serverchat/message` | 별도 BookData 챗봇 필드는 없다. 현재 페이지 문맥은 연결되지만 이전 대화와 현재 그래프 조작값은 서버에 전달하지 않는다. |

근거: `lib/shared/data/models/textbook.dart`의 `BookContentBlock`·`BookSection`, `api/textbook_import.py`의 `validate_book`·`validate_graph`, `lib/sessions/textbook/ui/pages/book_page.dart`의 `_TextbookGraphCard`·`_askAboutCurrentPage`·블록 renderer.

## 현재 허용되는 합성 예시

아래 JSON은 실제 교재 원문이 아닌 검증용 예시다. 그래프는 V1에서도 허용되며, 등록 체험을 함께 쓸 때 V2가 필요하다.

```json
{
  "schema_version": 2,
  "title": "합성 함수 관찰",
  "chapters": [{
    "title": "매개변수 비교",
    "pages": [{
      "id": "p1", "template": "experiment", "title": "폭 비교",
      "blocks": [{
        "type": "graph", "title": "p를 바꾸며 관찰",
        "graph": {
          "items": [{"id": "curve", "type": "function", "expression": "x*x/(4*p)", "colorHex": "#111113"}],
          "settings": {
            "viewport": {"left": -4, "right": 4, "top": 4, "bottom": -1},
            "parameters": [{"id": "p", "label": "p", "value": 2, "min": 1, "max": 4, "step": 0.5}]
          }
        }
      }, {
        "type": "question", "text": "p를 키웠을 때 같은 높이에서 그래프의 폭은 어떻게 바뀌나요?"
      }]
    }]
  }]
}
```

튜터 연결은 이 JSON에 키·모델·시스템 프롬프트를 넣는 대신, 학생이 리더에서 질문 동작을 선택하고 아래 형태의 인증 요청을 보내는 방식이다.

```json
{
  "user_message": "어떤 두 위치를 먼저 비교하면 좋을까요?",
  "mode": "socratic",
  "ephemeral": true,
  "include_user_data": false,
  "quest_title": "합성 함수 관찰 · 폭 비교",
  "flow": "학생이 선택한 현재 페이지의 제한된 발췌와 그래프 초기 설정"
}
```

`initialContext.answer_riddle`와 `all_formulas`는 Flutter에서 합쳐져 요청의 `flow`가 된다. 리더는 발췌를 3,700자로 제한하고 그래프 값을 ‘초기 설정 — 현재 조작값 아님’으로 표시한다. 서버 한도는 메시지250자·제목500자·flow4,000자다.

## 튜터의 실제 범위

- `/serverchat/config`·`/serverchat/message`는 `_current_user` 인증을 요구한다. 제공자 키는 Vercel 서버 환경에서만 읽는다. 현재 선택 함수는 Kiln 우선이며 Comet 대체 경로도 남아 있다. 배포 환경에서 어떤 경로가 활성인지 이 메모가 확정하지 않는다.
- 현재 페이지 질문은 책·계정·리더 세대를 검사한다. 다른 계정으로 바뀌면 이전 페이지 질문 화면을 가린다. 본문 전체나 다른 학생의 교재를 서버에서 조회하는 채팅 API는 아니다.
- 서버는 문맥을 시스템 명령이 아닌 참고 사용자 메시지로 전달하고, 소크라틱 모드에서 짧은 질문과 단계적 힌트를 지시한다. 이 문구만으로 응답 품질이나 프롬프트 주입 방어가 보장되지는 않는다.
- **연속 대화 기억은 미구현이다.** 화면 `_messages`는 로컬 목록이지만 `_request_tutor_reply`는 시스템 프롬프트·현재 문맥·현재 사용자 메시지만 전송한다. `conversationId` 인자도 현재 요청 본문에 쓰지 않는다. `history` 필드를 보내도 현재 요청 모델에서 제외되는 것을 합성 입력으로 확인했다.
- `ephemeral`·`include_user_data` 필드는 요청 모델에 있으나 현재 handler는 이를 바탕으로 대화 저장/학생 데이터 조회를 하지 않는다. 모델 제공자의 무보관 정책을 뜻하지 않는다. 학생의 보내기 동작으로 페이지 발췌가 외부 AI 제공자에 전달된다.

근거: `lib/sessions/learning_tools/ui/pages/server_chat_page.dart:140`, `lib/shared/services/api/api_client.dart`의 `sendServerChatMessage`, `api/index.py:701`, `_tutor_provider_config`, `_request_tutor_reply`, `/serverchat/message`.

## 그래프 도구와 입력 경계

- 독립 도구 `/graph`는 `JsxGraphPage`다. 교재 편집기가 아니라 별도 그래프 탐색기이며, 완성된 문서를 받는 교재 renderer와 구분한다. `POST /graphs/sample`은 선택 함수의 좌표를 계산하는 공개 숫자 API다. 인증·교재 저장 API가 아니며, 교재 내 그래프의 매 프레임 실행에 필수인 API도 아니다.
- 교재 가져오기 검사는 함수/line/scatter, 유한 좌표, 매개변수 최대16개, 예약 이름 금지, 수학 AST 등을 제한한다. 독립 샘플 API는 별도로 함수 최대6개·샘플41~401개·매개변수 최대12개를 제한하고, 허용 AST를 컴파일해 builtins 없는 Python `eval`로 계산한다. **브라우저에서 `eval`을 쓰지 않는다는 사실과 서버 구현을 혼동하면 안 된다.** 두 경로의 함수 집합·이름 길이·정규화 규칙도 같다고 가정하지 않는다.
- 브라우저 renderer는 `compileGraphMath` 수학 파서를 사용하고 저자 문자열을 이스케이프한다. 웹은 `iframe srcdoc`와 `sandbox=allow-scripts`를 사용하되 `allow-same-origin`은 없다. 양방향 메시지는 실제 부모/iframe 창을 검사한다. Native는 별도 InAppWebView이므로 웹 iframe 격리 검증을 그대로 적용했다고 볼 수 없다.
- 현재 embed가 Flutter로 보내는 상태는 viewport다. 교재 내부 slider 값은 iframe의 `parameterValues`에 남고 리더 문서나 튜터 문맥으로 돌아오지 않는다. 독립 도구의 Flutter 편집 매개변수와 혼동하지 않는다. 외부 JSXGraph 라이브러리 로딩 실패 시 Canvas 대체 경로가 있으나 오프라인·모든 플랫폼 동등 동작을 보장하지 않는다.

근거: `lib/app/router.dart:174`, `lib/sessions/graph_tools/README.md`, `api/index.py:827`, `api/index.py:1998`, `api/index.py:2027`, `jsx_graph_html_builder.dart:345`, `jsx_graph_embed_web.dart:57`, `jsx_graph_embed_native.dart`.

## 필요한 후속 계약

1. 일반 그래프만 쓰면 새 JSX 실행 스키마는 필요 없다. 기존 `graph`로 옮겨 strict importer·Dart 왕복·renderer를 함께 검사한다. `migrate_v1_to_v2`는 버전만 바꾸는 명시적 복사이며 HTML 동작이나 정답을 만들어 주지 않는다.
2. 연속 소크라틱 대화에는 사용자별 대화 식별자, 책 버전·페이지 연결, 제한된 이전 턴, 보존/만료 계약이 필요하다. 저자 JSON의 임의 프롬프트를 시스템 권한으로 올리지 않는다.
3. 현재 조작값을 질문에 넣으려면 embed→Flutter의 검증된 매개변수 이벤트, 페이지·활동 ID와 버전, 유한 값·범위, 다른 페이지/계정의 늦은 이벤트 차단을 정의한다. 그래프 초기값으로 현재값을 추정하지 않는다.
4. 페이지 내부 챗봇 버튼이 꼭 필요한 경우에만 별도 등록 V2 kind를 설계하고 Python·Dart·renderer·테스트를 함께 확장한다. 현재 임의 `tutor` 또는 `jsx_graph` 필드를 넣는 것은 호환되지 않는다.

## 검증과 배포 상태

- Python `test_graph_math_security.py` + `test_textbook_import.py`: **21 passed**.
- Flutter `bookdata_import_preservation_test.dart` + `jsx_graph_html_security_test.dart`: **5 passed**. 합성 원고의 페이지/slider 문서 왕복, 현재 페이지만 질문에 첨부, 계정 전환 차단, 이스케이프·JS 문법·산술 파서 경계를 확인한다.
- 실제 모델의 연속 대화 품질, 학생이 조작한 slider 값 전달, 실서비스 rate limit/동시성은 이 결과로 증명하지 않는다.
- 확인 시작 HEAD는 `b22cd34`이며 reader·chat UI·graph builder·web embed에 기존 미커밋 변경이 있다. 페이지 문맥 연결과 격리 개선을 포함한 현재 작업본 결과를 운영 배포 결과로 바꾸어 표현하지 않는다.
- 이번 작업은 호환성 메모만 추가한다. 원고 원문 노출·실제 AI 요청·DB 쓰기·공개 bundle 편입·Vercel 배포 및 alias 변경은 없다.

## 대화 이력 구현 체크포인트

기존 `/serverchat/message`에 선택 필드 `history`를 추가했다. 예전 클라이언트가 필드를 생략하면 기존 단일 요청과 호환된다. BookData 스키마나 게시 승인 조건은 바꾸지 않는다.

제공자 요청은 [Kiln 공식 Chat completions 문서](https://kiln.bricksum.com/docs/en/api-reference/chat-completions)의 user/assistant 텍스트 메시지 형식을 따른다. 제공자가 지원하는 tool 호출이나 저자 시스템 지시는 이 앱의 이력 계약에서 허용하지 않는다.

```json
{
  "user_message": "넓어졌습니다.", "mode": "socratic", "ephemeral": true,
  "history": [
    {"role": "user", "content": "같은 높이에서 비교하겠습니다."},
    {"role": "assistant", "content": "그때 가로 거리는 어떻게 달라졌나요?"}
  ]
}
```

| 책임 단위 | 계약과 상태 |
|---|---|
| `api/tutor_history.py` | `TutorTurn`은 user/assistant 역할과 1~2,000자 content만 허용한다. 최대8턴·총6,000자·완전한 user/assistant 쌍을 검증하며 system/tool 역할·추가 필드·순서 오류는422로 거절한다. 인증도 기존대로 필수다. |
| `_request_tutor_reply` | 정적인 서버 시스템 지시를 유지하고 현재 페이지 문맥 → 검증한 이전 턴 → 현재 질문 순으로 제공자에게 전달한다. 이력을 권한·채점 증명으로 사용하지 않는다. |
| `TutorHistory` | 한 화면의 메모리에서 성공한 대화만 쌍으로 기억한다. 오래된 쌍부터 제거하고 긴 내용을 말줄임표 포함2,000 Unicode code point로 제한한다. 인사·오류·실패 제출은 넣지 않는다. DB 쓰기는 없다. |
| Chat UI와 API adapter | 매 전송에 snapshot과 현재 세션을 연결한다. 재시도는 같은 성공 이력만 전송하며 실패 질문을 중복 적재하지 않는다. 세션 변경·dispose 시 이력을 비우고, 세대 검사로 이전 응답/재시도와 다른 계정 문맥을 차단한다. |

`history`는 클라이언트가 전하는 참고 자료이지 서버가 보증하는 대화 원장이 아니다. 영속 대화 ID·기기 간 복구·제공자의 무보관·소크라틱 응답 품질·200 동시 세션 성능을 보장하지 않는다. 현재 그래프 조작값도 아직 포함하지 않는다.

- Python 이력·기존 Kiln/채팅·BookData/public 회귀: **43 passed**, 기존 경고5.
- Flutter 이력 serializer2·새 전송3·기존 전달6·reader4: **15 passed**. 계정 전환 뒤 늦은 A 응답을 버리고 B 요청에서 A의 flow/title/history가 빠지는 것을 확인한다.
- 신규 Dart helper/테스트3파일 집중 analyze: **No issues found**.
- 첫 widget 컴파일의 nullable index/조건식 구문 오류는 명시적 getter 블록으로 고쳤다. 검사 삭제나 기대값 완화는 없다.
- 백엔드·순수 serializer와 그 테스트는 독립 체크포인트다. Chat UI/API adapter의 새 연결은 기존 미검토 dirty 세션 기반에 의존하므로 그 전체 변경을 묶어 커밋한 것으로 표시하지 않는다. `tutor_history_delivery_test.dart`도 이 작업본 통합 검사이며 clean HEAD 제품 검증이 아니다.
- 실제 제공자 호출·교재 게시·DB 쓰기는0이다. 합성 Preview는 후속 증거이며 실제 AI 또는 운영 배포로 취급하지 않는다.
