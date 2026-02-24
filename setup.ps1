# setup.ps1
# Interactive setup wizard for FG Sync.
# Run this once to configure your campaign and site URL.
# It updates fg-sync.ps1 with your settings and optionally installs the background task.

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   Fantasy Grounds Web Sync - Setup Wizard  " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Find FG data directory ---
$DefaultFGDir = "$env:APPDATA\SmiteWorks\Fantasy Grounds"
if (-not (Test-Path $DefaultFGDir)) {
    Write-Host "Fantasy Grounds data folder not found at default location." -ForegroundColor Yellow
    Write-Host "Default: $DefaultFGDir"
    $DefaultFGDir = Read-Host "Enter your Fantasy Grounds data folder path"
}

$CampaignsDir = Join-Path $DefaultFGDir "campaigns"
if (-not (Test-Path $CampaignsDir)) {
    Write-Host "ERROR: No campaigns folder found at $CampaignsDir" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# --- Step 2: Pick a campaign ---
Write-Host "Found campaigns:" -ForegroundColor Green
$campaigns = Get-ChildItem $CampaignsDir -Directory
$i = 1
foreach ($c in $campaigns) {
    $dbExists = Test-Path (Join-Path $c.FullName "db.xml")
    $status = if ($dbExists) { "(has db.xml)" } else { "(no db.xml yet)" }
    Write-Host "  [$i] $($c.Name) $status"
    $i++
}
Write-Host ""
$selection = Read-Host "Enter the number of your campaign"
$selectedCampaign = $campaigns[$selection - 1].Name

if (-not $selectedCampaign) {
    Write-Host "Invalid selection." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Selected: $selectedCampaign" -ForegroundColor Green
Write-Host ""

# --- Step 3: Get the Cloudflare Pages URL ---
Write-Host "Enter your Cloudflare Pages site URL." -ForegroundColor Cyan
Write-Host "This is the URL where the web app is hosted."
Write-Host "Example: https://your-project-name.pages.dev"
Write-Host ""
$SiteURL = Read-Host "Site URL"
$SiteURL = $SiteURL.TrimEnd('/')

# Validate it looks like a URL
if ($SiteURL -notmatch '^https://') {
    Write-Host "WARNING: URL should start with https://" -ForegroundColor Yellow
    $SiteURL = "https://$SiteURL"
    Write-Host "Using: $SiteURL" -ForegroundColor Yellow
}

$Endpoint = "$SiteURL/api/fg-characters"
Write-Host "API endpoint: $Endpoint" -ForegroundColor Green
Write-Host ""

# --- Step 4: Update fg-sync.ps1 ---
$ScriptDir = $PSScriptRoot
$SyncScript = Join-Path $ScriptDir "scripts\fg-sync.ps1"

if (-not (Test-Path $SyncScript)) {
    # Try current directory
    $SyncScript = Join-Path $ScriptDir "fg-sync.ps1"
}

if (-not (Test-Path $SyncScript)) {
    Write-Host "ERROR: Cannot find fg-sync.ps1" -ForegroundColor Red
    Write-Host "Make sure setup.ps1 is in the project root directory."
    Read-Host "Press Enter to exit"
    exit 1
}

$content = Get-Content $SyncScript -Raw
$content = $content -replace '\$CampaignName = ".*?"', "`$CampaignName = `"$selectedCampaign`""
$content = $content -replace '\$Endpoint = ".*?"', "`$Endpoint = `"$Endpoint`""
Set-Content $SyncScript -Value $content -Encoding UTF8

Write-Host "Updated fg-sync.ps1 with your settings." -ForegroundColor Green
Write-Host ""

# --- Step 5: Test the connection ---
Write-Host "Testing connection to $SiteURL..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "$SiteURL" -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "Site is reachable!" -ForegroundColor Green
    }
} catch {
    Write-Host "WARNING: Could not reach $SiteURL" -ForegroundColor Yellow
    Write-Host "Make sure the site is deployed to Cloudflare Pages first."
}
Write-Host ""

# --- Step 6: Test the parse ---
$DbFile = Join-Path $CampaignsDir "$selectedCampaign\db.xml"
if (Test-Path $DbFile) {
    $size = [math]::Round((Get-Item $DbFile).Length / 1KB, 1)
    Write-Host "Found db.xml ($size KB)" -ForegroundColor Green
    Write-Host "Testing parse..." -ForegroundColor Cyan
    try {
        [xml]$db = Get-Content $DbFile -Encoding UTF8
        $count = 0
        foreach ($node in $db.root.charsheet.ChildNodes) {
            if ($node.LocalName -match '^id-\d+') {
                $name = $node.SelectSingleNode("name")
                if ($name) {
                    Write-Host "  Found character: $($name.InnerText)" -ForegroundColor White
                    $count++
                }
            }
        }
        Write-Host "Successfully parsed $count character(s)!" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Could not parse db.xml: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "db.xml not found yet. Open the campaign in Fantasy Grounds first." -ForegroundColor Yellow
}
Write-Host ""

# --- Step 7: Offer to install background task ---
Write-Host "Would you like to install the background sync task?" -ForegroundColor Cyan
Write-Host "This runs fg-sync.ps1 automatically when you log in to Windows."
Write-Host "It watches for changes to db.xml and pushes updates to the web app."
Write-Host ""
$install = Read-Host "Install background task? (y/n)"

if ($install -eq 'y') {
    $InstallScript = Join-Path $ScriptDir "scripts\install-fg-sync.ps1"
    if (-not (Test-Path $InstallScript)) {
        $InstallScript = Join-Path $ScriptDir "install-fg-sync.ps1"
    }

    if (Test-Path $InstallScript) {
        & $InstallScript -CampaignName $selectedCampaign -ScriptPath $SyncScript

        # Start the task immediately (don't wait for next login)
        $TaskName = "FG-Sync-$selectedCampaign"
        Write-Host ""
        Write-Host "Starting background task '$TaskName'..." -ForegroundColor Cyan

        # Verify task was registered
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $task) {
            Write-Host "WARNING: Task was not registered. Try running setup as Administrator." -ForegroundColor Yellow
        } else {
            # Stop if already running (from previous install)
            if ($task.State -eq 'Running') {
                Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }

            # Start it
            Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3

            $task = Get-ScheduledTask -TaskName $TaskName
            if ($task.State -eq 'Running') {
                Write-Host "Background task is running!" -ForegroundColor Green
            } else {
                Write-Host "Task state: $($task.State)" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "The task may need to be started manually:" -ForegroundColor Yellow
                Write-Host "  1. Open Task Scheduler (search 'Task Scheduler' in Start menu)" -ForegroundColor White
                Write-Host "  2. Find '$TaskName' in the list" -ForegroundColor White
                Write-Host "  3. Right-click it and choose 'Run'" -ForegroundColor White
            }
        }
    } else {
        Write-Host "install-fg-sync.ps1 not found. You can install it manually later." -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "To run the sync manually:" -ForegroundColor Cyan
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$SyncScript`"" -ForegroundColor White
    Write-Host ""
    Write-Host "To install the background task later:" -ForegroundColor Cyan
    Write-Host "  Run install-fg-sync.ps1 as Administrator" -ForegroundColor White
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "   Setup complete!                          " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open your campaign in Fantasy Grounds"
Write-Host "  2. Start the sync (or it starts at next login if you installed the task)"
Write-Host "  3. Open $SiteURL in your browser"
Write-Host "  4. Characters should appear within ~5 minutes (or after /save)"
Write-Host ""
Read-Host "Press Enter to exit"
