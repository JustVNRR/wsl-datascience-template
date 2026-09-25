[CmdletBinding()]
param ()

# No parameter on purpose: the instance comes from the list, like everywhere
# else in this family. This is the one command that lists instances which are
# NOT ours yet - and it only reads the machine, never a distro.

$ErrorActionPreference = "Stop"

# What the whole family shares: how to tell one of our instances from any other
# registered one. Here it is what the whole command is about.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

# 1. Who can be adopted: every registered instance that does not carry the
# marker. Not just any of them - a distribution that was created outside this
# repository is exactly what this list is for.
$All = @(Get-Distros | Sort-Object Name)
if ($All.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No WSL instance is registered on this machine." -ForegroundColor Red
    Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor Yellow
    exit 1
}

$Eligible = @($All | Where-Object { -not (Test-TemplateInstance -Folder $_.BasePath) })

if ($Eligible.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] Every registered instance is already one of this template's." -ForegroundColor Red
    Write-Host "        Nothing to adopt." -ForegroundColor Yellow
    exit 1
}

# The folder is shown on every line, and it is the point of the list: it is what
# tells an instance built here from Docker Desktop's or a colleague's. The
# running state is left out - adopting one changes nothing about it.
Write-Host ""
Write-Host "Registered instances that are not this template's:" -ForegroundColor Cyan
for ($Index = 0; $Index -lt $Eligible.Count; $Index++) {
    $Entry = $Eligible[$Index]
    Write-Host ("  {0,2}.  {1,-24} {2,10}  {3}" -f ($Index + 1), $Entry.Name,
        (Format-Size (Get-VhdxSize $Entry.BasePath)), $Entry.BasePath)
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

# 2. The marker goes into the instance's folder, next to its disk. A marked
# instance whose folder is gone would be marked nowhere, and the report below
# would be a lie - so this is checked rather than assumed.
if (-not (Test-Path $Distro.BasePath)) {
    Write-Host ""
    Write-Host "[ABORT] The folder WSL records for '$DistroName' is not there:" -ForegroundColor Red
    Write-Host "        $($Distro.BasePath)" -ForegroundColor Yellow
    Write-Host "        Nothing was modified." -ForegroundColor DarkGray
    exit 1
}

Write-Host ""
Write-Host "==> Marking '$DistroName' as one of this template's..." -ForegroundColor Cyan
New-InstanceMarker -Folder $Distro.BasePath -By "adopt"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "       '$DistroName' is now one of ours" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$($Distro.BasePath)" -ForegroundColor Cyan
Write-Host "  * Marker           : " -NoNewline; Write-Host "$MarkerName" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Every command lists it from now on -  .\wsl.ps1 list  shows them all." -ForegroundColor DarkGray
Write-Host "  Nothing else was touched: nothing was written inside the instance," -ForegroundColor DarkGray
Write-Host "  and its Windows Terminal profile is unchanged." -ForegroundColor DarkGray
Write-Host ""
