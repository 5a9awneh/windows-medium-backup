<#
.SYNOPSIS
    Automated Medium post backup to Markdown via Docker + ZMediumToMarkdown

.DESCRIPTION
    Downloads all your Medium posts and converts to Markdown format with images.
    Designed for Windows with Docker Desktop (Hyper-V backend).

    Part of: windows-medium-backup
    GitHub: https://github.com/5a9awneh/windows-medium-backup

.EXAMPLE
    .\Medium-Backup.ps1 -Verbose

.NOTES
    Prerequisites:
    - Docker Desktop with Hyper-V backend
    - Docker image built via Build-ZMediumDocker.ps1

    Output: <script-dir>\Output\
    Logs: Medium-Backup-YYYYMMDD.log

    See TROUBLESHOOTING.md if issues occur.

.LINK
    https://github.com/5a9awneh/windows-medium-backup
#>

[CmdletBinding()]
param()

#Requires -Version 5.1

# Script configuration
$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"
$DockerImageName = "zmediumtomarkdown"

# Logging setup
$LogDate = Get-Date -Format "yyyyMMdd"
$LogFile = Join-Path $PSScriptRoot "Medium-Backup-$LogDate.log"
$DoneFile = Join-Path $PSScriptRoot "Medium-Backup-$LogDate.done"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8

    switch ($Level) {
        "ERROR" { Write-Error $Message }
        "WARNING" { Write-Warning $Message }
        default { Write-Verbose $Message }
    }
}

function Remove-OldLogs {
    param([int]$DaysToKeep = 30)

    $CutoffDate = (Get-Date).AddDays(-$DaysToKeep)
    Get-ChildItem -Path $PSScriptRoot -Filter "Medium-Backup-*.log" | 
    Where-Object { $_.LastWriteTime -lt $CutoffDate } | 
    Remove-Item -Force -ErrorAction SilentlyContinue

    # Also clean up matching .done stamps
    Get-ChildItem -Path $PSScriptRoot -Filter "Medium-Backup-*.done" |
    Where-Object { $_.LastWriteTime -lt $CutoffDate } |
    Remove-Item -Force -ErrorAction SilentlyContinue
}

function Install-BurntToast {
    try {
        if (-not (Get-Module -ListAvailable -Name BurntToast)) {
            Write-Log "Installing BurntToast module..."
            Install-Module BurntToast -Scope CurrentUser -Force -Repository PSGallery
            Write-Log "BurntToast module installed"
        }
        else {
            Write-Log "BurntToast module already installed"
        }
        Import-Module BurntToast -ErrorAction Stop
        return $true
    }
    catch {
        Write-Log "Failed to install/import BurntToast: $_" -Level WARNING
        return $false
    }
}

function Show-Notification {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet("Success", "Error", "Warning", "Info")]
        [string]$Type = "Info"
    )

    Write-Log "Notification: $Title - $Message"

    try {
        if (Get-Module -Name BurntToast -ErrorAction SilentlyContinue) {
            New-BurntToastNotification -Text $Title, $Message -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Log "Toast notification failed: $_" -Level WARNING
    }
}

function Test-DockerRunning {
    try {
        $dockerInfo = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Docker already running"
            return $true
        }
    }
    catch {}

    Write-Log "Docker not running, attempting to start..." -Level WARNING

    $DockerExe = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
    if (-not (Test-Path $DockerExe)) {
        throw "Docker Desktop not found at: $DockerExe"
    }

    Start-Process -FilePath $DockerExe
    Write-Log "Started Docker Desktop, waiting for initialization..."

    $timeout = 180
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        Start-Sleep -Seconds 10
        $elapsed += 10

        try {
            docker info 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Docker ready after $elapsed seconds"
                Start-Sleep -Seconds 10
                return $true
            }
        }
        catch {}

        Write-Log "Still waiting for Docker... ($elapsed/$timeout seconds)"
    }

    throw "Docker failed to start within $timeout seconds"
}

function Test-DockerImage {
    param([string]$ImageName)

    $images = docker images -q $ImageName 2>&1
    if ($LASTEXITCODE -eq 0 -and $images) {
        Write-Log "Docker image '$ImageName' found"
        return $true
    }

    Write-Log "Docker image '$ImageName' not found" -Level ERROR
    Write-Log "Run Build-ZMediumDocker.ps1 first to create the image" -Level ERROR
    return $false
}

function Invoke-Restructure {
    param([string]$OutputPath)

    # ZMediumToMarkdown hardcodes output to users/<username>/zmediumtomarkdown/ inside the mount
    $zmFolder = Get-ChildItem -Path $OutputPath -Filter 'zmediumtomarkdown' -Recurse -Directory -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $zmFolder) {
        Write-Log 'No zmediumtomarkdown folder found — skipping restructure' 'WARNING'
        return 0
    }

    Write-Log "Restructuring output from: $($zmFolder.FullName)"

    $mdFiles = Get-ChildItem -Path $zmFolder.FullName -Filter '*.md' -File
    $assetsRoot = Join-Path $zmFolder.FullName 'assets'
    $restructured = 0

    foreach ($md in $mdFiles) {
        $slug = $md.BaseName
        # Post ID is the last segment after the final dash (12-char Medium post hash)
        $postId = ($slug -split '-')[-1]

        $articleDir = Join-Path $OutputPath $slug
        New-Item -ItemType Directory -Path $articleDir -Force | Out-Null

        # Move .md into its own folder
        $destMd = Join-Path $articleDir $md.Name
        Move-Item -Path $md.FullName -Destination $destMd -Force

        # Move matching assets sub-folder contents to article's assets/
        $postAssets = Join-Path $assetsRoot $postId
        if (Test-Path $postAssets) {
            $articleAssets = Join-Path $articleDir 'assets'
            New-Item -ItemType Directory -Path $articleAssets -Force | Out-Null
            Get-ChildItem -Path $postAssets | Move-Item -Destination $articleAssets -Force
            Remove-Item -Path $postAssets -Force -ErrorAction SilentlyContinue
        }

        # Rewrite image refs: assets/<postId>/ -> assets/
        $content = Get-Content $destMd -Raw -Encoding UTF8
        $updated = $content -replace "assets/$postId/", 'assets/'
        if ($updated -ne $content) {
            Set-Content -Path $destMd -Value $updated -Encoding UTF8 -NoNewline
        }

        $restructured++
    }

    # Remove the now-empty users/ nesting
    $usersDir = Join-Path $OutputPath 'users'
    if (Test-Path $usersDir) {
        Remove-Item -Path $usersDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Log "Restructured $restructured articles into per-article folders"
    return $restructured
}

function Invoke-Backup {
    param([string]$OutputPath)

    Write-Log "Running Medium backup..."

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-Log "Created output directory: $OutputPath"
    }

    # Convert Windows path to Docker volume format
    $OutputPathNormalized = $OutputPath -replace '\\', '/'
    if ($OutputPathNormalized -match '^([A-Za-z]):(.+)$') {
        $drive = $matches[1].ToLower()
        $path = $matches[2]
        $dockerPath = "/$drive$path"
    }
    else {
        $dockerPath = $OutputPathNormalized
    }

    Write-Log "Output path: $OutputPath"
    Write-Log "Docker volume: $dockerPath"

    # Run Docker container
    $dockerOutput = docker run --rm `
        -v "${dockerPath}:/app/output" `
        $DockerImageName 2>&1

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Log "FATAL ERROR: Docker run failed with exit code $exitCode. Output: $dockerOutput" -Level ERROR
        throw "Docker container execution failed"
    }

    Write-Log "Backup completed successfully"
    Write-Log "Output: $dockerOutput"

    # Count generated files
    $mdFiles = Get-ChildItem -Path $OutputPath -Filter "*.md" -Recurse -ErrorAction SilentlyContinue
    $fileCount = ($mdFiles | Measure-Object).Count

    if ($fileCount -gt 0) {
        Write-Log "Generated $fileCount markdown files"
        return $fileCount
    }
    else {
        Write-Log "No markdown files found in output" -Level WARNING
        return 0
    }
}

# Main execution
try {
    Write-Log "=== Medium Backup Started ==="
    Write-Log "Version: $ScriptVersion"

    # Skip if already ran successfully today (task scheduler may trigger multiple times)
    if (Test-Path $DoneFile) {
        Write-Log "Backup already completed today — skipping"
        exit 0
    }

    # Clean old logs
    Remove-OldLogs -DaysToKeep 30

    # Install notification module
    $notificationsEnabled = Install-BurntToast

    # Check Docker
    if (-not (Test-DockerRunning)) {
        throw "Docker is not running and failed to start"
    }

    # Check Docker image
    if (-not (Test-DockerImage -ImageName $DockerImageName)) {
        throw "Docker image '$DockerImageName' not found. Run Build-ZMediumDocker.ps1 first."
    }

    # Output lands next to the script (works regardless of OneDrive sync settings)
    $OutputPath = Join-Path $PSScriptRoot 'Output'
    # To redirect output to Documents (which may sync to OneDrive), comment the line above and use:
    # $OutputPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'medium-backup\Output'
    Write-Log "Output location: $OutputPath"

    # Run backup
    $fileCount = Invoke-Backup -OutputPath $OutputPath

    # Flatten ZMediumToMarkdown nesting and group each article with its assets
    $restructured = Invoke-Restructure -OutputPath $OutputPath

    # Success
    Write-Log "=== Medium Backup Completed Successfully ==="
    New-Item -Path $DoneFile -ItemType File -Force | Out-Null  # prevent re-runs today

    if ($notificationsEnabled) {
        Show-Notification -Title "Medium Backup Complete" `
            -Message "Successfully backed up $restructured posts to $OutputPath" `
            -Type Success
    }

    Write-Host "`n✅ Backup completed successfully!" -ForegroundColor Green
    Write-Host "📁 Location: $OutputPath" -ForegroundColor Cyan
    Write-Host "📊 Articles: $restructured (each in its own folder)" -ForegroundColor Cyan
    Write-Host "📝 Log: $LogFile" -ForegroundColor Cyan

}
catch {
    Write-Log $_.Exception.Message -Level ERROR
    Write-Log $_.ScriptStackTrace -Level ERROR

    if ($notificationsEnabled) {
        Show-Notification -Title "Medium Backup Failed" `
            -Message "Backup failed. Check log: $LogFile" `
            -Type Error
    }

    Write-Host "`n❌ Backup failed!" -ForegroundColor Red
    Write-Host "📝 Check log: $LogFile" -ForegroundColor Yellow
    Write-Host "📖 See TROUBLESHOOTING.md for common issues" -ForegroundColor Yellow

    exit 1
}
