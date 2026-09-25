[CmdletBinding()]
param ()

# Several packs at once: every pack this checkout carries is shown, the ones the
# instance already has arrive checked, and what comes back is applied - the
# missing ones installed, the unchecked ones taken out.
#
# The asking and the applying live in scripts\packs.ps1, because build asks the
# same question with the same menu and applies the same answer in the same
# order. What is left here is the shape of this command: which instance, what it
# carries now, and what it says at the end.

$ErrorActionPreference = "Stop"

# What the whole family shares: the instances, the menus, the packs, and the
# moves a pack makes - copy its folder in, run one of its scripts, take the
# folder out.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

# 1. Which instance
$Distro = Select-Distro
$DistroName = $Distro.Name

Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."

$InstanceHome = Get-InstanceHome -DistroName $DistroName
if (-not $InstanceHome) {
    Write-Host ""
    Write-Host "[ABORT] '$DistroName' did not say where its user's home is." -ForegroundColor Red
    exit 1
}
$PacksDirectory = "$InstanceHome/.config/packs"

# 2. Every pack this checkout carries, and what that instance already has
$Available = @(Get-AvailablePacks)
if ($Available.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No pack found in $PacksRoot." -ForegroundColor Red
    Write-Host "        A pack is a folder there carrying a pack.conf." -ForegroundColor Yellow
    exit 1
}
$Installed = @(Get-InstalledPacks -DistroName $DistroName -PacksDirectory $PacksDirectory)

# 3. The checklist, and what it says to do
$Selection = Select-Packs -Title "Packs for '$DistroName'" -Available $Available -Installed $Installed

if ($null -eq $Selection) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}
if ($Selection.ToAdd.Count -eq 0 -and $Selection.ToRemove.Count -eq 0) {
    Write-Host ""
    Write-Host "[OK] Nothing to do: '$DistroName' already has exactly that." -ForegroundColor Green
    exit 0
}

# 4. What was asked for, in the one order that works
$Failure = Invoke-PackApply -DistroName $DistroName -PacksDirectory $PacksDirectory `
    -ToAdd $Selection.ToAdd -ToRemove $Selection.ToRemove
if ($null -ne $Failure) { exit $Failure.ExitCode }

# 5. Where things stand, read back from the instance: the folder is the state,
# so the answer is what is there, not what this run meant to do.
$Now = @(Get-InstalledPacks -DistroName $DistroName -PacksDirectory $PacksDirectory)
Write-Host ""
Write-Host "==> '$DistroName' now carries: $(if ($Now.Count -gt 0) { $Now -join ', ' } else { 'no pack' })" -ForegroundColor Green
if ($Selection.ToAdd.Count -gt 0) {
    Write-Host "    Open a shell in it to use them:  .\wsl.ps1 shell" -ForegroundColor DarkGray
    Write-Host "    Then, in there:  gmake env_global_enable   (adds their variables)" -ForegroundColor DarkGray
}
exit 0
