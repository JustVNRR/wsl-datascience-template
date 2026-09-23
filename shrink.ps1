[CmdletBinding()]
param (
    # No default on purpose: naming the instance is the first act.
    [Parameter(Mandatory = $true)]
    [string]$DistroName
)

$ErrorActionPreference = "Stop"

# One working folder, no guessing: an instance lives in <Root>\<name>, and
# every archive in <Root>\archives - the rule the other scripts follow too.
$Root = if (Test-Path "D:\") { "D:\WSL" } else { "$env:USERPROFILE\WSL" }

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

# 1. The instance must exist
$Distro = Get-Distro $DistroName
if (-not $Distro) {
    Write-Host ""
    Write-Host "[ABORT] No registered distro named '$DistroName'." -ForegroundColor Red
    Write-Host "        Nothing was modified." -ForegroundColor DarkGray
    exit 1
}

# Was it running when we arrived? Compacting works either way, but the archive
# does not, and whatever we stopped is started again at the end.
$WasRunning = (Get-DistroNames -Running) -contains $DistroName

$BeforeBytes = Get-VhdxSize $Distro.BasePath

Write-Host ""
Write-Host "==> Reclaiming space in '$DistroName'" -ForegroundColor Cyan
Write-Host "  * Disk file now    : $(Format-Size $BeforeBytes)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  This compacts the instance's virtual disk: the space its filesystem" -ForegroundColor DarkGray
Write-Host "  has freed over time comes back to Windows. Nothing inside is touched," -ForegroundColor DarkGray
Write-Host "  and it is the operation Windows ships without any warning - unlike the" -ForegroundColor DarkGray
Write-Host "  sparse flag, which it refuses by default as a corruption risk." -ForegroundColor DarkGray

# 2. A copy first, and the answer is yes by default: compacting rewrites the
# disk's metadata, which is exactly what a backup taken a minute before turns
# into a non-event.
$ArchiveScript = Join-Path $PSScriptRoot "archive.ps1"
Write-Host ""
$ArchiveFirst = [string](Read-Host "Archive it first? [Y/n]")
if ($ArchiveFirst -match "^[nN]") {
    Write-Host "  No archive - compacting on its own." -ForegroundColor DarkGray
} else {
    if (-not (Test-Path $ArchiveScript)) {
        Write-Host ""
        Write-Host "[ABORT] archive.ps1 is not next to this script - no archive, no operation." -ForegroundColor Red
        Write-Host "        Nothing was modified." -ForegroundColor DarkGray
        exit 1
    }
    # Leave: shrink decides what the instance does next, not the archive step.
    & $ArchiveScript -DistroName $DistroName -Name $DistroName -AfterExport Leave
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "[ABORT] The archive did not complete - nothing was compacted." -ForegroundColor Red
        Write-Host "        The instance is exactly as it was." -ForegroundColor DarkGray
        exit 1
    }
}

# 3. Compact. One command, in place: measured working on a running instance, and
# it refuses on its own if the disk cannot be compacted - there is nothing to
# prepare and nothing to undo.
Write-Host ""
Write-Host "==> Compacting the virtual disk..." -ForegroundColor Cyan
try {
    Invoke-External { wsl.exe --manage $DistroName --compact } "The compact failed."
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        The instance is untouched." -ForegroundColor DarkGray
    exit 1
}

$AfterBytes = Get-VhdxSize $Distro.BasePath
$FreedBytes = $BeforeBytes - $AfterBytes

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "       '$DistroName' compacted" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  * Disk file        : " -NoNewline
Write-Host "$(Format-Size $BeforeBytes) -> $(Format-Size $AfterBytes)" -ForegroundColor Cyan
if ($FreedBytes -gt 0) {
    Write-Host "  * Reclaimed        : " -NoNewline; Write-Host "$(Format-Size $FreedBytes)" -ForegroundColor Green
} else {
    Write-Host "  * Reclaimed        : " -NoNewline
    Write-Host "nothing - the disk held no space to give back" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "  The virtual disk's size does not change, only what it occupies on" -ForegroundColor DarkGray
Write-Host "  Windows. Nothing inside the instance was touched." -ForegroundColor DarkGray
Write-Host ""

# 4. It was running when we arrived: leave it the way it was found. `--exec`
# runs a command and returns, so it comes back up without a shell in it.
if ($WasRunning) {
    try {
        Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."
        Write-Host "'$DistroName' is running again." -ForegroundColor Green
    } catch {
        Write-Host "Could not start '$DistroName' - start it with: wsl -d $DistroName" -ForegroundColor Yellow
    }
    Write-Host ""
}
