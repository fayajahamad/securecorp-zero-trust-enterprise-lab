# SecureCorp lab-only live log collectors, Windows PowerShell 5.1.
# Start once, leave this window running, and press Ctrl+C to stop.
# Reads Docker logs; writes minimal normalized JSON to separate files Alloy already tails.

$ErrorActionPreference = 'Stop'
$logsDir = 'C:\zero-trust-enterprise\monitoring\logs'
New-Item -Path $logsDir -ItemType Directory -Force | Out-Null

# Prevent two simultaneous copies of this collector creating duplicate records.
$mutex = [System.Threading.Mutex]::new($false, 'Local\SecureCorpSecurityCollector')
$locked = $mutex.WaitOne(0)
if (-not $locked) {
    $mutex.Dispose()
    throw 'The SecureCorp collector is already running in another PowerShell window.'
}

$worker = {
    param([string]$Container, [string]$LogPath)
    $ErrorActionPreference = 'Continue'
    $encoding = [System.Text.UTF8Encoding]::new($false)

    while ($true) {
        Write-Output "[$Container] Watching NEW Docker log events..."
        docker logs --follow --tail 0 $Container 2>&1 | ForEach-Object {
            $line = [string]$_
            $record = $null

            if ($Container -eq 'zt-keycloak') {
                if ($line -match 'org\.keycloak\.events' -and
                    $line -match 'type="LOGIN_ERROR"' -and
                    $line -match 'realmName="securecorp"') {
                    $record = [ordered]@{
                        timestamp  = [DateTimeOffset]::UtcNow.ToString('o')
                        event      = 'authentication'
                        event_type = 'LOGIN_ERROR'
                        source     = 'keycloak'
                        realm      = 'securecorp'
                    }
                }
            }
            elseif ($Container -eq 'zt-pomerium') {
                $entry = $null
                try { $entry = $line | ConvertFrom-Json -ErrorAction Stop }
                catch { $entry = $null }

                if ($null -ne $entry -and
                    $entry.message -eq 'authorize check' -and
                    $entry.host -eq 'hr.localhost.pomerium.io' -and
                    $entry.path -eq '/') {
                    $allowed = ($entry.allow -eq $true -and $entry.deny -ne $true)
                    $decision = if ($allowed) { 'allowed' } else { 'not_allowed' }
                    $eventTime = if ($entry.time) { [string]$entry.time } else { [DateTimeOffset]::UtcNow.ToString('o') }
                    $record = [ordered]@{
                        timestamp = $eventTime
                        event     = 'authorization'
                        source    = 'pomerium'
                        decision  = $decision
                        allow     = [bool]$entry.allow
                        deny      = [bool]$entry.deny
                        request_id = [string]$entry.'request-id'
                    }
                }
            }

            if ($null -ne $record) {
                $json = $record | ConvertTo-Json -Compress
                $stream = $null
                $writer = $null
                try {
                    $stream = [System.IO.File]::Open(
                        $LogPath,
                        [System.IO.FileMode]::Append,
                        [System.IO.FileAccess]::Write,
                        [System.IO.FileShare]::ReadWrite
                    )
                    $writer = [System.IO.StreamWriter]::new($stream, $encoding)
                    $writer.WriteLine($json)
                    $writer.Flush()
                    Write-Output "[$Container] Captured $($record.event): $($record.source)"
                }
                catch {
                    Write-Error "[$Container] Failed to append $LogPath : $_"
                }
                finally {
                    if ($null -ne $writer) { $writer.Dispose() }
                    elseif ($null -ne $stream) { $stream.Dispose() }
                }
            }
        }
        Write-Output "[$Container] Docker log stream ended. Reconnecting in 5 seconds..."
        Start-Sleep -Seconds 5
    }
}

$jobs = @()
try {
    $jobs += Start-Job -Name 'securecorp-keycloak' -ScriptBlock $worker -ArgumentList @(
        'zt-keycloak', (Join-Path $logsDir 'keycloak-auto.log')
    )
    $jobs += Start-Job -Name 'securecorp-pomerium' -ScriptBlock $worker -ArgumentList @(
        'zt-pomerium', (Join-Path $logsDir 'pomerium-auto.log')
    )

    Write-Host 'SecureCorp live collectors started. Keep this window open.' -ForegroundColor Green
    Write-Host 'New events will appear here. Press Ctrl+C to stop.' -ForegroundColor Cyan
    while ($true) {
        $jobs | Receive-Job
        Start-Sleep -Seconds 2
    }
}
finally {
    if ($jobs.Count -gt 0) {
        $jobs | Stop-Job -ErrorAction SilentlyContinue
        $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    if ($locked) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
