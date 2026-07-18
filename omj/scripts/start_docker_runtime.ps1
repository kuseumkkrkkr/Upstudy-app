param(
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$logFile = Join-Path $env:LOCALAPPDATA 'AIFlow\docker-runtime-startup.log'
$logDirectory = Split-Path -Parent $logFile
if (-not (Test-Path -LiteralPath $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}
trap {
    $message = "[$([DateTime]::Now.ToString('s'))] 실패`r`n$($_ | Out-String)"
    [System.IO.File]::WriteAllText($logFile, $message, [System.Text.Encoding]::UTF8)
    exit 1
}
$dockerBin = 'C:\Program Files\Docker\Docker\resources\bin'
$dockerExe = Join-Path $dockerBin 'docker.exe'
$desktopExe = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
$composeFile = Join-Path $PSScriptRoot '..\docker-compose.runtime.yml'

# 필요 변수: Windows 사용자 환경 변수에 저장된 런타임 시크릿.
# 작동 원리: 예약 작업의 새 프로세스에서도 사용자 환경 변수를 명시적으로 다시 읽는다.
$runtimeVariables = @(
    'POSTGRES_PASSWORD',
    'DATABASE_URL',
    'REDIS_URL',
    'PROBLEM_CACHE_BACKEND',
    'PROBLEM_CACHE_VERIFIED',
    'RUN_EMBEDDED_BACKGROUND_WORKERS'
)
foreach ($name in $runtimeVariables) {
    $value = [Environment]::GetEnvironmentVariable($name, 'User')
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        Set-Item -Path "Env:$name" -Value $value
    }
}

if (-not (Test-Path -LiteralPath $dockerExe)) {
    throw "Docker CLI가 설치되어 있지 않습니다: $dockerExe"
}
if (-not (Test-Path -LiteralPath $desktopExe)) {
    throw "Docker Desktop이 설치되어 있지 않습니다: $desktopExe"
}
if ([string]::IsNullOrWhiteSpace($env:POSTGRES_PASSWORD)) {
    throw 'POSTGRES_PASSWORD 사용자 환경 변수가 필요합니다.'
}

$env:PATH = "$dockerBin;$env:PATH"

# 필요 변수: Docker Desktop 실행 파일과 제한 시간.
# 작동 원리: 엔진이 꺼져 있으면 숨김 실행하고 CLI가 응답할 때까지 짧게 재시도한다.
try {
    $status = & $dockerExe desktop status 2>$null | Out-String
} catch {
    $status = ''
}
if ($status -notmatch 'running') {
    Start-Process -FilePath $desktopExe -WindowStyle Hidden
}

$deadline = [DateTime]::UtcNow.AddSeconds([Math]::Max(30, $TimeoutSeconds))
do {
    try {
        $status = & $dockerExe desktop status 2>$null | Out-String
    } catch {
        $status = ''
    }
    if ($status -match 'running') {
        break
    }
    Start-Sleep -Seconds 3
} while ([DateTime]::UtcNow -lt $deadline)

if ($status -notmatch 'running') {
    throw "Docker Desktop이 ${TimeoutSeconds}초 안에 준비되지 않았습니다."
}

# 필요 변수: compose 파일과 PostgreSQL 비밀번호.
# 작동 원리: 컨테이너가 없으면 만들고, 있으면 restart 정책을 유지한 채 필요한 서비스만 복구한다.
& $dockerExe compose -f $composeFile up -d
if ($LASTEXITCODE -ne 0) {
    throw "Docker compose 기동 실패: exit=$LASTEXITCODE"
}

$deadline = [DateTime]::UtcNow.AddSeconds([Math]::Max(30, $TimeoutSeconds))
do {
    # 필요 변수: compose가 생성하는 고정 컨테이너 이름.
    # 작동 원리: PowerShell 버전에 영향받는 JSON 파싱 없이 Docker health 값을 직접 확인한다.
    $postgresHealth = & $dockerExe inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 'omj-postgres-1' 2>$null
    $postgresExitCode = $LASTEXITCODE
    $redisHealth = & $dockerExe inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 'omj-redis-1' 2>$null
    $redisExitCode = $LASTEXITCODE
    if (
        $postgresExitCode -eq 0 -and
        $redisExitCode -eq 0 -and
        ($postgresHealth | Out-String).Trim() -eq 'healthy' -and
        ($redisHealth | Out-String).Trim() -eq 'healthy'
    ) {
        [System.IO.File]::WriteAllText(
            $logFile,
            "[$([DateTime]::Now.ToString('s'))] PostgreSQL·Redis 자동 시작 성공",
            [System.Text.Encoding]::UTF8
        )
        exit 0
    }
    Start-Sleep -Seconds 3
} while ([DateTime]::UtcNow -lt $deadline)

throw "PostgreSQL 또는 Redis가 ${TimeoutSeconds}초 안에 healthy 상태가 되지 않았습니다."
