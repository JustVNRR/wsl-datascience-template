[CmdletBinding()]
param ()

# No parameter on purpose: the instance comes from a list - the ones that are
# running - never from the command line. Typing a name by heart is a name you
# can get wrong.

$ErrorActionPreference = "Stop"

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

# 1. Who can be stopped: the ones running at this moment, and only those. An
# instance that is already stopped has nothing to do here. Sorted by name, like
# every list in this family: a menu whose numbers move is a menu you cannot
# trust twice.
$All = @(Get-Distros | Sort-Object Name)
if ($All.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No WSL instance is registered on this machine." -ForegroundColor Red
    Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor Yellow
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
