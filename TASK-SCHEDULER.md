# Task Scheduler Automation

## Setup

```powershell
.\Register-Task.ps1
```

Prompts for confirmation (Y default, 5-second countdown). Creates a task that checks every 2 hours and runs whenever the PC has been idle for 10+ minutes — won't interrupt your work. Once it runs successfully, it won't run again that day.

**To remove:**
```powershell
.\Register-Task.ps1 -Unregister
```

## How It Behaves

- Checks for an idle window every 2 hours throughout the day
- Skips if the PC is in use — waits for the next 2-hour slot
- After a successful backup, skips all remaining slots for that day
- Sends a toast notification on completion or failure
- Logs to `Medium-Backup-YYYYMMDD.log` (30-day rotation)

## Verify It's Working

In Task Scheduler (`taskschd.msc`) → find **Medium Backup**:
- **Last Run Time** — when it last executed
- **Last Run Result** — `0x0` = success
- **History tab** — full run log (enable if blank: Action → Enable All Tasks History)

Or just check the log file and `Output\` folder for today's date.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Task never runs | PC always busy when triggered | Run manually: right-click → Run |
| `0x1` result code | Script error | Check `Medium-Backup-YYYYMMDD.log` |
| Docker error in log | Docker not started | Launch Docker Desktop; script auto-starts it |
| Auth error in log | Cookies expired | Rebuild image via `Build-ZMediumDocker.ps1` |

For deeper issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Disable / Remove

```powershell
# Remove permanently
.\Register-Task.ps1 -Unregister

# Or disable temporarily: Task Scheduler → right-click task → Disable
```
