$ErrorActionPreference = 'Stop'

# 필요 변수: 시안 루트 경로와 검사할 UTF-8 텍스트 파일 목록.
# 작동 원리: BOM 유무와 관계없이 엄격한 UTF-8 디코더로 모든 파일을 읽어 깨진 인코딩을 차단한다.
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$files = Get-ChildItem -Path $root -Recurse -File | Where-Object { $_.Extension -in '.html', '.css', '.js', '.md', '.ps1' }
foreach ($file in $files) {
  $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
  [void]$utf8.GetString($bytes)
}

# 필요 변수: HTML, CSS, JavaScript 원문과 필수 화면 ID.
# 작동 원리: 전체 화면 원장, 반응형 규칙, 보존 계약, API 무호출 경계를 정적 문자열로 검증한다.
$html = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'full_face_preview.html')
$css = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'student-app.css')
$js = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'student-app.js')
$requiredScreens = @(
  'dashboard', 'courses', 'course-detail', 'course-learning',
  'solve', 'exam-paper', 'wrong-answers', 'level-test',
  'arena', 'textbooks', 'textbook-reader', 'schedule', 'groups',
  'group-detail', 'academy', 'friends', 'chat', 'marketplace', 'tools', 'graph',
  'flow', 'profile', 'settings', 'auth', 'signup'
)

foreach ($screen in $requiredScreens) {
  if ($js -notmatch [regex]::Escape($screen)) {
    throw "Missing required screen: $screen"
  }
}

if ($html -notmatch 'student-app\.js' -or $html -notmatch 'student-app\.css') { throw 'Missing HTML asset link.' }
if ($css -notmatch '@media \(max-width: 780px\)' -or $css -notmatch '\.mobile-nav') { throw 'Missing mobile layout.' }
if ($js -notmatch 'data-screen-contract' -or $js -notmatch 'ENDPOINT') { throw 'Missing feature or endpoint ledger.' }
if ($js -match '\bfetch\s*\(' -or $js -match 'XMLHttpRequest' -or $js -match 'WebSocket\s*\(') { throw 'Network call found in prototype.' }
if ($css -match 'transform:\s*scale\(') { throw 'CSS scale distortion found.' }

$screenCount = $requiredScreens.Count
$featureCount = ([regex]::Matches($js, "features:\s*\[")).Count
$endpointCount = ([regex]::Matches($js, "endpoints:\s*\[")).Count
Write-Output "Verified: $screenCount screens / $featureCount feature ledgers / $endpointCount endpoint ledgers / UTF-8 / offline only"
