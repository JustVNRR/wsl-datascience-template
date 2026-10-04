[CmdletBinding()]
param (
)

# No parameter on purpose: the source comes from the list, never from the
# command line, and the copy's name is asked for.

$ErrorActionPreference = "Stop"

# One working folder, no guessing: the copy lands in <Root>\<name>, the folder
# build.ps1 proposes.
$Root = if (Test-Path "D:\") { "D:\WSL" } else { "$env:USERPROFILE\WSL" }

# The family's shared half: the marker, and the Windows-side look - captured
# off the source now, re-applied to the copy after the import.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
    exit 1
}
. $InstanceLib

# 0. Which instance to copy
$AllDistros = Get-Distros
$Source = Select-Distro
$SourceDistro = $Source.Name

# 0-bis. The copy's name: typed, because there is nothing to pick from. The
# question comes back until the name is usable.
while ($true) {
    $Answer = [string](Read-Host "Name of the copy")
    if ([string]::IsNullOrWhiteSpace($Answer)) {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was created." -ForegroundColor (Get-MessageColour success)
        exit 0
    }
    if ($Answer.Trim() -match '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
        $NewDistroName = $Answer.Trim()
        break
    }
    Write-Host "  Letters, digits, '.', '_' and '-' only." -ForegroundColor (Get-MessageColour hint)
}

# This script never unregisters anything, so a name already taken is a dead
# end, not something to resolve.
if ($AllDistros | Where-Object { $_.Name -eq $NewDistroName }) {
    Write-Host ""
    Write-Host "[ABORT] An instance named '$NewDistroName' already exists." -ForegroundColor (Get-MessageColour error)
    Write-Host "        Pick another name." -ForegroundColor (Get-MessageColour hint)
    Write-Host "        Nothing was modified." -ForegroundColor (Get-MessageColour muted)
    exit 1
}

# The export stops the source - WSL terminates it to read a consistent disk -
# and unsaved work is gone: ask rather than surprise.
$StoppedByUs = $false
if ((Get-DistroNames -Running) -contains $SourceDistro) {
    Write-Host ""
    Write-Host "  '$SourceDistro' is running, and this needs it stopped." -ForegroundColor (Get-MessageColour warning)
    Write-Host "  Save what you have open in there: stopping it loses anything unsaved." -ForegroundColor (Get-MessageColour warning)
    $StopIt = [string](Read-Host "Stop it now? [Y/n]")
    if ($StopIt -match "^[nN]") {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor (Get-MessageColour success)
        exit 0
    }
    $Source.Stop()
    Write-Host "  Stopped." -ForegroundColor (Get-MessageColour muted)
    $StoppedByUs = $true
}

# 1. Install folder: <Root>\<name>, always - a taken name was refused above,
# so this folder cannot be another instance's.
$FullDestination = [System.IO.Path]::GetFullPath((Join-Path $Root $NewDistroName))

# 2. What it costs: the copy reads the instance into an archive and unpacks it
# into the new folder, both at the same time - twice the disk is the peak
# checked here.
#
# The archive route rather than a raw disk copy (`--format vhd`): a vhd export
# is refused with ERROR_SHARING_VIOLATION while the WSL virtual machine is up -
# `--terminate` does not release it, only a full `--shutdown` does, and that
# stops every other instance. The copy pays the compression instead.
$VhdxPath = Join-Path $Source.Path "ext4.vhdx"
$DiskBytes = if (Test-Path $VhdxPath) { (Get-Item $VhdxPath).Length } else { 0 }
$NeededBytes = 2 * $DiskBytes

$DriveLetter = (Split-Path -Qualifier $FullDestination).TrimEnd(':')
$FreeBytes = (Get-PSDrive -Name $DriveLetter).Free

Write-Host ""
Write-Host "==> Duplicating '$SourceDistro' into '$NewDistroName'" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Source disk      : $(Format-Size $DiskBytes)" -ForegroundColor (Get-MessageColour muted)
Write-Host "  * Needed on $DriveLetter`:      : $(Format-Size $NeededBytes) (archive + copy at peak)" -ForegroundColor (Get-MessageColour muted)
Write-Host "  * Free on $DriveLetter`:        : $(Format-Size $FreeBytes)" -ForegroundColor (Get-MessageColour muted)
Write-Host "  * Install folder   : $FullDestination" -ForegroundColor (Get-MessageColour muted)

if ($FreeBytes -lt $NeededBytes) {
    Write-Host ""
    Write-Host "[ABORT] Not enough room on $DriveLetter`:." -ForegroundColor (Get-MessageColour error)
    Write-Host "        Needed: $(Format-Size $NeededBytes) - free: $(Format-Size $FreeBytes)." -ForegroundColor (Get-MessageColour warning)
    Write-Host "        Free some space, then run this again." -ForegroundColor (Get-MessageColour hint)
    Write-Host "        Nothing was modified." -ForegroundColor (Get-MessageColour muted)
    exit 1
}

$DestinationDir = Split-Path -Path $FullDestination -Parent
if (-not (Test-Path -Path $DestinationDir)) {
    New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
}

# 3. Copy: the source is only read. The temporary image is removed by the
# copy itself, in all cases - it is worth twice the disk, and leaving it
# would eat the room just checked for.
try {
    Write-Host "==> 1. Reading the source (the source itself is not modified)..." -ForegroundColor (Get-MessageColour info)
    Write-Host "==> 2. Registering '$NewDistroName' from it..." -ForegroundColor (Get-MessageColour info)
    $Copy = $Source.Duplicate($NewDistroName)
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    Write-Host "        The source was not modified." -ForegroundColor (Get-MessageColour muted)
    if ($_.Exception.Message -like "*import*") {
        Write-Host "        A half-registered '$NewDistroName' may be left behind:" -ForegroundColor (Get-MessageColour warning)
        Write-Host "        remove it with  .\wsl.ps1 unregister        (pick '$NewDistroName' in the list)" -ForegroundColor (Get-MessageColour hint)
    }
    exit 1
}

$CopyVhdx = Join-Path $FullDestination "ext4.vhdx"
$CopyBytes = if (Test-Path $CopyVhdx) { (Get-Item $CopyVhdx).Length } else { 0 }

# The copy has its own profile and its own guid: the look is re-applied from
# the values captured before the export - Docker Desktop's entry too, keyed by
# name.
Set-InstanceState -Name $NewDistroName -InstallPath $FullDestination -Appearance $Copy.Look

Write-Host ""
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "       '$NewDistroName' is a copy of '$SourceDistro'" -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$FullDestination" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Copy on disk     : " -NoNewline; Write-Host "$(Format-Size $CopyBytes)" -ForegroundColor (Get-MessageColour info)
Write-Host "  * WSL version      : " -NoNewline; Write-Host "$($Source.Version)" -ForegroundColor (Get-MessageColour info)
Write-Host ""
Write-Host "  Windows Terminal: the copy gets a profile of its own, with the icon," -ForegroundColor (Get-MessageColour muted)
Write-Host "  the font and the colours of the source. Restart Terminal to see it." -ForegroundColor (Get-MessageColour muted)
Write-Host ""

# Left the way it was found.
if ($StoppedByUs) {
    try {
        $Source.Start()
        Write-Host "'$SourceDistro' is running again." -ForegroundColor (Get-MessageColour success)
    } catch {
        Write-Host "Could not restart '$SourceDistro' - start it with: wsl -d $SourceDistro" -ForegroundColor (Get-MessageColour warning)
    }
    Write-Host ""
}
