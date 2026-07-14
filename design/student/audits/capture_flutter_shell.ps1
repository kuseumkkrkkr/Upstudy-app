param([switch]$SkipBuild)

$ErrorActionPreference = 'Stop'

# 필요 변수: 저장소 루트, Flutter Web 출력 경로, Edge 실행 파일과 캡처 대상 크기.
# 작동 원리: API 없는 공용 셸을 빌드한 뒤 로컬 서버에서 세 viewport를 실제 브라우저 PNG로 저장한다.
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$webRoot = Join-Path $root 'build\student-density-preview'
$captureRoot = Join-Path $root 'design\student\previews\flutter-implementation'
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$port = 8976
$sizes = @(
  @{ Name = 'student-shell-390'; Width = 390; Height = 844 },
  @{ Name = 'student-shell-500'; Width = 500; Height = 1000 },
  @{ Name = 'student-shell-1280'; Width = 1280; Height = 900 }
)

if (-not (Test-Path -LiteralPath $edge -PathType Leaf)) {
  throw "Microsoft Edge not found: $edge"
}

Push-Location $root
try {
  if (-not $SkipBuild) {
    & flutter build web --target tool/student_density_preview.dart --output $webRoot
    if ($LASTEXITCODE -ne 0) { throw 'Flutter Web preview build failed.' }
  } elseif (-not (Test-Path -LiteralPath (Join-Path $webRoot 'index.html'))) {
    throw 'SkipBuild requires an existing Flutter Web preview.'
  }

  New-Item -ItemType Directory -Path $captureRoot -Force | Out-Null
  $server = Start-Process python -ArgumentList @(
    '-m', 'http.server', "$port", '--bind', '127.0.0.1', '--directory', $webRoot
  ) -WindowStyle Hidden -PassThru
  try {
    $ready = $false
    foreach ($attempt in 1..30) {
      try {
        $response = Invoke-WebRequest "http://127.0.0.1:$port" -UseBasicParsing -TimeoutSec 1
        if ($response.StatusCode -eq 200) { $ready = $true; break }
      } catch {}
      Start-Sleep -Milliseconds 200
    }
    if (-not $ready) { throw 'Flutter preview server did not start.' }

    foreach ($size in $sizes) {
      $output = Join-Path $captureRoot "$($size.Name).png"
      $profile = Join-Path $webRoot "edge-profile-$($size.Name)-$([guid]::NewGuid().ToString('N'))"
      $edgeProcess = Start-Process $edge -ArgumentList @(
        '--headless=new', '--disable-gpu', '--hide-scrollbars',
        '--run-all-compositor-stages-before-draw', '--virtual-time-budget=10000',
        "--user-data-dir=$profile",
        "--window-size=$($size.Width),$($size.Height)", "--screenshot=$output",
        "http://127.0.0.1:$port/?width=$($size.Width)&height=$($size.Height)"
      ) -WindowStyle Hidden -Wait -PassThru
      $capture = Get-Item -LiteralPath $output -ErrorAction SilentlyContinue
      if (-not $capture -or $capture.Length -eq 0) {
        throw "Capture failed: $($size.Name)"
      }
    }
  } finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
  }
} finally {
  Pop-Location
}

Write-Output "Captured Flutter shell: $($sizes.Count) viewports"
