# Task Scheduler Automation

Set up automated daily backups of your Medium posts using Windows Task Scheduler.

## Overview

Task Scheduler runs the backup script automatically at scheduled times, even when you're not at the computer.

**Benefits:**
- Never forget to backup
- Always have recent copies
- Runs silently in background
- Toast notification on completion

## Setup

Run `Register-Task.ps1` — it creates the task automatically with recommended settings:

```powershell
.\Register-Task.ps1
```

You'll see a summary of what will be created and a 5-second confirmation prompt (Y is the default). The task runs daily at 9:00 AM when the PC has been idle for 10 minutes.

**To remove the task:**
```powershell
.\Register-Task.ps1 -Unregister
```

## Test the Task

### Manual Test

1. Find your task in Task Scheduler Library
2. Right-click → **"Run"**
3. Watch for toast notification
4. Check output folder: `Output\` (next to `Medium-Backup.ps1`)
5. Check log file: `Medium-Backup-YYYYMMDD.log`

### Verify Scheduled Execution

1. Select your task
2. Bottom panel → **History** tab (enable if disabled)
3. After scheduled time, check for:
   - "Task started"
   - "Task completed"
4. Check timestamps match your schedule

## Monitor Task Execution

### Check Last Run

In Task Scheduler, select your task. Main panel shows:
- **Last Run Time:** When it last executed
- **Last Run Result:** 0x0 = success, other = error
- **Next Run Time:** When it will run next

### Check Logs

**Script logs:** `Medium-Backup-YYYYMMDD.log` (same folder as script)

**Task Scheduler logs:**
1. Task Scheduler → Your task
2. History tab
3. Look for event ID 102 (task completed)

### Toast Notifications

When backup completes, you'll see a toast notification in bottom-right:
- **Success:** "Medium Backup Complete - Successfully backed up X posts"
- **Failure:** "Medium Backup Failed - Check log file"

Notifications stay in Action Center (Win + A).

## Troubleshooting

### Task Shows "Running" But Nothing Happens

**Check:**
1. Docker Desktop is installed and running
2. Script path in task is correct
3. PowerShell execution policy allows scripts

**Fix:**
```powershell
# Verify script runs manually
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\Medium-Backup.ps1"
```

If manual works but scheduled doesn't, check "Run with highest privileges" in task properties.

### Task Fails Immediately

**Check:**
1. Task "Last Run Result" code
2. Script log file for errors
3. Docker Desktop is running

**Common causes:**
- Docker not running → Start Docker Desktop or add startup to task
- Cookies expired → Rebuild Docker image
- Path typo in task arguments

### Task Runs But Backup Fails

Check script log: `Medium-Backup-YYYYMMDD.log`

**Common issues:**
- Docker not started yet → Add delay or Docker startup (see below)
- Cookies expired → Rebuild image
- Network disconnected → Wait for reconnection

### Docker Not Running When Task Starts

**Solution:** Add Docker startup to task

**Modified arguments:**
```powershell
-WindowStyle Hidden -ExecutionPolicy Bypass -Command "& { Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe' -WindowStyle Hidden; Start-Sleep -Seconds 120; & 'C:\full\path\to\Medium-Backup.ps1' }"
```

This starts Docker, waits 2 minutes, then runs backup.

**Note:** `Medium-Backup.ps1` already tries to start Docker, but this ensures it's running.

### Multiple Failed Attempts in History

**If cookies expired:**
- Task will fail every run until you rebuild Docker image with fresh cookies
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#cookie-or-authentication-errors)

## Scheduling Options

### Daily at Specific Time
- **Trigger:** Daily, 9:00 AM
- **Use case:** Backup every morning before work

### Multiple Times Per Day
- **Trigger:** Daily, 9:00 AM
- **Repeat:** Every 6 hours for 18 hours
- **Result:** Runs at 9 AM, 3 PM, 9 PM
- **Use case:** Frequent backup for active writers

### Weekly (Less Frequent)
- **Trigger:** Weekly, Sunday, 9:00 AM
- **Use case:** Infrequent updates to Medium

### On Idle (Smart Backup)
- **Trigger:** Daily
- **Conditions:** Start only if idle for 10 minutes
- **Result:** Runs when PC is idle, doesn't interrupt work
- **Use case:** Best option for most users

## Disable or Pause

### Temporarily Disable
1. Task Scheduler → Find task
2. Right-click → **"Disable"**
3. Re-enable when ready

### Permanently Remove

The quick way:
```powershell
.\Register-Task.ps1 -Unregister
```

Or manually in Task Scheduler:
1. Task Scheduler → Find task
2. Right-click → **"Delete"**

## Tips

- **Realistic schedule:** Daily is good, hourly is overkill for most users
- **Check logs occasionally:** Catch expired cookies early
- **Idle conditions recommended:** Prevents interrupting your work
- **Keep Docker Desktop set to start with Windows** (Settings → General)

## Advanced: Multiple Backups

To backup multiple Medium accounts:

1. Build separate Docker images with different names:
   ```powershell
   docker build -t zmedium-account1 ...
   docker build -t zmedium-account2 ...
   ```
2. Modify script to accept image name as parameter
3. Create separate scheduled tasks for each account

## Log Cleanup

Script automatically removes logs older than 30 days. No manual cleanup needed.

**Manual cleanup:**
```powershell
# Remove all logs older than 30 days
Get-ChildItem -Path "C:\path\to\scripts" -Filter "Medium-Backup-*.log" |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
  Remove-Item -Force
```

## Success Indicators

Your automation is working if:
- Task "Last Run Time" updates daily
- Toast notifications appear
- Output folder has recent posts
- Log files show successful completions
- "Next Run Time" is set correctly

## Getting Help

If issues persist:
1. Check script log file first
2. Check Task Scheduler History
3. Test manual execution
4. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
5. Open GitHub issue with task settings and log output
