# install-fg-sync.ps1
# Registers fg-sync.ps1 as a background task that starts at user login.
# The watcher runs silently and pushes to KV whenever db.xml changes.
# Run this script once as Administrator.

param(
    [string]$CampaignName = "YOUR_CAMPAIGN_NAME",
    [string]$ScriptPath = ""
)

# Auto-detect script path if not specified
if (-not $ScriptPath) {
    $ScriptPath = Join-Path $PSScriptRoot "fg-sync.ps1"
}

if (-not (Test-Path $ScriptPath)) {
    Write-Host "ERROR: fg-sync.ps1 not found at: $ScriptPath" -ForegroundColor Red
    Write-Host "Place this script in the same folder as fg-sync.ps1, or pass -ScriptPath" -ForegroundColor Yellow
    exit 1
}

$TaskName = "FG-Sync-$CampaignName"

Write-Host "=== Fantasy Grounds Sync Installer ===" -ForegroundColor Cyan
Write-Host "Campaign:    $CampaignName"
Write-Host "Script:      $ScriptPath"
Write-Host "Task Name:   $TaskName"
Write-Host ""

# Check for existing task
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Task '$TaskName' already exists." -ForegroundColor Yellow
    $choice = Read-Host "Replace it? (y/n)"
    if ($choice -ne 'y') {
        Write-Host "Cancelled."
        exit 0
    }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed existing task." -ForegroundColor Green
}

# Create the scheduled task
# -WindowStyle Hidden keeps it from popping up a console window
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

# Trigger at user login
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

# Settings: allow it to run indefinitely, don't stop after 3 days
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Watches Fantasy Grounds campaign '$CampaignName' db.xml and syncs character data to Cloudflare KV." `
    -RunLevel Limited | Out-Null

Write-Host ""
Write-Host "Task '$TaskName' registered successfully." -ForegroundColor Green
Write-Host ""
Write-Host "The watcher will start automatically at next login." -ForegroundColor Cyan
Write-Host "To start it now without relogging:" -ForegroundColor Cyan
Write-Host "  Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
Write-Host ""
Write-Host "Other commands:" -ForegroundColor Cyan
Write-Host "  Stop:    Stop-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
Write-Host "  Remove:  Unregister-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
Write-Host "  Status:  Get-ScheduledTask -TaskName '$TaskName' | Select State" -ForegroundColor White
Write-Host "  Logs:    Get-Content `"$env:LOCALAPPDATA\fg-sync-$CampaignName.log`" -Tail 20" -ForegroundColor White
