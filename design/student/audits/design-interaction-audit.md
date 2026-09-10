# 디자인 동작 감사 도구

`design_interaction_audit.py`는 지정 HTML을 읽기 전용으로 분석한다. 기본 모드는 화면 등록·대화상자·`data-*` 속성의 기준을 확인하고, `--runtime` 모드는 로컬 HTML에서 화면별 보이는 조작 대상을 새 페이지로 초기화하며 하나씩 누른다.

## 실행

```powershell
python design/student/audits/design_interaction_audit.py `
  --source "C:\Users\user\Downloads\Upstudy-student-app-design\upstudy-student-app-design.html" `
  --expect-screens 86

python design/student/audits/design_interaction_audit.py `
  --source "C:\Users\user\Downloads\Upstudy-student-app-design\upstudy-student-app-design.html" `
  --runtime --screen home --width 390 --height 844 `
  --output "design/student/audits/evidence/2026-09-01-deployed-vs-design/runtime-home-390x844.json"

# 86개 화면의 첫 조작만 빠르게 확인할 때
python design/student/audits/design_interaction_audit.py `
  --source "C:\Users\user\Downloads\Upstudy-student-app-design\upstudy-student-app-design.html" `
  --runtime --width 390 --height 844 --wait-ms 0 --max-actions 1 `
  --output "design/student/audits/evidence/2026-09-01-deployed-vs-design/runtime-86-first-action-390x844.json"
```

`--runtime` 결과는 표준 출력과 선택한 `--output` JSON 파일로 내보내며 API·Flutter·사용자 데이터를 호출하지 않는다. 전체 검수는 `--screen`을 생략해 실행하고, 오래 걸리는 화면은 화면 ID 단위로 나눠 실행한다. `--max-actions 1`은 화면별 첫 조작만 확인하는 빠른 스모크이며 중첩 장면 전수 검사를 의미하지 않는다.

## 함수·변수표

| 클래스·함수·변수 | 목적 | 입력·반환 | 부작용·검수 기준 |
|---|---|---|---|
| `DesignInteractionAuditor` | 한 HTML 기준의 정적·브라우저 감사를 소유 | `source: Path` | 지정 파일만 읽음 |
| `DesignInteractionAuditor._read` | UTF-8 HTML을 한 번 읽어 재사용 | 없음 → `str` | 파일 읽기만 수행 |
| `DesignInteractionAuditor.inventory` | 화면 ID·대화상자 수·data 속성·해시 추출 | 없음 → `DesignInventory` | 86 화면 기준 확인에 사용 |
| `DesignInteractionAuditor.assert_expected` | 화면 등록 수가 기대값과 같은지 확인 | `expected_screens: int` → `DesignInventory` | 불일치 시 `ValueError` |
| `DesignInteractionAuditor.click_visible_controls` | 화면마다 조작 대상을 새로 열어 클릭하고 결과 수집 | viewport·화면 목록 → `tuple[ClickObservation, ...]` | 로컬 HTTP 서버와 브라우저만 사용 |
| `DesignInventory` | 정적 기준값을 불변으로 보관 | source·해시·크기·화면·대화상자·속성 | `screen_count`는 `screen_ids` 길이 |
| `ClickObservation` | 한 클릭의 라벨·URL·가시 대화상자·오류 보관 | 화면 ID·요소 index → 불변 기록 | 성공 여부를 임의로 통과 처리하지 않음 |
| `SCREEN_RE` | `defineScreen({ id: ... })` 등록 추출 | HTML 문자열 → ID 목록 | 디자인 파일의 등록 문법에 한정 |
| `DIALOG_RE` | `<dialog>`와 `role="dialog"` 템플릿 추출 | HTML 문자열 → 개수 | 동적 런타임 상태 수와 동일하지 않음 |
| `CLICK_SELECTOR` | 검수할 버튼·링크·역할·화면 이동 요소 선택 | CSS selector | 숨겨진 요소는 클릭하지 않음 |

## 해석 경계

- 정적 86개 화면과 43개 템플릿은 누락 방지용 분모다. Flutter 화면 통과를 의미하지 않는다.
- 로컬 HTML의 클릭 결과는 디자인 프로토타입의 동작 증거다. 실제 채점·저장·결제·권한 성공의 증거가 아니다.
- 동일 HTML을 두 번 검사할 때도 화면별로 새 페이지를 열어 이전 클릭 상태가 다음 항목에 섞이지 않게 한다.
- 브라우저 오류는 `ClickObservation.error`에 남긴다. 오류를 숨기거나 성공으로 바꾸지 않는다.
