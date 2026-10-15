# Creates only the requested login; DB admin membership is a separate explicit step.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'verify-hotfix-worktree.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$apiOrigin = 'https://aiflow-web-canary.vercel.app'
$privateDirectory = 'D:\AIFlow-Workspace\Projects\Aiflow\Upstudy-hotfix\build\temp\private-content-admin'
$credentialPath = Join-Path $privateDirectory 'admin.credential.clixml'
New-Item -ItemType Directory -Path $privateDirectory -Force | Out-Null
$identitySid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls $privateDirectory /inheritance:r /grant:r "*${identitySid}:(OI)(CI)F" /q | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to restrict credential directory permissions' }

if (Test-Path -LiteralPath $credentialPath) {
    $record = Import-Clixml -LiteralPath $credentialPath
    if ($record.Origin -ne $apiOrigin -or $record.Credential.UserName -ne 'admin') {
        throw 'Unexpected credential record; do not overwrite it'
    }
} else {
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $randomBytes = New-Object byte[] 48
        $generator.GetBytes($randomBytes)
        $characters = [Convert]::ToBase64String($randomBytes) -replace '[^A-Za-z0-9]', ''
        $temporaryPassword = 'A1' + $characters.Substring(0, 18)
    } finally { $generator.Dispose() }
    $secretPassword = ConvertTo-SecureString $temporaryPassword -AsPlainText -Force
    $record = [pscustomobject]@{
        Origin = $apiOrigin
        Credential = New-Object System.Management.Automation.PSCredential('admin', $secretPassword)
        UserId = ''
        State = 'pending'
    }
    $record | Export-Clixml -LiteralPath $credentialPath
    $temporaryPassword = $null
}

function Invoke-AdminSetupRequest([string]$Path, [hashtable]$Payload) {
    try {
        Invoke-RestMethod -Uri ($apiOrigin + $Path) -Method Post -ContentType 'application/json; charset=utf-8' `
            -Body ([Text.Encoding]::UTF8.GetBytes(($Payload | ConvertTo-Json -Compress))) `
            -TimeoutSec 30 -MaximumRedirection 0
    } catch {
        # Never print request bodies, tokens, or provider error bodies.
        throw ('Admin setup request failed at ' + $Path + '; credential retained for safe retry.')
    }
}

$availability = Invoke-AdminSetupRequest '/auth/username/check' @{username='admin'}
$plainPassword = $record.Credential.GetNetworkCredential().Password
try {
    if ($availability.available) {
        $response = Invoke-AdminSetupRequest '/auth/register' @{
            username='admin'; password=$plainPassword; name='관리자'; grade='내부 테스트'; subject='수학'
        }
    } else {
        # Existing accounts are never reset or replaced. Only recover our own matching creation.
        $response = Invoke-AdminSetupRequest '/auth/login' @{username='admin'; password=$plainPassword}
    }
    if (-not $response.user_id -or -not $response.token) { throw 'Invalid authentication response' }
    $record.UserId = [string]$response.user_id
    $record.State = 'login-created-membership-not-granted'
    $record | Export-Clixml -LiteralPath $credentialPath
    Write-Output 'admin_login_verified=true'
    Write-Output ('protected_credential_file=' + $credentialPath)
    Write-Output 'admin_membership_granted=false'
} finally {
    $plainPassword = $null
    $response = $null
}
