# Flutter 학생 셸 렌더 검증

## 검증 조건

- Flutter Web 공용 셸 진입점: `tool/student_density_preview.dart`
- 실제 렌더러: Microsoft Edge headless
- 화면 크기: 390×844, 500×1000, 1280×900
- 비교 기준: `previews/density-redesign/mobile/dashboard.png`, `previews/density-redesign/desktop/dashboard.png`
- 재현 명령: `powershell -ExecutionPolicy Bypass -File design/student/audits/capture_flutter_shell.ps1`

## 결과

| 화면 | Flutter 캡처 | 확인 결과 |
| --- | --- | --- |
| 390px 모바일 | `previews/flutter-implementation/student-shell-390.png` | 햄버거, 단일 열, 20px 본문 여백, 카드 가로 오버플로 없음 |
| 500px 모바일 | `previews/flutter-implementation/student-shell-500.png` | 햄버거, 단일 열, 확대·축소 없는 반응형 재배치 확인 |
| 1280×900 PC | `previews/flutter-implementation/student-shell-1280.png` | 상단 메뉴 4개, 중앙 최대 폭, 하단 탭·상시 사이드바 없음 |

## 시안 대조

- 흑백 표면, 얇은 경계선, 둥근 카드, 대형 제목, 캡슐 행동 버튼을 동일 계층으로 유지했다.
- 모바일은 시안처럼 메뉴 항목을 숨기고 햄버거 드로어 진입만 남겼다.
- PC는 구현 계획의 “PC 상단 메뉴와 모바일 햄버거” 조건을 우선하여 햄버거를 제거했다.
- 공용 셸 캡처와 별도로 HTML 시안의 25개 화면·기능 원장·엔드포인트 원장은 `verify_prototype.ps1`로 검증한다.
