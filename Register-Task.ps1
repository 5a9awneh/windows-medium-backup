<#
.SYNOPSIS
    Register (or remove) a Windows Task Scheduler task for Medium-Backup.ps1.

.DESCRIPTION
    Creates a daily scheduled task that runs Medium-Backup.ps1 automatically.
    Prompts for confirmation before creating — Y is the default (5-second countdown).
    Run with -Unregister to remove the task.

.PARAMETER Unregister
    Remove the scheduled task instead of creating it.

.EXAMPLE
    # Create the task (interactive, Y default)
    .\Register-Task.ps1

.EXAMPLE
    # Remove the task
    .\Register-Task.ps1 -Unregister

.NOTES
    Requires PowerShell 5.1+. No Administrator elevation needed for interactive logon tasks.
#>

[CmdletBinding()]
param(
    [switch]$Unregister
)

$TaskName = 'Medium Backup'
$ScriptPath = Join-Path $PSScriptRoot 'Medium-Backup.ps1'

# ── Unregister mode ───────────────────────────────────────────────────────────
if ($Unregister) {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "`n  ✅ Task '$TaskName' removed.`n" -ForegroundColor Green
    }
    else {
        Write-Host "`n  ⚠️  Task '$TaskName' not found.`n" -ForegroundColor Yellow
    }
    exit 0
}

# ── Validate script path ──────────────────────────────────────────────────────
if (-not (Test-Path $ScriptPath)) {
    Write-Host "`n  ❌ Medium-Backup.ps1 not found at: $ScriptPath" -ForegroundColor Red
    Write-Host "     Run Register-Task.ps1 from the same folder as Medium-Backup.ps1.`n" -ForegroundColor Red
    exit 1
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Medium Backup — Task Scheduler Registration" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Task name : $TaskName"
Write-Host "  Script    : $ScriptPath"
Write-Host "  Trigger   : Checks every 2 h; runs when PC has been idle 10+ min"
Write-Host "  Restarts  : Up to 3 times every 15 min on failure"
Write-Host "  User      : $env:USERDOMAIN\$env:USERNAME"
Write-Host ""

# ── Y-default prompt with 5-second countdown ─────────────────────────────────
for ($i = 5; $i -ge 1; $i--) {
    Write-Host "`r  Create scheduled task? [Y/n] (auto-yes in ${i}s)  " -NoNewline -ForegroundColor Yellow
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'N' -or $key.KeyChar -eq 'n') {
            Write-Host "`n`n  Skipped. Run Medium-Backup.ps1 manually whenever needed.`n" -ForegroundColor Gray
            exit 0
        }
        break
    }
    Start-Sleep -Seconds 1
}
Write-Host "`r  Creating task...                                    " -ForegroundColor Cyan

# ── Remove existing task if present ──────────────────────────────────────────
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "  Replacing existing task '$TaskName'..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# ── Build task components ─────────────────────────────────────────────────────
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

# Trigger: fires just after midnight, then repeats every 2 hours for 24 hours.
# Combined with RunOnlyIfIdle + StartWhenAvailable, this gives ~12 opportunistic
# windows per day — the task runs during whichever window the PC is idle.
$trigger = New-ScheduledTaskTrigger -Once -At '00:01' `
    -RepetitionInterval (New-TimeSpan -Hours 2) `
    -RepetitionDuration (New-TimeSpan -Days 1)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit  (New-TimeSpan -Hours 1) `
    -RestartCount        3 `
    -RestartInterval     (New-TimeSpan -Minutes 15) `
    -RunOnlyIfIdle `
    -IdleDuration        (New-TimeSpan -Minutes 10) `
    -IdleWaitTimeout     (New-TimeSpan -Minutes 90) `
    -MultipleInstances   IgnoreNew `
    -StartWhenAvailable

$principal = New-ScheduledTaskPrincipal `
    -UserId    "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel  Highest

# ── Register ──────────────────────────────────────────────────────────────────
Register-ScheduledTask `
    -TaskName   $TaskName `
    -Action     $action `
    -Trigger    $trigger `
    -Settings   $settings `
    -Principal  $principal `
    -Description 'Daily automated Medium post backup via ZMediumToMarkdown' | Out-Null

Write-Host ""
Write-Host "  ✅ Task '$TaskName' created successfully!" -ForegroundColor Green
Write-Host "  🌙 Runs opportunistically — checks every 2 h, executes when idle 10+ min" -ForegroundColor Cyan
Write-Host "  🗑  To remove: .\Register-Task.ps1 -Unregister" -ForegroundColor Cyan
Write-Host ""
