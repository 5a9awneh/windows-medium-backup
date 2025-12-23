<#
.SYNOPSIS
    Build ZMediumToMarkdown Docker image with Medium credentials

.DESCRIPTION
    Creates Docker image for backing up Medium posts. Handles Windows path
    incompatibility by cloning repo inside Linux container.

    Part of: windows-medium-backup
    GitHub: https://github.com/5a9awneh/windows-medium-backup

.PARAMETER Username
    Your Medium username (without @)
    Example: "yourname" from @yourname

.PARAMETER CookieUID
    Medium uid cookie value from browser Developer Tools
    Example: "83fecdce698f"

.PARAMETER CookieSID
    Medium sid cookie value from browser Developer Tools
    Example: "1:wUmvjV39ucYk4GyI56aXp1wcpGWG6..."

.EXAMPLE
    .\Build-ZMediumDocker.ps1 -Username "yourname" -CookieUID "abc123" -CookieSID "def456xyz"

.NOTES
    Get cookies from browser:
    1. Open medium.com in browser (logged in)
    2. Press F12 → Application tab → Cookies → https://medium.com
    3. Find and copy uid value
    4. Find and copy sid value

    Rebuild image when:
    - First time setup
    - Cookies expire (backup fails with auth error)
    - Want to update ZMediumToMarkdown version

    See SETUP.md for detailed cookie instructions.

.LINK
    https://github.com/5a9awneh/windows-medium-backup
    https://github.com/ZhgChgLi/ZMediumToMarkdown
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Username,

    [Parameter(Mandatory = $true)]
    [string]$CookieUID,

    [Parameter(Mandatory = $true)]
    [string]$CookieSID
)

$ErrorActionPreference = "Stop"

Write-Host "=== Building ZMediumToMarkdown Docker Image ===" -ForegroundColor Cyan
Write-Host ""

# Validate inputs
if ([string]::IsNullOrWhiteSpace($Username)) {
    throw "Username cannot be empty"
}
if ([string]::IsNullOrWhiteSpace($CookieUID)) {
    throw "CookieUID cannot be empty"
}
if ([string]::IsNullOrWhiteSpace($CookieSID)) {
    throw "CookieSID cannot be empty"
}

# Check Docker
Write-Host "Checking Docker..." -ForegroundColor Yellow
try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker not responding"
    }
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Error "Docker is not running. Start Docker Desktop and try again."
    exit 1
}

# Create Dockerfile content
Write-Host "`nPreparing Dockerfile..." -ForegroundColor Yellow

$dockerfileContent = @"
FROM ruby:3.1-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Clone ZMediumToMarkdown repository
WORKDIR /app
RUN git clone https://github.com/ZhgChgLi/ZMediumToMarkdown.git .

# Install Ruby gems
RUN gem install bundler && bundle install

# Set Medium credentials
ENV MEDIUM_USERNAME="$Username"
ENV MEDIUM_COOKIE_UID="$CookieUID"
ENV MEDIUM_COOKIE_SID="$CookieSID"

# Create output directory
RUN mkdir -p /app/output

# Set working directory
WORKDIR /app

# Run ZMediumToMarkdown on container start
CMD ["sh", "-c", "bundle exec ruby ./ZMediumToMarkdown.rb -u `$MEDIUM_USERNAME -c `$MEDIUM_COOKIE_UID -s `$MEDIUM_COOKIE_SID -o /app/output"]
"@

$tempDockerfile = Join-Path $PSScriptRoot "Dockerfile.temp"
$dockerfileContent | Set-Content -Path $tempDockerfile -Encoding UTF8 -NoNewline

Write-Host "✅ Dockerfile created" -ForegroundColor Green

# Build Docker image
Write-Host "`nBuilding Docker image (this may take 5-10 minutes)..." -ForegroundColor Yellow
Write-Host "Steps: Download base image → Clone repo → Install gems → Configure" -ForegroundColor Cyan
Write-Host ""

try {
    $buildOutput = docker build -t zmediumtomarkdown -f $tempDockerfile $PSScriptRoot 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n❌ Docker build failed!" -ForegroundColor Red
        Write-Host $buildOutput
        throw "Docker build failed with exit code $LASTEXITCODE"
    }

    Write-Host "`n✅ Docker image built successfully!" -ForegroundColor Green

} finally {
    # Cleanup
    if (Test-Path $tempDockerfile) {
        Remove-Item $tempDockerfile -Force
    }
}

# Verify image
Write-Host "`nVerifying image..." -ForegroundColor Yellow
$images = docker images zmediumtomarkdown --format "{{.Repository}}:{{.Tag}}" 2>&1
if ($images -match "zmediumtomarkdown") {
    Write-Host "✅ Image verified: $images" -ForegroundColor Green
} else {
    Write-Warning "Image built but verification failed"
}

Write-Host "`n=== Build Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run: .\Medium-Backup.ps1 -Verbose" -ForegroundColor White
Write-Host "  2. Check: Documents\medium-backup\Output\" -ForegroundColor White
Write-Host ""
Write-Host "If backup fails with authentication error:" -ForegroundColor Yellow
Write-Host "  • Cookies expired - get fresh ones and rebuild" -ForegroundColor White
Write-Host "  • See TROUBLESHOOTING.md for help" -ForegroundColor White
Write-Host ""
