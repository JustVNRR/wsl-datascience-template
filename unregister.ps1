[CmdletBinding()]
param ()

# No parameter on purpose: the instance comes from the list, never from the
# command line, and the removal still asks for the name to be typed before
# anything happens. This script never chooses its own target.

$ErrorActionPreference = "Stop"

# Where the instances live, for the one case the list cannot serve.
$Root = if (Test-Path "D:\") { "D:\WSL" } else { "$env:USERPROFILE\WSL" }

# Halts script execution if an external command (like wsl) fails
function Invoke-External {
    param([scriptblock]$Command, [string]$ErrorMessage)
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$ErrorMessage (Exit code: $LASTEXITCODE)"
    }
}

# Reading what wsl.exe prints while it may write on its error stream: under
# $ErrorActionPreference = "Stop" a redirection turns that stderr into a
# TERMINATING error. "Continue" for the call, then put it back - the same
# guard build.ps1 uses around `docker info` and `wsl --unregister`.
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

# Every registered instance, with its folder and its WSL version (1 or 2)
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

function Get-Distro {
    param([string]$Name)
    return (Get-Distros | Where-Object { $_.Name -eq $Name } | Select-Object -First 1)
}

function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N1} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N1} MB" -f ($Bytes / 1MB)) }
    return ("{0:N0} KB" -f ($Bytes / 1KB))
}

function Get-VhdxSize {
    param([string]$Folder)
    $Vhdx = Join-Path $Folder "ext4.vhdx"
    if (Test-Path $Vhdx) { return (Get-Item $Vhdx).Length }
    return 0
}

# The choice every command in this family offers: the instances that exist,
# numbered, with what is worth knowing about each, and a way out. The question
# comes back until the answer is one of the numbers - an empty answer cancels,
# so a run with no console can never loop forever.
function Select-Distro {
    # Sorted by name: the registry order changes between runs, and a menu
    # whose numbers move is a menu you cannot trust twice.
    $All = Get-Distros | Sort-Object Name
    if ($All.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] No WSL instance is registered on this machine." -ForegroundColor Red
        Write-Host "        Build one with  .\build.ps1" -ForegroundColor Yellow
        exit 1
    }

    $Running = Get-DistroNames -Running

    Write-Host ""
    Write-Host "Instances registered on this machine:" -ForegroundColor Cyan
    for ($Index = 0; $Index -lt $All.Count; $Index++) {
        $Entry = $All[$Index]
        $State = if ($Running -contains $Entry.Name) { "running" } else { "stopped" }
        Write-Host ("  {0,2}.  {1,-30} {2,-8} {3,10}" -f ($Index + 1), $Entry.Name, $State,
            (Format-Size (Get-VhdxSize $Entry.BasePath)))
    }
    Write-Host "   0.  Cancel"

    while ($true) {
        $Answer = [string](Read-Host "Which one? (0 to cancel)")
        if ([string]::IsNullOrWhiteSpace($Answer)) {
            Write-Host ""
            Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
            exit 0
        }
        $Number = 0
        if ([int]::TryParse($Answer.Trim(), [ref]$Number)) {
            if ($Number -eq 0) {
                Write-Host ""
                Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
                exit 0
            }
            if ($Number -ge 1 -and $Number -le $All.Count) {
                return $All[$Number - 1]
            }
        }
        Write-Host "  '$Answer' is not one of the numbers above." -ForegroundColor Yellow
    }
}

# ==============================================================================
# 1. WHICH DISTRO (from the list, always)
# ==============================================================================
# The list is the only way in. With nothing registered there is nothing to
# remove - and a folder left behind by an earlier removal is deleted by hand,
# not by naming it.
if ((Get-Distros).Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No WSL instance is registered on this machine." -ForegroundColor Red
    Write-Host "        If a removal left a folder behind, delete it by hand:" -ForegroundColor Yellow
    Write-Host "        $Root" -ForegroundColor White
    exit 1
}

$Distro = Select-Distro
$DistroName = $Distro.Name

# Taken before the removal, so that afterwards the two cases can be told apart
$InstallPath = $Distro.BasePath
$FolderExisted = Test-Path $InstallPath

# ==============================================================================
# 2. CONFIRMATION (destructive) - same style as build.ps1
# ==============================================================================
if ($Distro) {
    [Console]::Beep(1000, 400)
    Write-Host ""
    Write-Host " /!\ ================================================================ /!\" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host " |                     DANGER: TOTAL DATA LOSS IMMINENT               |" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host " \!/ ================================================================ \!/" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host ""
    Write-Host "  The WSL distribution '$DistroName' and ALL its data will be deleted:" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Proceeding will PERMANENTLY DESTROY this distribution:" -ForegroundColor Yellow
    Write-Host "    - Executing: wsl --unregister $DistroName" -ForegroundColor DarkGray
    Write-Host "    - IRREVERSIBLE DELETION of the virtual disk (VHDX)" -ForegroundColor DarkGray
    Write-Host "    - TOTAL LOSS of projects, SSH keys, and all files in /home" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  THIS OPERATION CANNOT BE UNDONE." -ForegroundColor Red
    Write-Host ""
    Write-Host " ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " Press ENTER to abort immediately." -ForegroundColor Yellow
    Write-Host " To confirm DESTRUCTION, type the exact name of the distribution:" -ForegroundColor Yellow
    $Confirmation = Read-Host " Confirm"
    Write-Host " ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    # -cne, not -ne: PowerShell's -ne ignores case, while the banner above asks
    # for the exact name.
    if ($Confirmation -cne $DistroName) {
        Write-Host "[ABORT] Operation cancelled. No data was modified." -ForegroundColor Green
        exit 0
    }

    # What is about to be destroyed is worth a copy, and this is the last
    # moment to take one. archive.ps1 writes it to <Root>\archives, asks to
    # stop the instance if it is still running, and leaves it stopped.
    Write-Host ""
    $ArchiveIt = [string](Read-Host "Archive it before deleting? [y/N]")
    if ($ArchiveIt -match "^[yY]") {
        $ArchiveScript = Join-Path $PSScriptRoot "archive.ps1"
        if (-not (Test-Path $ArchiveScript)) {
            Write-Host ""
            Write-Host "[ABORT] archive.ps1 is not next to this script - not deleting anything." -ForegroundColor Red
            Write-Host "        The instance is untouched." -ForegroundColor DarkGray
            exit 1
        }
        & $ArchiveScript -DistroName $DistroName -Name $DistroName -AfterExport Leave
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "[ABORT] The archive did not complete - not deleting anything." -ForegroundColor Red
            Write-Host "        The instance is untouched." -ForegroundColor DarkGray
            exit 1
        }
    }

    Write-Host "==> Unregistering the distro..." -ForegroundColor Cyan
    Invoke-External { wsl.exe --unregister $DistroName } "WSL unregister failed."
}

# ==============================================================================
# 3. INSTALLATION FOLDER (registry BasePath, or the default location)
# ==============================================================================
# wsl --unregister removes the install folder with the distribution, so
# anything left here is the exception. The cases are told apart: a folder WSL
# removed with the distribution is not a folder that was never there.
if (Test-Path $InstallPath) {
    Write-Host "==> Removing installation folder ($InstallPath)..." -ForegroundColor Cyan
    Remove-Item -Recurse -Force $InstallPath
    $FolderState = "removed"
} elseif ($FolderExisted) {
    Write-Host "==> Installation folder already gone - wsl --unregister removes it with the distribution." -ForegroundColor Cyan
    $FolderState = "removed with the distribution"
} else {
    Write-Host "==> No installation folder found ($InstallPath)." -ForegroundColor Cyan
    $FolderState = "not found"
}

# ==============================================================================
# 4. WINDOWS TERMINAL CLEANUP (ghost settings entries, our fragments)
# ==============================================================================
Write-Host "==> Cleaning Windows Terminal leftovers..." -ForegroundColor Cyan

# Live profile guids = the WSL fragments still on disk (WSL removed the dead one)
$WslFragmentsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Microsoft.WSL"
$LiveGuids = @()
if (Test-Path $WslFragmentsDir) {
    foreach ($File in (Get-ChildItem $WslFragmentsDir -Filter *.json)) {
        try {
            $Fragment = Get-Content $File.FullName -Raw | ConvertFrom-Json
            foreach ($Entry in $Fragment.profiles) {
                if ($Entry.guid) { $LiveGuids += $Entry.guid }
            }
        } catch { }
    }
}

# Ghost entries in the user's settings.json (Terminal persists them when a
# profile's source disappears). Same pruning as build.ps1 step 9.
$GhostsPruned = 0
foreach ($SettingsPath in @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)) {
    if (-not (Test-Path $SettingsPath)) { continue }
    try {
        $Settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
        $All = @($Settings.profiles.list)
        $Kept = @($All | Where-Object { -not ($_.source -eq "Microsoft.WSL" -and $_.name -eq $DistroName -and $LiveGuids -notcontains $_.guid) })
        if ($Kept.Count -ne $All.Count) {
            Copy-Item $SettingsPath "$SettingsPath.bak" -Force
            $Settings.profiles.list = $Kept
            $Settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding Utf8
            $GhostsPruned += $All.Count - $Kept.Count
        }
    } catch {
        Write-Host "  * settings.json : ghost entries NOT pruned in $SettingsPath" -ForegroundColor Yellow
        Write-Host "                    (unreadable JSON - a // comment breaks ConvertFrom-Json; remove them by hand)" -ForegroundColor DarkGray
    }
}
if ($GhostsPruned -gt 0) {
    Write-Host "  * settings.json : pruned $GhostsPruned ghost '$DistroName' entries" -ForegroundColor Green
}

# Our appearance fragment files (one per distro, named <DistroName>.json)
$OurFragmentDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-datascience-template"
$FragmentsRemoved = 0
if (Test-Path $OurFragmentDir) {
    $OwnFile = Join-Path $OurFragmentDir "$DistroName.json"
    if (Test-Path $OwnFile) {
        Remove-Item $OwnFile -Force
        $FragmentsRemoved++
    }
    # Any other of our files whose target distro no longer exists
    if ($LiveGuids.Count -gt 0) {
        foreach ($File in (Get-ChildItem $OurFragmentDir -Filter *.json)) {
            try {
                $Fragment = Get-Content $File.FullName -Raw | ConvertFrom-Json
                $Target = ($Fragment.profiles | Where-Object { $_.updates } | Select-Object -First 1).updates
                if ($Target -and ($LiveGuids -notcontains $Target)) {
                    Remove-Item $File.FullName -Force
                    $FragmentsRemoved++
                }
            } catch { }
        }
    }
}
if ($FragmentsRemoved -gt 0) {
    Write-Host "  * fragments     : removed $FragmentsRemoved appearance file(s)" -ForegroundColor Green
}

# ==============================================================================
# 5. DOCKER DESKTOP (its own list of integrated distros)
# ==============================================================================
# Docker Desktop injects its client into the distros it lists, and reads that
# list when it starts. build.ps1 offers to add the name there; a removal that
# left it behind would keep a name pointing at nothing.
$DockerSettings = Join-Path $env:APPDATA "Docker\settings-store.json"
if (Test-Path $DockerSettings) {
    try {
        $DockerConfig = Get-Content $DockerSettings -Raw | ConvertFrom-Json
        if ($DockerConfig.IntegratedWslDistros -contains $DistroName) {
            Copy-Item $DockerSettings "$DockerSettings.bak" -Force
            $DockerConfig.IntegratedWslDistros = @($DockerConfig.IntegratedWslDistros | Where-Object { $_ -and $_ -ne $DistroName })
            # Written beside the file and swapped in, and with WriteAllText
            # rather than Set-Content: Docker Desktop's file carries no
            # byte-order mark, and PowerShell's -Encoding Utf8 adds one.
            $DockerJson = ($DockerConfig | ConvertTo-Json -Depth 10) -replace "`r`n", "`n"
            [System.IO.File]::WriteAllText("$DockerSettings.tmp", $DockerJson, (New-Object System.Text.UTF8Encoding($false)))
            Move-Item "$DockerSettings.tmp" $DockerSettings -Force
            Write-Host "  * Docker Desktop : '$DistroName' removed from the integrated distros" -ForegroundColor Green
        }
    } catch {
        Write-Host "  * Docker Desktop : list not updated ($($_.Exception.Message))" -ForegroundColor Yellow
    }
}

# ==============================================================================
# SUMMARY
# ==============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "          WSL Data Science Instance Removed!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  * Distro          : " -NoNewline; Write-Host "$DistroName" -ForegroundColor Cyan
Write-Host "  * Install folder  : " -NoNewline
if ($FolderState -eq "removed") {
    Write-Host "$FolderState" -ForegroundColor Green
} elseif ($FolderState -eq "kept") {
    Write-Host "$FolderState" -ForegroundColor Yellow
} else {
    Write-Host "$FolderState" -ForegroundColor DarkGray
}
Write-Host "  * Terminal ghosts : " -NoNewline; Write-Host "$GhostsPruned pruned" -ForegroundColor Cyan
Write-Host "  * Fragments       : " -NoNewline; Write-Host "$FragmentsRemoved removed" -ForegroundColor Cyan
Write-Host ""
Write-Host " Restart Windows Terminal to refresh the profile list."
Write-Host ""
