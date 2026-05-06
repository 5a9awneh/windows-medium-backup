# Troubleshooting Guide

Solutions to common issues encountered when using Windows Medium Backup.

## "WSL needs updating" Error

**Symptom:** Docker Desktop shows "WSL needs updating" warning and won't start properly.

**Cause:** Docker Desktop trying to use WSL2 backend instead of Hyper-V.

**Solution:**
1. Close Docker Desktop completely (system tray → right-click → Quit)
2. Open Docker Desktop again
3. Go to Settings → General
4. **UNCHECK** "Use the WSL 2 based engine"
5. Click "Apply & Restart"
6. Wait 2-3 minutes for Docker to fully restart
7. Try backup again

**Why this happens:** Docker Desktop defaults to WSL2 on some systems, but this project requires Hyper-V backend.

---

## "EOF" Error When Running Backup

**Symptom:**
```
error during connect: Post "http://%2F%2F.%2Fpipe%2FdockerDesktopLinuxEngine/v1.52/containers/create": EOF
```

**Cause:** Docker Desktop's Hyper-V VM not fully initialized or in bad state.

**Solution 1 - Simple restart:**
1. Right-click Docker Desktop icon in system tray
2. Click "Restart"
3. Wait 2-3 minutes
4. Run backup again

**Solution 2 - Full restart:**
```powershell
# Stop Docker
Get-Process "Docker Desktop" -ErrorAction SilentlyContinue | Stop-Process -Force

# Wait for complete shutdown
Start-Sleep -Seconds 20

# Start Docker
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait for initialization (2-3 minutes)
Start-Sleep -Seconds 180

# Try backup again
.\Medium-Backup.ps1 -Verbose
```

**Why this happens:** Hyper-V VM can enter a state where Docker daemon responds to `docker info` but can't actually run containers.

---

## Cookie or Authentication Errors

**Symptoms:**
- "Authentication failed"
- "Unauthorized"
- "Cookie expired"
- "Invalid credentials"
- Backup completes but downloads 0 posts

**Cause:** Medium cookies expired (typical lifespan: 30-90 days).

**Solution:**

1. Get fresh cookies (see [SETUP.md](SETUP.md#get-medium-cookies))
2. Rebuild Docker image:
   ```powershell
   .\Build-ZMediumDocker.ps1 `
     -Username "yourname" `
     -CookieUID "new-uid" `
     -CookieSID "new-sid"
   ```
3. Run backup again

**Prevention:** Set calendar reminder to refresh cookies every 2 months.

---

## "Volume mount" or "File sharing" Error

**Symptom:**
```
Error response from daemon: error while creating mount source path
```

**Cause:** Docker Desktop doesn't have permission to access `C:\` drive.

**Solution:**
1. Open Docker Desktop
2. Settings → Resources → File Sharing
3. Ensure `C:\` is in the list
4. If not present:
   - Click "+" button
   - Add `C:\`
5. Click "Apply & Restart"
6. Wait 2-3 minutes
7. Run backup again

---

## No Toast Notification

**Symptom:** Backup completes successfully but no popup notification appears.

**Cause:** BurntToast module not installed or installation failed.

**Check installation:**
```powershell
Get-Module -ListAvailable BurntToast
```

**If not found, install manually:**
```powershell
Install-Module BurntToast -Scope CurrentUser -Force
```

**Note:** Backup still works without notifications. Check log file for results.

---

## Backup Completes But No Output Files

**Symptom:** Script reports success but no markdown files in output folder.

**Possible causes:**

### 1. Wrong username
```powershell
# Verify your Medium username
# Visit: https://medium.com/@yourname
# Username is the part after @ (without the @)
```

### 2. No published posts
- Check if your Medium account has published posts
- Private drafts are not backed up

### 3. Cookies issue
- See "Cookie or Authentication Errors" above

### 4. Output path issue
Verify output path (Output\ is created next to Medium-Backup.ps1):
```powershell
# Output is saved next to the script:
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path
$OutputPath = Join-Path $ScriptDir 'Output'
Write-Host $OutputPath
# Navigate to this path in File Explorer
```

---

## "Docker image not found" Error

**Symptom:**
```
Docker image 'zmediumtomarkdown' not found
Run Build-ZMediumDocker.ps1 first to create the image
```

**Cause:** Haven't built Docker image yet, or image was deleted.

**Solution:**

1. Verify image doesn't exist:
   ```powershell
   docker images zmediumtomarkdown
   ```

2. Build image:
   ```powershell
   .\Build-ZMediumDocker.ps1 -Username "..." -CookieUID "..." -CookieSID "..."
   ```

---

## Slow Backup Performance

**Normal timing:**
- 1-5 posts: 1-2 minutes
- 10-20 posts: 3-5 minutes
- 50+ posts: 10-15 minutes
- 100+ posts: 15-30 minutes

**Factors affecting speed:**
- Number of images (images take time to download)
- Image sizes
- Internet connection speed
- Medium server response time

**Not a bug** - just be patient. Check log file to see progress.

---

## Docker Desktop Won't Start

**Symptom:** Docker Desktop fails to start or crashes immediately.

**Solutions to try:**

### 1. Check Hyper-V is enabled
```powershell
# Run as Administrator
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
```
Should show `State : Enabled`

### 2. Check Windows version
- Requires Windows 10/11 Pro, Enterprise, or Education
- Home editions: Hyper-V not available

### 3. Restart Hyper-V service
```powershell
# Run as Administrator
Restart-Service vmms
```

### 4. Reinstall Docker Desktop
1. Uninstall Docker Desktop
2. Restart computer
3. Download latest version
4. Install with "Use Hyper-V backend" option

---

## Task Scheduler Issues

**See [TASK-SCHEDULER.md](TASK-SCHEDULER.md#troubleshooting)** for automation-specific issues.

---

## Check Log Files

**Location:** Same folder as `Medium-Backup.ps1`

**Format:** `Medium-Backup-YYYYMMDD.log`

**Example:**
```
[2025-12-23 17:34:21] [INFO] === Medium Backup Started ===
[2025-12-23 17:34:21] [INFO] Docker already running
[2025-12-23 17:36:25] [INFO] Backup completed successfully
[2025-12-23 17:36:25] [INFO] Generated 15 markdown files
```

**Log retention:** Automatically deletes logs older than 30 days.

---

## Getting Additional Help

If issue persists:

1. **Check log file** for detailed error messages
2. **Check Docker Desktop** for errors or warnings
3. **Open GitHub issue** with:
   - Error message (remove personal info/cookies)
   - Relevant log entries
   - Windows version
   - Docker Desktop version
   - PowerShell version: `$PSVersionTable.PSVersion`

**Before opening issue:**
- Ensure Docker Desktop is running
- Verify Hyper-V is enabled
- Check you're using correct cookies (not expired)
- Try rebuilding Docker image

---

## Quick Diagnostic Commands

```powershell
# Check Windows version
[System.Environment]::OSVersion.Version

# Check PowerShell version
$PSVersionTable.PSVersion

# Check Hyper-V status
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V

# Check Docker status
docker info

# Check Docker images
docker images

# Check output path (next to Medium-Backup.ps1)
Join-Path (Split-Path $MyInvocation.MyCommand.Path) 'Output'

# Test Docker with simple container
docker run --rm alpine:latest echo "Docker works"
```

Save output when requesting help.
