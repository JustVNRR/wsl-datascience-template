[CmdletBinding()]
param ()

# No parameter on purpose: the instance comes from a list - the ones that are
# stopped - never from the command line. Typing a name by heart is a name you
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

# 1. Who can be started: the stopped ones, and only those. An instance that is
# already running has nothing to do here, and offering it would be a choice
# with no effect. Sorted by name, like every list in this family: a menu whose
# numbers move is a menu you cannot trust twice.
$All = @(Get-Distros | Sort-Object Name)
if ($All.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No WSL instance is registered on this machine." -ForegroundColor Red
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
