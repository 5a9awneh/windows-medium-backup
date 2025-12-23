# Setup Guide

Complete setup instructions for Windows Medium Backup.

## Prerequisites

### 1. Windows Version

**Required:**
- Windows 10 Pro/Enterprise/Education
- Windows 11 Pro/Enterprise/Education

**Note:** Home editions don't include Hyper-V. WSL2 support may be added in future.

### 2. Enable Hyper-V

Open PowerShell as Administrator and run:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

Restart computer when prompted.

**Verify Hyper-V is enabled:**
```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
```

Should show `State : Enabled`

### 3. Install Docker Desktop

1. Download from: https://www.docker.com/products/docker-desktop
2. Run installer
3. **IMPORTANT:** During setup, select "Use Hyper-V backend"
4. Restart if prompted

### 4. Configure Docker Desktop

1. Open Docker Desktop
2. Click Settings (gear icon)
3. **General tab:**
   - ✅ Use Hyper-V backend
   - ❌ **UNCHECK** "Use the WSL 2 based engine"
4. **Resources → File Sharing:**
   - Ensure `C:\` is in the list
   - If not, click "+" and add it
5. Click "Apply & Restart"
6. Wait 2-3 minutes for Docker to fully restart

## Get Medium Cookies

Medium requires authentication to access your posts, especially paywall content.

### Why cookies?
- Medium API not publicly available
- Cookies prove you own the account
- Allows downloading private/paywalled posts

### How to get cookies:

1. **Open Medium.com** in your browser
2. **Log in** to your account
3. Press **F12** to open Developer Tools
4. Click **Application** tab (Chrome/Edge) or **Storage** tab (Firefox)
5. Expand **Cookies** → **https://medium.com**
6. Find the `uid` row:
   - Click on it
   - Copy the **Value** (looks like: `5PL0xYaRDj4g`)
7. Find the `sid` row:
   - Click on it
   - Copy the **Value** (looks like: `1:qhM3FQ5Lfx21rWuUje9xF...`)

**Example values:**
```
uid: 5PL0xYaRDj4g
sid: 1:qzdiVAHdkhhnW0uKYT1QFSQgGrJtu1QGmcL19EAWcCutgYWeJP4rJd5dj5pR0pLq
```

**Security note:** These cookies grant access to your Medium account. Keep them private.

### Cookie lifespan

Cookies typically expire after **30-90 days**. When backup fails with authentication error, get fresh cookies and rebuild the Docker image.

## Build Docker Image

With your Medium username and cookies ready:

```powershell
.\Build-ZMediumDocker.ps1 `
  -Username "your-medium-username" `
  -CookieUID "your-uid-value" `
  -CookieSID "your-sid-value"
```

**Example:**
```powershell
.\Build-ZMediumDocker.ps1 `
  -Username "5a9awneh" `
  -CookieUID "5PL0xYaRDj4g" `
  -CookieSID "1:qzdiVAHdkhhnW0uKYT1QFSQgGrJtu1QGmcL19EAWcCutgYWeJP4rJd5dj5pR0pLq"
```

**Build time:** 5-10 minutes on first run (downloads Ruby, gems, ZMediumToMarkdown)

**What it does:**
1. Creates Dockerfile
2. Downloads Ruby base image
3. Clones ZMediumToMarkdown repository (inside Linux container, avoids Windows path issues)
4. Installs Ruby gems
5. Configures your credentials
6. Creates Docker image named `zmediumtomarkdown`

**Output on success:**
```
✅ Docker image built successfully!
✅ Image verified: zmediumtomarkdown:latest
```

## Run First Backup

```powershell
.\Medium-Backup.ps1 -Verbose
```

**What happens:**
1. Checks Docker is running (starts it if not)
2. Verifies Docker image exists
3. Creates output directory: `Documents\medium-backup\Output\`
4. Runs Docker container to download posts
5. Converts posts to Markdown with images
6. Shows toast notification when done
7. Creates log file: `Medium-Backup-YYYYMMDD.log`

**Expected output:**
```
✅ Backup completed successfully!
📁 Location: C:\Users\YourName\Documents\medium-backup\Output
📊 Files: 15 markdown files
📝 Log: Medium-Backup-20251223.log
```

**Time:** 1-5 minutes depending on number of posts and images

## Verify Output

Navigate to: `Documents\medium-backup\Output\`

**Structure:**
```
Output\
├── post-title-1\
│   └── images\
│       ├── image1.jpg
│       └── image2.png
├── post-title-2\
│   └── images\
└── ...
```

Each post's images are in own folder

**Open a .md file** in any text editor or Markdown viewer to verify content.

## OneDrive Users

Script automatically detects OneDrive paths. No special configuration needed.

**OneDrive path examples:**
```
C:\Users\YourName\OneDrive\Documents\medium-backup\
C:\Users\YourName\OneDrive - Company\Documents\medium-backup\
```

Both work automatically.

## Next Steps

- **Automation:** See [TASK-SCHEDULER.md](TASK-SCHEDULER.md) to schedule daily backups
- **Troubleshooting:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if issues occur
- **Updates:** When cookies expire, rebuild Docker image with fresh cookies

## Common Questions

**Q: Do I need to rebuild the image every time?**  
A: No, only when cookies expire or you want to update ZMediumToMarkdown.

**Q: Can I backup someone else's posts?**  
A: Yes.

**Q: What if I have 100+ posts?**  
A: Works fine, just takes longer (10-15 minutes).

**Q: Can I run this on multiple computers?**  
A: Yes, just install on each computer and use same cookies.

**Q: Is my data safe?**  
A: Everything runs locally. No data sent anywhere except to Medium (to download your own posts).
