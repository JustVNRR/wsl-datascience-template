# ==============================================================================
# WHICH INSTANCES ARE OURS, AND WHAT WINDOWS KNOWS ABOUT THEM
# ==============================================================================
# The machine holds distributions that are not ours - Docker Desktop's own, or
# the ones a colleague keeps for other projects - and they sit side by side
# with ours in the same folders. The registry says what Windows knows; it does
# not say what this repository built.
#
# So every instance we create carries a marker, in its own folder, next to
# ext4.vhdx:
#
#   <install folder>\.wsl-datascience-template
#
# It is written by the three commands that create an instance - build, restore,
# duplicate - and looked for by every command that lists instances. There is no
# list to keep up to date: the mark travels with the instance, wherever it
# lives, and an instance that loses it simply leaves our lists. adopt.ps1 is
# how an instance built before this existed gets one.
#
# --------------------------------------------------------------------------
# Two more things live on the Windows side of an instance, and both are lost
# the same way - silently:
#
#   the look     an icon, a font and a colour scheme, written by build.ps1 into
#                a Windows Terminal fragment that targets the guid of that
#                instance's WSL profile. A re-import gives it a NEW guid, so
#                the fragment stops matching and the instance comes back bare.
#   Docker       whether Docker Desktop knows the instance, which it records in
#                its own settings file, by NAME.
#
# Neither is inside the tar: they are Windows settings, not Linux ones. So they
# are captured when an archive is taken, next to it:
#
#   archives\<name>\instance.json       the font, the colours, Docker's answer
#   archives\<name>\terminal-icon.png   the icon, copied from the instance
#
# and re-applied after an import.
#
# This file defines functions; it is not a command. Every command of the family
# loads it at the top - a missing instance.ps1 means the scripts\ folder is
# incomplete, and the commands say so rather than run half blind.
# ==============================================================================

# The marker's name, kept here so that one file knows it and the others ask.
# It is the repository's own name, like the Windows Terminal fragments folder,
# so there is one string to remember in the whole project.
$MarkerName = ".wsl-datascience-template"

# Is this folder an instance of ours? A folder name proves nothing - it is the
# marker file, and only it, that answers.
function Test-TemplateInstance {
    param([string]$Folder)

    if (-not $Folder) { return $false }
    return (Test-Path (Join-Path $Folder $MarkerName))
}

# Mark an instance as ours. Called right after an import, while the folder is
# fresh - the point is that the mark is there before anything else can go
# wrong, so the other commands see the instance even if a later step fails.
function New-InstanceMarker {
    param([string]$Folder, [string]$By)

    if (-not (Test-Path $Folder)) { return }

    # [ordered]: a hashtable would print its keys in a different order on every
    # run, and a file whose lines move is a file nobody diffs twice.
    $Marker = [ordered]@{
        template = "wsl-datascience-template"
        created  = (Get-Date).ToString("yyyy-MM-dd")
        by       = $By
    }

    $Json = ($Marker | ConvertTo-Json) -replace "`r`n", "`n"
    # Written byte-order-mark-free, like Docker Desktop's settings file:
    # PowerShell's -Encoding Utf8 prepends one that the next reader is not
    # expecting.
    [System.IO.File]::WriteAllText((Join-Path $Folder $MarkerName), $Json,
        (New-Object System.Text.UTF8Encoding($false)))
}

# Is a font face installed for this user or for the machine? Windows stores
# them as registry values whose names carry the face ("MesloLGS NF (TrueType)").
function Test-FontInstalled {
    param([string]$Face)

    if (-not $Face) { return $true }
    foreach ($Root in @("HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
                        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")) {
        $Key = Get-ItemProperty -Path $Root -ErrorAction SilentlyContinue
        if (-not $Key) { continue }
        foreach ($Property in $Key.psobject.properties) {
            if ($Property.Name -like "*$Face*") { return $true }
        }
    }
    return $false
}

# What an instance looks like right now: the fragment this repository wrote
# when it built the instance, what Windows Terminal's own settings say the user
# changed since, or the template's defaults - in that order. A settings file
# Windows Terminal owns may carry // comments, which ConvertFrom-Json refuses:
# that is what the try/catch is for.
function Get-InstanceAppearance {
    param([string]$Name)

    $Appearance = [PSCustomObject]@{
        Name        = $Name
        Font        = "MesloLGS NF"
        ColorScheme = "One Half Dark"
        IconFrom    = $null
    }

    $OurFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-datascience-template\$Name.json"
    if (Test-Path $OurFragment) {
        try {
            $Parsed = (Get-Content $OurFragment -Raw | ConvertFrom-Json).profiles[0]
            if ($Parsed.font.face) { $Appearance.Font = $Parsed.font.face }
            if ($Parsed.colorScheme) { $Appearance.ColorScheme = $Parsed.colorScheme }
        } catch { }
    }

    foreach ($SettingsPath in @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )) {
        if (-not (Test-Path $SettingsPath)) { continue }
        try {
            foreach ($Profile in (Get-Content $SettingsPath -Raw | ConvertFrom-Json).profiles.list) {
                if ($Profile.name -eq $Name -and $Profile.source -eq "Microsoft.WSL") {
                    if ($Profile.font.face) { $Appearance.Font = $Profile.font.face }
                    if ($Profile.colorScheme) { $Appearance.ColorScheme = $Profile.colorScheme }
                }
            }
        } catch { }
    }

    # The icon lives next to the disk, where build.ps1 put it
    $Registry = Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ItemProperty $_.PSPath } |
        Where-Object { $_.DistributionName -eq $Name }
    if ($Registry) {
        $Folder = ($Registry.BasePath -replace '^\\\\\?\\', '').TrimEnd('\')
        $Icon = Join-Path $Folder "terminal-icon.png"
        if (Test-Path $Icon) { $Appearance.IconFrom = $Icon }
    }

    return $Appearance
}

# Write what Windows knows about an instance next to an archive, so it travels
# with it
function Save-InstanceState {
    param([string]$Name, [string]$Folder)

    $Appearance = Get-InstanceAppearance -Name $Name
    $Docker = Get-DockerState -Name $Name
    $Appearance | Add-Member -NotePropertyName Docker -NotePropertyValue $Docker

    if (-not (Test-Path $Folder)) { New-Item -ItemType Directory -Path $Folder -Force | Out-Null }
    $Appearance | ConvertTo-Json | Set-Content -Path (Join-Path $Folder "instance.json") -Encoding Utf8

    if ($Appearance.IconFrom) {
        Copy-Item -Path $Appearance.IconFrom -Destination (Join-Path $Folder "terminal-icon.png") -Force
    }

    Write-Host "  * Look             : font '$($Appearance.Font)', colours '$($Appearance.ColorScheme)'$(if ($Appearance.IconFrom) { ", icon copied" })" -ForegroundColor DarkGray
    Write-Host "  * Docker Desktop   : $(if ($Docker -eq "yes") { "knows this instance" } elseif ($Docker -eq "no") { "does not know it" } else { "not installed, or unreadable" })" -ForegroundColor DarkGray
    if (-not (Test-FontInstalled $Appearance.Font)) {
        Write-Host "                       '$($Appearance.Font)' is not installed on Windows" -ForegroundColor Yellow
    }
}

# Give an instance back the look it had. Either from an archive folder, or from
# an appearance object captured a moment ago (duplicate.ps1, shrink.ps1).
function Set-InstanceState {
    param([string]$Name, [string]$InstallPath, [string]$Folder, [PSCustomObject]$Appearance)

    if ($Folder) {
        $File = Join-Path $Folder "instance.json"
        if (-not (Test-Path $File)) {
            # An archive taken before this existed carries nothing to re-apply.
            # Said out loud, because the reports downstream promise a look.
            Write-Host "  * Look             : the archive carries no instance.json - not re-applied" -ForegroundColor Yellow
            return
        }
        try { $Appearance = Get-Content $File -Raw | ConvertFrom-Json } catch { return }
        $IconInArchive = Join-Path $Folder "terminal-icon.png"
    }

    # The guid WSL just gave the instance: its own fragment, written on import
    $Guid = $null
    $WslFragments = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Microsoft.WSL"
    for ($Attempt = 1; $Attempt -le 5 -and -not $Guid; $Attempt++) {
        if (Test-Path $WslFragments) {
            foreach ($File in (Get-ChildItem $WslFragments -Filter *.json | Sort-Object LastWriteTime -Descending)) {
                try {
                    foreach ($Entry in (Get-Content $File.FullName -Raw | ConvertFrom-Json).profiles) {
                        if (-not $Guid -and $Entry.name -eq $Name -and $Entry.guid) { $Guid = $Entry.guid }
                    }
                } catch { }
            }
        }
        if (-not $Guid) { Start-Sleep -Seconds 1 }
    }

    if (-not $Guid) {
        Write-Host "  * Look             : no WSL fragment for '$Name' yet - not re-applied" -ForegroundColor Yellow
        return
    }

    $IconPath = Join-Path $InstallPath "terminal-icon.png"
    if ($IconInArchive -and (Test-Path $IconInArchive)) {
        Copy-Item -Path $IconInArchive -Destination $IconPath -Force
    } elseif ($Appearance.IconFrom -and (Test-Path $Appearance.IconFrom)) {
        Copy-Item -Path $Appearance.IconFrom -Destination $IconPath -Force
    }

    $FragmentDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-datascience-template"
    New-Item -ItemType Directory -Force $FragmentDir | Out-Null
    # Layered over WSL's own profile via "updates"; the user's settings.json is
    # never touched. Same shape as the fragment build.ps1 writes.
    $FragmentJson = @"
{
    "profiles": [
        {
            "updates": "$Guid",
            "icon": "$($IconPath -replace '\\','\\')",
            "font": { "face": "$($Appearance.Font)" },
            "colorScheme": "$($Appearance.ColorScheme)",
            "suppressApplicationTitle": true
        }
    ]
}
"@
    Set-Content -Path (Join-Path $FragmentDir "$Name.json") -Value $FragmentJson -Encoding Utf8
    Write-Host "  * Look             : font '$($Appearance.Font)', colours '$($Appearance.ColorScheme)', icon re-applied" -ForegroundColor Green

    if (-not (Test-FontInstalled $Appearance.Font)) {
        Write-Host "                       Not installed on Windows: '$($Appearance.Font)'." -ForegroundColor Yellow
        Write-Host "                       The profile points at it, but the prompt will show boxes" -ForegroundColor Yellow
        Write-Host "                       until it is installed." -ForegroundColor Yellow
    }

    # Docker Desktop keeps the distros it knows in its own settings file, by
    # name, and reads that file only when it starts. If the archive says it knew
    # the original, put the new one back - the restart is the price, so it is
    # asked rather than paid quietly.
    if ($Appearance.Docker -eq "yes" -and (Get-DockerState -Name $Name) -eq "no") {
        Write-Host ""
        # [y/N], not [Y/n]: this question lands in the middle of a restore or a
        # copy, where restarting Docker Desktop stops containers for a reason
        # the user may not care about. Nothing happens unless it is asked for.
        $AddToDocker = [string](Read-Host "Add '$Name' to Docker Desktop? (it restarts Docker) [y/N]")
        if ($AddToDocker -match "^[yY]") {
            try {
                Set-DockerState -Name $Name
                $PreviousEAP = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                $null = docker desktop restart *> $null
                $RestartCode = $LASTEXITCODE
                $ErrorActionPreference = $PreviousEAP
                if ($RestartCode -eq 0) {
                    Write-Host "  * Docker Desktop   : added, and restarted to pick it up" -ForegroundColor Green
                } else {
                    Write-Host "  * Docker Desktop   : added - restart it for it to notice" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  * Docker Desktop   : could not be updated ($($_.Exception.Message))" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  * Docker Desktop   : not added - its settings can take it later" -ForegroundColor DarkGray
        }
    }
}

# ---------------------------------------------------------------------------
# DOCKER DESKTOP
# ---------------------------------------------------------------------------
# Docker Desktop injects its CLI into the distros its settings list, and reads
# that list only when it starts. "yes", "no", or "unknown" when Docker Desktop
# is not installed - which is not the same answer as "no" and must be reported
# as what it is.

function Get-DockerState {
    param([string]$Name)

    $Settings = Join-Path $env:APPDATA "Docker\settings-store.json"
    if (-not (Test-Path $Settings)) { return "unknown" }
    try {
        $Config = Get-Content $Settings -Raw | ConvertFrom-Json
        if (@($Config.IntegratedWslDistros) -contains $Name) { return "yes" }
        return "no"
    } catch {
        return "unknown"
    }
}

function Set-DockerState {
    param([string]$Name)

    # The same recipe build.ps1 uses: a backup beside the file, the name
    # rebuilt rather than appended twice, and a byte-order-mark-free write
    # because this file, written by Docker Desktop, does not carry one.
    $Settings = Join-Path $env:APPDATA "Docker\settings-store.json"
    $Config = Get-Content $Settings -Raw | ConvertFrom-Json
    Copy-Item $Settings "$Settings.bak" -Force
    $Config.IntegratedWslDistros = @($Config.IntegratedWslDistros | Where-Object { $_ -and $_ -ne $Name }) + $Name
    $Json = ($Config | ConvertTo-Json -Depth 10) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText("$Settings.tmp", $Json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item "$Settings.tmp" $Settings -Force
}

# ---------------------------------------------------------------------------
# THE INSTANCES, AND WHAT EVERY COMMAND ASKS ABOUT THEM
# ---------------------------------------------------------------------------
# These five used to live in twelve copies across scripts\ - identical to the
# byte, which is how they were found: one hash per function body, twelve files.
# Not one of them was wrong; the cost was that a fix had twelve places to land
# in, and eleven chances to be forgotten. They are here now, where the commands
# already come for the marker and for Docker's answer.

# Halts script execution if an external command (like wsl) fails
function Invoke-External {
    param([scriptblock]$Command, [string]$ErrorMessage)
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$ErrorMessage (Exit code: $LASTEXITCODE)"
    }
}

# Every registered instance, with its folder and its WSL version (1 or 2).
# The registry says what Windows knows; it does not say which of them are ours -
# Test-TemplateInstance answers that, on the folder's marker.
function Get-Distros {
    $Found = @()
    foreach ($Key in Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss -ErrorAction SilentlyContinue) {
        $Props = Get-ItemProperty $Key.PSPath
        if ($Props.DistributionName) {
            $Found += [PSCustomObject]@{
                Name     = $Props.DistributionName
                Version  = if ($Props.Version) { [int]$Props.Version } else { 2 }
                BasePath = ($Props.BasePath -replace '^\\\\\?\\', '').TrimEnd('\')
            }
        }
    }
    return @($Found)
}

# What WSL answers about the instances it knows, which is the only source that
# says whether one is RUNNING - the registry does not. Wrapped in @() for the
# reason every caller wraps it: PowerShell unrolls a one-element list into its
# element, and a string is not a list of one.
function Get-DistroNames {
    param([switch]$Running)
    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $WslArgs = @("--list", "--quiet")
    if ($Running) { $WslArgs += "--running" }
    $Names = (wsl.exe @WslArgs 2>$null) |
        ForEach-Object { ($_ -replace "`0", "").Trim() } |
        Where-Object { $_ }
    $ErrorActionPreference = $PreviousEAP
    return @($Names)
}

# How much room an instance takes on Windows - the .vhdx file's size on disk,
# not what its filesystem holds.
function Get-VhdxSize {
    param([string]$Folder)
    $Vhdx = Join-Path $Folder "ext4.vhdx"
    if (Test-Path $Vhdx) { return (Get-Item $Vhdx).Length }
    return 0
}

function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N1} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N1} MB" -f ($Bytes / 1MB)) }
    return ("{0:N0} KB" -f ($Bytes / 1KB))
}

# ---------------------------------------------------------------------------
# THE MENUS
# ---------------------------------------------------------------------------
# They live beside this file rather than inside it: what the commands share is
# now two things - what this machine is (here) and how it is asked (menu.ps1).
# Same rule as this file when a piece of it is missing: say so, rather than
# die with a PowerShell error that reads like the machine's fault.
$MenuLib = Join-Path $PSScriptRoot "menu.ps1"
if (-not (Test-Path $MenuLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\menu.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $MenuLib
