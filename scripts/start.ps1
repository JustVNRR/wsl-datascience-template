[CmdletBinding()]
param ()

# No parameter on purpose: the instance comes from a list - the ones that are
# stopped - never from the command line. Typing a name by heart is a name you
# can get wrong.

$ErrorActionPreference = "Stop"

# What the whole family shares: how to tell one of our instances from any other
# registered one.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

# 1. Who can be started: our instances that are stopped, and only those - one
# already running has nothing to do here, and offering it would be a choice
# with no effect. Sorted by name, like every list in this family: a menu whose
# numbers move is a menu you cannot trust twice.
$All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.BasePath } | Sort-Object Name)
if ($All.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor Red
    Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor Yellow
    exit 1
}

$Running = Get-DistroNames -Running
$Eligible = @($All | Where-Object { $Running -notcontains $_.Name })

if ($Eligible.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] Every registered instance is already running." -ForegroundColor Red
    Write-Host "        Nothing to start." -ForegroundColor Yellow
    exit 1
}

$Distro = Select-FromList -Title "Stopped instances - the ones that can be started:" -Items $Eligible -Label {
    param($Entry)
    "{0,-30} {1,10}" -f $Entry.Name, (Format-Size (Get-VhdxSize $Entry.BasePath))
}

if (-not $Distro) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

$DistroName = $Distro.Name

# 2. Start it. `--exec` runs a command and returns, so the instance comes back
# up without this script opening a shell in it.
Write-Host ""
Write-Host "==> Starting '$DistroName'..." -ForegroundColor Cyan
try {
    Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        '$DistroName' is not running." -ForegroundColor DarkGray
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "       '$DistroName' is running" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$($Distro.BasePath)" -ForegroundColor Cyan
Write-Host "  * Disk file        : " -NoNewline; Write-Host "$(Format-Size (Get-VhdxSize $Distro.BasePath))" -ForegroundColor Cyan
Write-Host ""
