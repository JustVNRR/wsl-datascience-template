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
    Write-Host "        Already have one? Make it ours with  .\wsl.ps1 adopt" -ForegroundColor Yellow
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

Write-Host ""
Write-Host "Stopped instances - the ones that can be started:" -ForegroundColor Cyan
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
