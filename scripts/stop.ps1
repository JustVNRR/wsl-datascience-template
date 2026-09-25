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
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

# 1. Who can be stopped: our instances running at this moment, and only those -
# one already stopped has nothing to do here. Sorted by name, like every list
# in this family: a menu whose numbers move is a menu you cannot trust twice.
$All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.BasePath } | Sort-Object Name)
if ($All.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor Red
    Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor Yellow
    Write-Host "        Already have one? Make it ours with  .\wsl.ps1 adopt" -ForegroundColor Yellow
    exit 1
}

$Running = Get-DistroNames -Running
$Eligible = @($All | Where-Object { $Running -contains $_.Name })

if ($Eligible.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No instance is running." -ForegroundColor Red
    Write-Host "        Nothing to stop." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Running instances - the ones that can be stopped:" -ForegroundColor Cyan
for ($Index = 0; $Index -lt $Eligible.Count; $Index++) {
    $Entry = $Eligible[$Index]
    Write-Host ("  {0,2}.  {1,-30} {2,10}" -f ($Index + 1), $Entry.Name,
        (Format-Size (Get-VhdxSize $Entry.BasePath)))
}
Write-Host "   0.  Cancel"

# The question comes back until the answer is one of the numbers - an empty
# answer cancels, so a run with no console can never loop forever.
$Distro = $null
while (-not $Distro) {
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
        if ($Number -ge 1 -and $Number -le $Eligible.Count) {
            $Distro = $Eligible[$Number - 1]
        }
    }
    if (-not $Distro) {
        Write-Host "  '$Answer' is not one of the numbers above." -ForegroundColor Yellow
    }
}

$DistroName = $Distro.Name

# 2. Stopping is what was asked for, but it is the one thing here that can
# lose work: what is open in there and not saved goes with it. The disk is not
# touched - only what is in memory. Asked once, default yes, because picking
# the instance in the list was already a deliberate act.
Write-Host ""
Write-Host "  '$DistroName' will be stopped." -ForegroundColor Yellow
Write-Host "  Whatever is open in there and not saved is lost; what is already" -ForegroundColor Yellow
Write-Host "  written on the disk stays exactly as it is." -ForegroundColor Yellow
$Confirm = [string](Read-Host "Stop it? [Y/n]")
if ($Confirm -match "^[nN]") {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "==> Stopping '$DistroName'..." -ForegroundColor Cyan
try {
    Invoke-External { wsl.exe --terminate $DistroName } "Could not stop '$DistroName'."
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        '$DistroName' may still be running." -ForegroundColor DarkGray
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "       '$DistroName' is stopped" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$($Distro.BasePath)" -ForegroundColor Cyan
Write-Host "  * Disk file        : " -NoNewline; Write-Host "$(Format-Size (Get-VhdxSize $Distro.BasePath))" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Nothing on the disk was touched: closing an instance only ends what" -ForegroundColor DarkGray
Write-Host "  was running. Start it again with  .\wsl.ps1 start" -ForegroundColor DarkGray
Write-Host ""
