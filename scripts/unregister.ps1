[CmdletBinding()]
param ()

# No parameter on purpose: the instance comes from the list, never from the
# command line, and the removal asks for the name to be typed before anything
# happens. This script never chooses its own target.

$ErrorActionPreference = "Stop"

# Where the instances live, for the one case the list cannot serve.
$Root = if (Test-Path "D:\") { "D:\WSL" } else { "$env:USERPROFILE\WSL" }

# The family's shared half: the marker that tells our instances from any other -
# a removal that cannot tell them apart targets whatever the registry holds.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
    exit 1
}
. $InstanceLib

# ==============================================================================
# 1. WHICH DISTRO (from the list, always)
# ==============================================================================
# The list is the only way in. A folder left behind by an earlier removal is
# deleted by hand, not by naming it here.
$Ours = @([WslInstanceManager]::Ours())
if ($Ours.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor (Get-MessageColour error)
    Write-Host "        Nothing to remove." -ForegroundColor (Get-MessageColour hint)
    Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor (Get-MessageColour hint)
    Write-Host "        (A folder left behind by an earlier removal is deleted by hand: $Root)" -ForegroundColor (Get-MessageColour muted)
    exit 1
}

$Distro = Select-Distro
$DistroName = $Distro.Name

$InstallPath = $Distro.Path

# ==============================================================================
# 2. CONFIRMATION (destructive) - same style as build.ps1
# ==============================================================================
if ($Distro) {
    [Console]::Beep(1000, 400)
    Write-Host ""
    Write-DangerBanner
    Write-Host ""
    Write-Host "  The WSL distribution '$DistroName' and ALL its data will be deleted:" -ForegroundColor (Get-MessageColour error)
    Write-Host ""
    Write-Host "  Proceeding will PERMANENTLY DESTROY this distribution:" -ForegroundColor (Get-MessageColour warning)
    Write-Host "    - Executing: wsl --unregister $DistroName" -ForegroundColor (Get-MessageColour muted)
    Write-Host "    - IRREVERSIBLE DELETION of the virtual disk (VHDX)" -ForegroundColor (Get-MessageColour muted)
    Write-Host "    - TOTAL LOSS of projects, SSH keys, and all files in /home" -ForegroundColor (Get-MessageColour muted)
    Write-Host ""
    Write-Host "  THIS OPERATION CANNOT BE UNDONE." -ForegroundColor (Get-MessageColour error)
    Write-Host ""
    Write-Host " ----------------------------------------------------------------------" -ForegroundColor (Get-MessageColour muted)
    Write-Host " Press ENTER to abort immediately." -ForegroundColor (Get-MessageColour hint)
    Write-Host " To confirm DESTRUCTION, type the exact name of the distribution:" -ForegroundColor (Get-MessageColour hint)
    $Confirmation = Read-Host " Confirm"
    Write-Host " ----------------------------------------------------------------------" -ForegroundColor (Get-MessageColour muted)
    Write-Host ""

    # -cne, not -ne: PowerShell's -ne ignores case, while the banner above asks
    # for the exact name.
    if ($Confirmation -cne $DistroName) {
        Write-Host "[ABORT] Operation cancelled. No data was modified." -ForegroundColor (Get-MessageColour success)
        exit 0
    }

    # The last moment to take a copy. archive.ps1 writes it to <Root>\archives,
    # stops the instance if needed, and leaves it stopped.
    Write-Host ""
    $ArchiveIt = [string](Read-Host "Archive it before deleting? [y/N]")
    if ($ArchiveIt -match "^[yY]") {
        $ArchiveScript = Join-Path $PSScriptRoot "archive.ps1"
        if (-not (Test-Path $ArchiveScript)) {
            Write-Host ""
            Write-Host "[ABORT] archive.ps1 is not next to this script - not deleting anything." -ForegroundColor (Get-MessageColour error)
            Write-Host "        The instance is untouched." -ForegroundColor (Get-MessageColour muted)
            exit 1
        }
        & $ArchiveScript -DistroName $DistroName -Name $DistroName -AfterExport Leave
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "[ABORT] The archive did not complete - not deleting anything." -ForegroundColor (Get-MessageColour error)
            Write-Host "        The instance is untouched." -ForegroundColor (Get-MessageColour muted)
            exit 1
        }
    }

    # The destruction belongs to the instance now - the stop (its failure
    # ignored: a distro half gone must not block its own removal), the
    # unregister, the install folder and the Windows-side housekeeping; what
    # it found comes back for the report below. The archive, when asked for
    # above, was written by archive.ps1 - its own report and its own guards.
    Write-Host "==> Stopping the distro processes..." -ForegroundColor (Get-MessageColour info)
    Write-Host "==> Unregistering the distro..." -ForegroundColor (Get-MessageColour info)
    $Removed = $Distro.Unregister($false)
}

# ==============================================================================
# 3. WHAT BECAME OF IT (reported; the removal itself was the instance's)
# ==============================================================================
if ($Removed.FolderState -eq "removed") {
    Write-Host "==> Removing installation folder ($InstallPath)..." -ForegroundColor (Get-MessageColour info)
} elseif ($Removed.FolderState -eq "removed with the distribution") {
    Write-Host "==> Installation folder already gone - wsl --unregister removes it with the distribution." -ForegroundColor (Get-MessageColour info)
} else {
    Write-Host "==> No installation folder found ($InstallPath)." -ForegroundColor (Get-MessageColour info)
}

# ==============================================================================
# 4. WINDOWS TERMINAL AND DOCKER (reported; the cleaning was the instance's)
# ==============================================================================
Write-Host "==> Cleaning Windows Terminal leftovers..." -ForegroundColor (Get-MessageColour info)
foreach ($SettingsPath in $Removed.Unreadable) {
    Write-Host "  * settings.json : ghost entries NOT pruned in $SettingsPath" -ForegroundColor (Get-MessageColour warning)
    Write-Host "                    (unreadable JSON - a // comment breaks ConvertFrom-Json; remove them by hand)" -ForegroundColor (Get-MessageColour muted)
}
if ($Removed.GhostsPruned -gt 0) {
    Write-Host "  * settings.json : pruned $($Removed.GhostsPruned) ghost '$DistroName' entries" -ForegroundColor (Get-MessageColour success)
}
if ($Removed.FragmentsRemoved -gt 0) {
    Write-Host "  * fragments     : removed $($Removed.FragmentsRemoved) appearance file(s)" -ForegroundColor (Get-MessageColour success)
}
if ($Removed.DockerError) {
    Write-Host "  * Docker Desktop : list not updated ($($Removed.DockerError))" -ForegroundColor (Get-MessageColour warning)
} elseif ($Removed.DockerRemoved) {
    Write-Host "  * Docker Desktop : '$DistroName' removed from the integrated distros" -ForegroundColor (Get-MessageColour success)
}

# ==============================================================================
# SUMMARY
# ==============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "                WSL Stack Instance Removed!" -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
Write-Host "  * Distro          : " -NoNewline; Write-Host "$DistroName" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Install folder  : " -NoNewline
if ($Removed.FolderState -eq "removed") {
    Write-Host "$($Removed.FolderState)" -ForegroundColor (Get-MessageColour success)
} else {
    Write-Host "$($Removed.FolderState)" -ForegroundColor (Get-MessageColour muted)
}
Write-Host "  * Terminal ghosts : " -NoNewline; Write-Host "$($Removed.GhostsPruned) pruned" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Fragments       : " -NoNewline; Write-Host "$($Removed.FragmentsRemoved) removed" -ForegroundColor (Get-MessageColour info)
Write-Host ""
Write-Host " Restart Windows Terminal to refresh the profile list."
Write-Host ""
