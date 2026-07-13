param()

$ErrorActionPreference = 'Stop'
$designRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$prototypeRoot = Join-Path $designRoot 'design\prototypes'
$matrixPath = Join-Path $PSScriptRoot 'feature_matrix.json'
$scriptPath = Join-Path $prototypeRoot 'full-app.js'
$htmlPath = Join-Path $prototypeRoot 'full_face_preview.html'
$cssPath = Join-Path $prototypeRoot 'full-app.css'
$utf8 = [Text.UTF8Encoding]::new($false, $true)

<#
필요 변수: path(검사할 파일의 절대 경로), UTF-8 디코더.
작동 원리: 잘못된 바이트가 있으면 예외를 발생시켜 CP949 또는 손상된 파일이 섞이는 것을 차단한다.
#>
function Read-StrictUtf8([string]$path) {
  return $utf8.GetString([IO.File]::ReadAllBytes($path))
}

$matrixText = Read-StrictUtf8 $matrixPath
$scriptText = Read-StrictUtf8 $scriptPath
$htmlText = Read-StrictUtf8 $htmlPath
$cssText = Read-StrictUtf8 $cssPath
$matrix = $matrixText | ConvertFrom-Json
$errors = [Collections.Generic.List[string]]::new()

foreach ($screen in $matrix.screens) {
  $quotedKey = "'$($screen.id)':"
  $plainKey = "$($screen.id):"
  if (-not ($scriptText.Contains($quotedKey) -or $scriptText.Contains($plainKey))) {
    $errors.Add("화면 템플릿 또는 메타데이터 누락: $($screen.id)")
  }
  foreach ($method in $screen.methods) {
    if (-not $scriptText.Contains("'$method'")) {
      $errors.Add("서비스 메서드 매핑 누락: $($screen.id) / $method")
    }
  }
  foreach ($feature in $screen.features) {
    if (-not $scriptText.Contains("'$feature'")) {
      $errors.Add("화면 기능 매핑 누락: $($screen.id) / $feature")
    }
  }
}

if (-not $htmlText.Contains('full-app.css')) { $errors.Add('HTML의 full-app.css 연결 누락') }
if (-not $htmlText.Contains('full-app.js')) { $errors.Add('HTML의 full-app.js 연결 누락') }
if ($cssText -match 'transform\s*:\s*scale\(') { $errors.Add('컴포넌트 왜곡 위험: CSS scale 변환 사용') }
if ($matrix.screens.Count -ne 17) { $errors.Add("예상 화면 수 17개와 다름: $($matrix.screens.Count)") }

if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Output "PROTOTYPE_OK screens=$($matrix.screens.Count) methods=$((($matrix.screens.methods | Measure-Object).Count)) encoding=UTF-8 scale=none"
