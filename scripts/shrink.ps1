[CmdletBinding()]
param ()

# No parameter on purpose: the instance comes from the list - a name typed by
# heart is a name you can get wrong.

$ErrorActionPreference = "Stop"

# One working folder, no guessing: instances in <Root>\<name>, archives in
# <Root>\archives - the family's rule.
$Root = if (Test-Path "D:\") { "D:\WSL" } else { "$env:USERPROFILE\WSL" }

# The family's shared half: the marker.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
    exit 1
}
. $InstanceLib

function Get-Distro {
    param([string]$Name)
    foreach ($Key in Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss -ErrorAction SilentlyContinue) {
        $Props = Get-ItemProperty $Key.PSPath
        if ($Props.DistributionName -eq $Name) {
            return [PSCustomObject]@{
                Name     = $Name
                BasePath = ($Props.BasePath -replace '^\\\\\?\\', '').TrimEnd('\')
            }
        }
    }
    return $null
}

# 1. Which instance
$Distro = Select-Distro
$DistroName = $Distro.Name

# Compacting works either way, but the archive does not - whatever we stop is
# started again at the end.
$WasRunning = (Get-DistroNames -Running) -contains $DistroName

$BeforeBytes = Get-VhdxSize $Distro.BasePath

Write-Host ""
Write-Host "==> Reclaiming space in '$DistroName'" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Disk file now    : $(Format-Size $BeforeBytes)" -ForegroundColor (Get-MessageColour muted)
Write-Host ""
Write-Host "  This compacts the instance's virtual disk: the space its filesystem has" -ForegroundColor (Get-MessageColour muted)
Write-Host "  freed over time comes back to Windows. Nothing inside is touched." -ForegroundColor (Get-MessageColour muted)

# 2. A copy first, yes by default: compacting rewrites the disk's metadata -
# exactly what a backup a minute before turns into a non-event.
$ArchiveScript = Join-Path $PSScriptRoot "archive.ps1"
Write-Host ""
$ArchiveFirst = [string](Read-Host "Archive it first? [Y/n]")
if ($ArchiveFirst -match "^[nN]") {
    Write-Host "  No archive - compacting on its own." -ForegroundColor (Get-MessageColour muted)
} else {
    if (-not (Test-Path $ArchiveScript)) {
        Write-Host ""
        Write-Host "[ABORT] archive.ps1 is not next to this script - no archive, no operation." -ForegroundColor (Get-MessageColour error)
        Write-Host "        Nothing was modified." -ForegroundColor (Get-MessageColour muted)
        exit 1
    }
    # Leave: shrink decides what the instance does next, not the archive step.
    & $ArchiveScript -DistroName $DistroName -Name $DistroName -AfterExport Leave
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "[ABORT] The archive did not complete - nothing was compacted." -ForegroundColor (Get-MessageColour error)
        Write-Host "        The instance is exactly as it was." -ForegroundColor (Get-MessageColour muted)
        exit 1
    }
}

# 3. Compact. One command, in place, working on a running instance; it refuses
# on its own if the disk cannot be compacted - nothing to prepare, nothing to
# undo.
Write-Host ""
Write-Host "==> Compacting the virtual disk..." -ForegroundColor (Get-MessageColour info)
try {
    Invoke-External { wsl.exe --manage $DistroName --compact } "The compact failed."
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    Write-Host "        The instance is untouched." -ForegroundColor (Get-MessageColour muted)
    exit 1
}

$AfterBytes = Get-VhdxSize $Distro.BasePath
$FreedBytes = $BeforeBytes - $AfterBytes

Write-Host ""
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "       '$DistroName' compacted" -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
Write-Host "  * Disk file        : " -NoNewline
Write-Host "$(Format-Size $BeforeBytes) -> $(Format-Size $AfterBytes)" -ForegroundColor (Get-MessageColour info)
if ($FreedBytes -gt 0) {
    Write-Host "  * Reclaimed        : " -NoNewline; Write-Host "$(Format-Size $FreedBytes)" -ForegroundColor (Get-MessageColour success)
} else {
    Write-Host "  * Reclaimed        : " -NoNewline
    Write-Host "nothing - the disk held no space to give back" -ForegroundColor (Get-MessageColour muted)
}

# 4. Left the way it was found: `--exec` runs a command and returns, so it
# comes back up without a shell.
if ($WasRunning) {
    try {
        Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."
        Write-Host "'$DistroName' is running again." -ForegroundColor (Get-MessageColour success)
    } catch {
        Write-Host "Could not start '$DistroName' - start it with: wsl -d $DistroName" -ForegroundColor (Get-MessageColour warning)
    }
    Write-Host ""
}
