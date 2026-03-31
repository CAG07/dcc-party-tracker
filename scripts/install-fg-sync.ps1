# install-fg-sync.ps1
# Registers fg-sync.ps1 as a scheduled task (manual start).

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

# Task action runs PowerShell directly (visible console window)
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`""

# Settings: allow it to run indefinitely
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

# Register with no trigger — manual start only (via shortcut or Task Scheduler)
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Settings $settings `
    -Description "Syncs Fantasy Grounds campaign '$CampaignName' character data to Cloudflare KV. Start manually before a session." `
    -RunLevel Limited | Out-Null

$LogFile = "$env:LOCALAPPDATA\fg-sync-$CampaignName.log"

Write-Host ""
Write-Host "Task '$TaskName' registered successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Start the sync before a session:" -ForegroundColor Cyan
Write-Host "  - Open Task Scheduler and right-click the task -> Run" -ForegroundColor White
Write-Host "  - Or create a desktop shortcut (see README)" -ForegroundColor White
Write-Host ""
Write-Host "Other commands:" -ForegroundColor Cyan
Write-Host "  Stop:    Stop-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
Write-Host "  Remove:  Unregister-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
Write-Host "  Status:  Get-ScheduledTask -TaskName '$TaskName' | Select State" -ForegroundColor White
Write-Host "  Logs:    Get-Content '$LogFile' -Tail 20" -ForegroundColor White
Write-Host ""
Write-Host "See the README for how to create a desktop shortcut." -ForegroundColor Cyan
