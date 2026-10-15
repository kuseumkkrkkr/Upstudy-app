# Run explicitly from the D: hotfix checkout when entering the administrator API key.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'verify-hotfix-worktree.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$secretsPath = Join-Path $PSScriptRoot '../build/temp/private-content-admin/admin-app-secrets.clixml'
$adminSecrets = Import-Clixml -LiteralPath $secretsPath
$adminApiKey = [Net.NetworkCredential]::new('', $adminSecrets.ApiKey).Password
if (-not $adminApiKey) { throw 'Local protected administrator key is missing' }
Set-Clipboard -Value $adminApiKey
Write-Output '관리자 API 키를 클립보드에 복사했습니다. 관리자 화면에 붙여넣고 사용 후 클립보드를 비워 주세요. 키 원문은 출력하지 않습니다.'
