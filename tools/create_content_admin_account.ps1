# Separate admin DB only. Never calls student auth or resets existing accounts.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'verify-hotfix-worktree.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$adminOrigin = $env:ADMIN_SUPABASE_URL
$studentOrigin = $env:SUPABASE_URL
$adminKey = $env:ADMIN_SUPABASE_SERVICE_ROLE_KEY
if (-not $adminOrigin -or -not $studentOrigin -or -not $adminKey) {
    throw 'Separate ADMIN_SUPABASE_URL and ADMIN_SUPABASE_SERVICE_ROLE_KEY are required; no credentials created.'
}
$adminUri = [Uri]$adminOrigin
if ($adminUri.Scheme -ne 'https' -or $adminUri.Host -eq ([Uri]$studentOrigin).Host -or
    $adminKey -eq $env:SUPABASE_SERVICE_ROLE_KEY -or $adminUri.UserInfo -or
    $adminUri.Query -or $adminUri.Fragment -or $adminUri.AbsolutePath -ne '/') {
    throw 'Admin database must be a different HTTPS project with its own credential.'
}
$adminOrigin = $adminOrigin.TrimEnd('/')
$privateDirectory = 'D:\AIFlow-Workspace\Projects\Aiflow\Upstudy-hotfix\build\temp\private-content-admin'
$credentialPath = Join-Path $privateDirectory 'isolated-admin.credential.clixml'
New-Item -ItemType Directory -Path $privateDirectory -Force | Out-Null
$identitySid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls $privateDirectory /inheritance:r /grant:r "*${identitySid}:(OI)(CI)F" /q | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to restrict credential directory permissions' }
function Random-Hex([int]$Count) {
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $bytes = New-Object byte[] $Count; $rng.GetBytes($bytes); return [Convert]::ToHexString($bytes).ToLowerInvariant() }
    finally { $rng.Dispose() }
}
if (Test-Path -LiteralPath $credentialPath) {
    $record = Import-Clixml -LiteralPath $credentialPath
    if ($record.Origin -ne $adminOrigin) { throw 'Credential record belongs to another admin database' }
} else {
    $record = [pscustomobject]@{
        Origin=$adminOrigin; UserId=[Guid]::NewGuid().ToString(); Salt=(Random-Hex 16)
        Credential=[pscredential]::new('admin',(ConvertTo-SecureString ('A1'+(Random-Hex 24)) -AsPlainText -Force))
        State='pending'
    }
    $record | Export-Clixml -LiteralPath $credentialPath
}
$plainPassword=$record.Credential.GetNetworkCredential().Password
$derivation=[Security.Cryptography.Rfc2898DeriveBytes]::new($plainPassword,[Text.Encoding]::UTF8.GetBytes($record.Salt),600000,[Security.Cryptography.HashAlgorithmName]::SHA256)
try { $passwordHash=[Convert]::ToHexString($derivation.GetBytes(32)).ToLowerInvariant() } finally { $derivation.Dispose() }
$requestHeaders=@{apikey=$adminKey}
if ($adminKey.StartsWith('eyJ')) { $requestHeaders.Authorization="Bearer $adminKey" }
$lookupUri=$adminOrigin+'/rest/v1/content_admin_accounts?username=eq.admin&select=id,password_hash,salt&limit=1'
try {
    $existing=Invoke-RestMethod -Uri $lookupUri -Headers $requestHeaders -UserAgent 'AIFlow-Admin-Provisioner/1.0' -MaximumRedirection 0 -TimeoutSec 20
    if (-not $existing) {
        $row=@{id=$record.UserId; username='admin'; password_hash=$passwordHash; salt=$record.Salt}
        Invoke-RestMethod -Uri ($adminOrigin+'/rest/v1/content_admin_accounts') -Method Post -Headers $requestHeaders -ContentType 'application/json' -UserAgent 'AIFlow-Admin-Provisioner/1.0' `
            -Body ($row | ConvertTo-Json -Compress) -MaximumRedirection 0 -TimeoutSec 20 | Out-Null
        $existing=Invoke-RestMethod -Uri $lookupUri -Headers $requestHeaders -UserAgent 'AIFlow-Admin-Provisioner/1.0' -MaximumRedirection 0 -TimeoutSec 20
    }
    if ($existing[0].id -ne $record.UserId -or $existing[0].password_hash -cne $passwordHash -or $existing[0].salt -cne $record.Salt) {
        throw 'Existing admin does not match this creation; no reset performed'
    }
    $record.State='separate-db-account-created'
    $record | Export-Clixml -LiteralPath $credentialPath
    $desktopDirectory=[Environment]::GetFolderPath('Desktop')
    if (-not $desktopDirectory) { throw 'Desktop location unavailable; encrypted credential retained' }
    $desktopFile=Join-Path $desktopDirectory 'AIFlow 관리자 로그인.txt'
    if (Test-Path -LiteralPath $desktopFile) { throw 'Desktop login file already exists; not overwritten' }
    [IO.File]::WriteAllText($desktopFile,"AIFlow 관리자 전용 로그인`r`nID: admin`r`nPW: $plainPassword`r`n일반 학생 계정과 다른 DB입니다. API 키도 별도로 필요합니다.`r`n평문 파일이므로 공유하지 마세요.`r`n",[Text.UTF8Encoding]::new($false))
    & icacls $desktopFile /inheritance:r /grant:r "*${identitySid}:F" /q | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Desktop file ACL could not be restricted' }
    Write-Output 'separate_admin_account_created=true'
    Write-Output ('desktop_login_file='+$desktopFile)
} catch {
    Write-Output ('provision_failure_type='+$_.Exception.GetType().Name)
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
        Write-Output ('provision_http_status='+[int]$_.Exception.Response.StatusCode)
    }
    throw 'Separate admin provisioning was not completed. Credential retained locally; no existing account reset. A pending file is not a working login.'
} finally { $plainPassword=$null; $adminKey=$null; $requestHeaders=$null }
