# fg-sync.ps1
# Polls for changes to Fantasy Grounds db.xml and pushes character data
# to Cloudflare KV when the file is modified.
# Run this in the background during a session, or register it at login.

# --- CONFIGURATION ---
# Campaign name — change this per campaign
$CampaignName = "YOUR_CAMPAIGN_NAME"

# Base FG data directory (default location)
$FGDataDir = "$env:APPDATA\SmiteWorks\Fantasy Grounds"

# Full path to campaign folder and db.xml
$CampaignDir = Join-Path $FGDataDir "campaigns\$CampaignName"
$CampaignFile = Join-Path $CampaignDir "db.xml"

# Your Cloudflare Pages site endpoint (writes to fg-characters KV key only)
$Endpoint = "https://your-project-name.pages.dev/api/fg-characters"

# Log file
$LogFile = "$env:LOCALAPPDATA\fg-sync-$CampaignName.log"

# Backup directory for player-data
$BackupDir = Join-Path $CampaignDir "backups"

# Base site URL (derived from endpoint)
$SiteBase = $Endpoint -replace '/api/fg-characters$', ''

# Poll interval: how often to check for changes (in seconds)
$PollInterval = 30

# Backup interval: how often to back up player-data (in seconds)
$BackupInterval = 600

# --- LOGGING ---

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

# --- CHARACTER PARSING FUNCTIONS ---

function Get-XMLText {
    param([System.Xml.XmlElement]$Parent, [string]$Name)
    $node = $Parent.SelectSingleNode($Name)
    if ($node) { return $node.InnerText.Trim() }
    return ""
}

function Get-XMLNumber {
    param([System.Xml.XmlElement]$Parent, [string]$Name)
    $text = Get-XMLText $Parent $Name
    if ($text -match '^\-?\d+') { return [int]$text }
    return 0
}

function Get-CharacterName {
    param([System.Xml.XmlElement]$CharNode)
    $nameNode = $CharNode.SelectSingleNode("name")
    if (-not $nameNode) { return "Unknown" }
    $name = $nameNode.InnerText.Trim()
    $name = $name -replace '^\[.*?\]\s*', ''
    $name = $name -replace '\s*\(Copy\)\s*$', ''
    return $name
}

function Parse-Ability {
    param([System.Xml.XmlElement]$CharNode, [string]$AbilityName)
    $ab = $CharNode.SelectSingleNode("abilities/$AbilityName")
    if (-not $ab) {
        return @{ score = 10; bonus = 0; tempDamage = 0; permDamage = 0; spellburn = 0; total = 10 }
    }
    return @{
        score      = Get-XMLNumber $ab "score"
        bonus      = Get-XMLNumber $ab "bonus"
        tempDamage = Get-XMLNumber $ab "damage/temporary"
        permDamage = Get-XMLNumber $ab "damage/permanent"
        spellburn  = (Get-XMLNumber $ab "spellburn/old") + (Get-XMLNumber $ab "spellburn/new")
        total      = Get-XMLNumber $ab "total"
    }
}

function Parse-Classes {
    param([System.Xml.XmlElement]$CharNode)
    $classes = @()
    $classesNode = $CharNode.SelectSingleNode("classes")
    if ($classesNode) {
        foreach ($cl in $classesNode.ChildNodes) {
            if ($cl.NodeType -eq "Element") {
                $name = Get-XMLText $cl "name"
                $level = Get-XMLNumber $cl "level"
                if ($name -and $level -gt 0) {
                    $classes += @{ name = $name; level = $level }
                }
            }
        }
    }
    return $classes
}

function Parse-Coins {
    param([System.Xml.XmlElement]$CharNode)
    $coins = @{}
    $coinsNode = $CharNode.SelectSingleNode("coins")
    if ($coinsNode) {
        foreach ($coin in $coinsNode.ChildNodes) {
            if ($coin.NodeType -eq "Element") {
                $name = Get-XMLText $coin "name"
                $amount = Get-XMLNumber $coin "amount"
                if ($name) { $coins[$name] = $amount }
            }
        }
    }
    return $coins
}

function Parse-Equipment {
    param([System.Xml.XmlElement]$CharNode)
    $eq = @()
    $invNode = $CharNode.SelectSingleNode("inventorylist")
    if ($invNode) {
        foreach ($item in $invNode.ChildNodes) {
            if ($item.NodeType -eq "Element") {
                $isId = Get-XMLNumber $item "isidentified"
                $idNode = $item.SelectSingleNode("isidentified")
                if ($isId -eq 1 -or $null -eq $idNode) {
                    $eq += @{
                        name        = Get-XMLText $item "name"
                        count       = [Math]::Max(1, (Get-XMLNumber $item "count"))
                        carried     = Get-XMLNumber $item "carried"
                        type        = Get-XMLText $item "type"
                        subtype     = Get-XMLText $item "subtype"
                        cost        = Get-XMLText $item "cost"
                        notch1      = Get-XMLNumber $item "notch1"
                        notch2      = Get-XMLNumber $item "notch2"
                        notch3      = Get-XMLNumber $item "notch3"
                        description = Get-XMLText $item "description"
                        damage      = Get-XMLText $item "damage"
                        ac          = Get-XMLNumber $item "ac"
                        bonus       = Get-XMLNumber $item "bonus"
                    }
                }
            }
        }
    }
    return $eq
}

function Parse-Weapons {
    param([System.Xml.XmlElement]$CharNode)
    $weapons = @()
    $wpNode = $CharNode.SelectSingleNode("weaponlist")
    if ($wpNode) {
        foreach ($wp in $wpNode.ChildNodes) {
            if ($wp.NodeType -eq "Element") {
                $dmgStr = ""
                $dmgNode = $wp.SelectSingleNode("damagelist")
                if ($dmgNode -and $dmgNode.HasChildNodes) {
                    $firstDmg = $dmgNode.FirstChild
                    $dice = Get-XMLText $firstDmg "dice"
                    $bonus = Get-XMLNumber $firstDmg "bonus"
                    if ($bonus -gt 0) { $dmgStr = "$dice+$bonus" }
                    elseif ($bonus -lt 0) { $dmgStr = "$dice$bonus" }
                    else { $dmgStr = $dice }
                }
                $weapons += @{
                    name        = Get-XMLText $wp "name"
                    attackBonus = Get-XMLNumber $wp "attackbonus"
                    damage      = $dmgStr
                }
            }
        }
    }
    return $weapons
}

function Parse-Spells {
    param([System.Xml.XmlElement]$CharNode)
    $spells = @()
    $powersNode = $CharNode.SelectSingleNode("powers")
    if ($powersNode) {
        foreach ($s in $powersNode.ChildNodes) {
            if ($s.NodeType -eq "Element") {
                $group = Get-XMLText $s "group"
                if ($group -eq "Spells" -or $group -eq "") {
                    $castingTable = @()
                    $ctNode = $s.SelectSingleNode("castingtable")
                    if ($ctNode) {
                        foreach ($r in $ctNode.ChildNodes) {
                            if ($r.NodeType -eq "Element") {
                                $castingTable += @{
                                    fromRange = Get-XMLNumber $r "fromrange"
                                    toRange   = Get-XMLNumber $r "torange"
                                    result    = Get-XMLText $r "result"
                                }
                            }
                        }
                        $castingTable = @($castingTable | Sort-Object { $_.fromRange })
                    }
                    $spells += @{
                        name          = Get-XMLText $s "name"
                        level         = Get-XMLNumber $s "level"
                        prepared      = Get-XMLNumber $s "prepared"
                        range         = Get-XMLText $s "range"
                        duration      = Get-XMLText $s "duration"
                        save          = Get-XMLText $s "save"
                        castingTable  = $castingTable
                        manifestation = Get-XMLText $s "manifestation"
                        misfire       = Get-XMLText $s "misfire"
                        corruption    = Get-XMLText $s "corruption"
                    }
                }
            }
        }
        $spells = @($spells | Sort-Object { $_.level }, { $_.name })
    }
    return $spells
}

function Parse-Features {
    param([System.Xml.XmlElement]$CharNode)
    $features = @()
    $ftNode = $CharNode.SelectSingleNode("featurelist")
    if ($ftNode) {
        foreach ($ft in $ftNode.ChildNodes) {
            if ($ft.NodeType -eq "Element") {
                $features += @{
                    name = Get-XMLText $ft "name"
                    text = Get-XMLText $ft "text"
                }
            }
        }
    }
    return $features
}

function Parse-Languages {
    param([System.Xml.XmlElement]$CharNode)
    $langs = @()
    $lgNode = $CharNode.SelectSingleNode("languagelist")
    if ($lgNode) {
        foreach ($lg in $lgNode.ChildNodes) {
            if ($lg.NodeType -eq "Element") {
                $name = Get-XMLText $lg "name"
                if ($name) { $langs += $name }
            }
        }
    }
    return $langs
}

function Parse-HouseRules {
    param([System.Xml.XmlElement]$CharNode)
    $hr = $CharNode.SelectSingleNode("houserules")
    if (-not $hr) { return @{} }
    return @{
        tidalDie      = Get-XMLText $hr "class/tidaldie"
        petrification = Get-XMLNumber $hr "class/petrification"
        lucidity      = Get-XMLNumber $hr "class/lucidity"
        focusDie      = Get-XMLText $hr "class/focusdie"
        focusGem      = Get-XMLText $hr "class/focusgem"
        shapingDie    = Get-XMLText $hr "class/shapingdie"
        notes         = Get-XMLText $hr "class/notes"
        wounds        = Get-XMLText $hr "wounds/notes"
    }
}

function Parse-ActionDice {
    param([System.Xml.XmlElement]$CharNode)
    $ad = Get-XMLText $CharNode "actiondice"
    if ($ad) { return $ad }
    return "d20"
}

function Parse-Character {
    param([System.Xml.XmlElement]$CharNode, [string]$NodeId)
    return @{
        id           = "char_db_$NodeId"
        name         = Get-CharacterName $CharNode
        portrait     = $null
        familiar     = $null
        level        = Get-XMLNumber $CharNode "level"
        exp          = Get-XMLNumber $CharNode "exp"
        expNeeded    = Get-XMLNumber $CharNode "expneeded"
        occupation   = Get-XMLText $CharNode "occupation"
        birthAugur   = Get-XMLText $CharNode "birthaugur"
        appearance   = Get-XMLText $CharNode "appearance"
        notes        = Get-XMLText $CharNode "notes"
        classes      = @(Parse-Classes $CharNode)
        abilities    = @{
            strength     = Parse-Ability $CharNode "strength"
            agility      = Parse-Ability $CharNode "agility"
            stamina      = Parse-Ability $CharNode "stamina"
            personality  = Parse-Ability $CharNode "personality"
            intelligence = Parse-Ability $CharNode "intelligence"
            luck         = Parse-Ability $CharNode "luck"
        }
        hp           = @{
            total     = Get-XMLNumber $CharNode "hp/total"
            wounds    = Get-XMLNumber $CharNode "hp/wounds"
            temporary = Get-XMLNumber $CharNode "hp/temporary"
        }
        ac           = Get-XMLNumber $CharNode "defenses/ac/total"
        attackMelee  = Get-XMLNumber $CharNode "attack/melee"
        initiative   = Get-XMLNumber $CharNode "initiative/total"
        saves        = @{
            fort   = Get-XMLNumber $CharNode "saves/fortitude/total"
            reflex = Get-XMLNumber $CharNode "saves/reflex/total"
            will   = Get-XMLNumber $CharNode "saves/willpower/total"
        }
        crit         = @{
            die   = Get-XMLText $CharNode "crit/die"
            table = Get-XMLText $CharNode "crit/table"
            range = Get-XMLNumber $CharNode "crit/range"
        }
        coins        = Parse-Coins $CharNode
        equipment    = @(Parse-Equipment $CharNode)
        weapons      = @(Parse-Weapons $CharNode)
        spells       = @(Parse-Spells $CharNode)
        spellCheck   = Get-XMLNumber $CharNode "spellcheck/total"
        casterLevel  = Get-XMLNumber $CharNode "casterlevel"
        features     = @(Parse-Features $CharNode)
        languages    = @(Parse-Languages $CharNode)
        houseRules   = Parse-HouseRules $CharNode
        actionDice   = Parse-ActionDice $CharNode
    }
}

# --- UPLOAD FUNCTION ---

function Read-DBXmlSafe {
    # Reads db.xml without exclusive lock — won't conflict with FG holding the file open.
    # Retries once after 2 seconds if FG is mid-write.
    param([string]$Path, [int]$MaxRetries = 2)
    for ($i = 0; $i -lt $MaxRetries; $i++) {
        try {
            $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
            $content = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            [xml]$xml = $content
            return $xml
        }
        catch {
            if ($i -lt ($MaxRetries - 1)) {
                Write-Log "File locked by FG, retrying in 2s... (attempt $($i+1)/$MaxRetries)"
                Start-Sleep -Seconds 2
            } else {
                throw $_
            }
        }
    }
}

function Push-Characters {
    try {
        Write-Log "Parsing db.xml..."
        $db = Read-DBXmlSafe -Path $CampaignFile
        $charsheet = $db.root.charsheet

        if (-not $charsheet) {
            Write-Log "No charsheet node found in db.xml"
            return
        }

        $characters = @()
        foreach ($node in $charsheet.ChildNodes) {
            if ($node.NodeType -eq "Element" -and $node.LocalName -match '^id-\d+') {
                $name = Get-CharacterName $node
                Write-Log "  Found: $name ($($node.LocalName))"
                $characters += Parse-Character $node $node.LocalName
            }
        }

        if ($characters.Count -eq 0) {
            Write-Log "No characters found in charsheet"
            return
        }

        $payload = @{
            characters         = $characters
            inactiveCharacters = @()
        } | ConvertTo-Json -Depth 10 -Compress

        Write-Log "Uploading $($characters.Count) character(s)..."

        $response = Invoke-RestMethod -Uri $Endpoint `
            -Method Put `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) `
            -ContentType "application/json; charset=utf-8" `
            -TimeoutSec 30

        Write-Log "Upload successful: $($response.timestamp)"
    }
    catch {
        Write-Log "ERROR: $_"
    }
}

function Backup-PlayerData {
    try {
        $pdUrl = "$SiteBase/api/player-data"
        $resp = Invoke-RestMethod -Uri $pdUrl -Method Get -TimeoutSec 15 -ErrorAction Stop
        $json = $resp | ConvertTo-Json -Depth 10

        if (-not (Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        }

        # Rolling backup: keep latest + timestamped
        $latestFile = Join-Path $BackupDir "player-data-latest.json"
        Set-Content -Path $latestFile -Value $json -Encoding UTF8

        # Timestamped backup once per hour (keep history)
        $hourlyFile = Join-Path $BackupDir "player-data-$(Get-Date -Format 'yyyy-MM-dd-HH').json"
        if (-not (Test-Path $hourlyFile)) {
            Set-Content -Path $hourlyFile -Value $json -Encoding UTF8
            Write-Log "Player-data hourly backup saved"

            # Clean up backups older than 30 days
            Get-ChildItem $BackupDir -Filter "player-data-20*.json" |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
                Remove-Item -Force
        }

        Write-Log "Player-data backup updated"
    }
    catch {
        Write-Log "Backup warning: $_"
    }
}

# --- STARTUP VALIDATION ---

Write-Log "=== FG Sync Starting ==="
Write-Log "Campaign: $CampaignName"
Write-Log "Monitoring: $CampaignFile"
Write-Log "Endpoint: $Endpoint"
Write-Log "Poll interval: ${PollInterval}s"

if (-not (Test-Path $CampaignDir)) {
    Write-Log "ERROR: Campaign directory not found: $CampaignDir"
    Write-Log "Available campaigns:"
    $campaignsDir = Join-Path $FGDataDir "campaigns"
    if (Test-Path $campaignsDir) {
        Get-ChildItem $campaignsDir -Directory | ForEach-Object { Write-Log "  - $($_.Name)" }
    }
    Write-Log "Update `$CampaignName at the top of this script and try again."
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not (Test-Path $CampaignFile)) {
    Write-Log "WARNING: db.xml not found yet. Waiting for FG to create it..."
}

# --- INITIAL PUSH (if db.xml already exists) ---

if (Test-Path $CampaignFile) {
    Write-Log "Performing initial push..."
    Push-Characters
}

# --- POLL LOOP ---

$script:lastModified = [DateTime]::MinValue
$script:lastBackup = [DateTime]::MinValue

# Record current timestamp if file exists (we already pushed it above)
if (Test-Path $CampaignFile) {
    $script:lastModified = (Get-Item $CampaignFile).LastWriteTimeUtc
}

# Initial backup
Backup-PlayerData
$script:lastBackup = [DateTime]::UtcNow

Write-Log "Polling every ${PollInterval}s for db.xml changes..."
Write-Log "Backing up player-data every ${BackupInterval}s"
Write-Log "Backups saved to: $BackupDir"
Write-Log "Press Ctrl+C to stop."

try {
    while ($true) {
        Start-Sleep -Seconds $PollInterval

        try {
            if (-not (Test-Path $CampaignFile)) { continue }

            $currentModified = (Get-Item $CampaignFile).LastWriteTimeUtc
            if ($currentModified -gt $script:lastModified) {
                Write-Log "db.xml changed ($(Get-Date $currentModified -Format 'HH:mm:ss')). Syncing..."
                $script:lastModified = $currentModified

                # Brief pause to let FG finish writing
                Start-Sleep -Seconds 1

                Push-Characters
            }

            # Periodic player-data backup
            $elapsed = ([DateTime]::UtcNow - $script:lastBackup).TotalSeconds
            if ($elapsed -ge $BackupInterval) {
                Backup-PlayerData
                $script:lastBackup = [DateTime]::UtcNow
            }
        }
        catch {
            Write-Log "Poll error (will retry next cycle): $_"
        }
    }
}
finally {
    Write-Log "=== FG Sync Stopped ==="
}
