[CmdletBinding()]
param ()

# No parameter on purpose: the instance comes from a list - the ones that are
# running - never from the command line. Typing a name by heart is a name you
# can get wrong.

$ErrorActionPreference = "Stop"

# What the whole family shares: how to tell one of our instances from any other
# registered one.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
    exit 1
}
. $InstanceLib

# 1. Who can be restarted: our instances running at this moment, and only those
# - a stopped one has `start` for that, and offering it here would be two
# commands for one thing. Sorted by name, like every list in this family: a menu
# whose numbers move is a menu you cannot trust twice.
$All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.BasePath } | Sort-Object Name)
if ($All.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor (Get-MessageColour error)
    Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor (Get-MessageColour hint)
    exit 1
}

$Running = Get-DistroNames -Running
$Eligible = @($All | Where-Object { $Running -contains $_.Name })

if ($Eligible.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No instance is running." -ForegroundColor (Get-MessageColour error)
    Write-Host "        Nothing to restart." -ForegroundColor (Get-MessageColour hint)
    exit 1
}

$Distro = Select-FromList -Title "Running instances - the ones that can be restarted:" -Items $Eligible -Label {
    param($Entry)
    "{0,-30} {1,10}" -f $Entry.Name, (Format-Size (Get-VhdxSize $Entry.BasePath))
}

if (-not $Distro) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor (Get-MessageColour success)
    exit 0
}

$DistroName = $Distro.Name

# 2. A restart is a stop with a start behind it, and the stop is the one thing
# here that can lose work: what is open in there and not saved goes with it. The
# disk is not touched - only what is in memory. Asked once, default yes, because
# picking the instance in the list was already a deliberate act.
Write-Host ""
Write-Host "  '$DistroName' will be stopped, then started again." -ForegroundColor (Get-MessageColour warning)
Write-Host "  Whatever is open in there and not saved is lost; what is already" -ForegroundColor (Get-MessageColour warning)
Write-Host "  written on the disk stays exactly as it is." -ForegroundColor (Get-MessageColour warning)
$Confirm = [string](Read-Host "Restart it? [Y/n]")
if ($Confirm -match "^[nN]") {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor (Get-MessageColour success)
    exit 0
}

# 3. The two halves, in the order that makes the second one a fresh start:
# WSL reads /etc/wsl.conf and /etc/resolv.conf when the instance boots, and
# that is the point of the command. `--exec` runs a command and returns, so the
# instance comes back up without this script opening a shell in it.
Write-Host ""
Write-Host "==> Stopping '$DistroName'..." -ForegroundColor (Get-MessageColour info)
try {
    Invoke-External { wsl.exe --terminate $DistroName } "Could not stop '$DistroName'."
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    Write-Host "        '$DistroName' may still be running, and was not started again." -ForegroundColor (Get-MessageColour muted)
    exit 1
}

Write-Host ""
Write-Host "==> Starting '$DistroName'..." -ForegroundColor (Get-MessageColour info)
try {
    Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    Write-Host "        '$DistroName' is stopped - start it with  .\wsl.ps1 start" -ForegroundColor (Get-MessageColour muted)
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "       '$DistroName' is running again" -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$($Distro.BasePath)" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Disk file        : " -NoNewline; Write-Host "$(Format-Size (Get-VhdxSize $Distro.BasePath))" -ForegroundColor (Get-MessageColour info)
Write-Host ""
Write-Host ""
