[CmdletBinding()]
param (
    # No default on purpose: naming the instance to copy is the first act.
    [Parameter(Mandatory = $true)]
    [string]$SourceDistro,

    # The copy's name. Must be free: this script never unregisters anything.
    [Parameter(Mandatory = $true)]
    [string]$NewDistroName
)

$ErrorActionPreference = "Stop"

# One working folder, no guessing: the copy is installed in <Root>\<name>,
# the same rule build.ps1's default -InstallPath follows.
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

# 0. The new name has to look like a name, and be free
if ($NewDistroName -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
    Write-Host ""
    Write-Host "[ABORT] '$NewDistroName' is not usable as an instance name" -ForegroundColor Red
    Write-Host "        (letters, digits, '.', '_' and '-' only)." -ForegroundColor Yellow
    Write-Host "        Nothing was modified." -ForegroundColor DarkGray
    exit 1
}

$AllDistros = Get-Distros

$Source = $AllDistros | Where-Object { $_.Name -eq $SourceDistro } | Select-Object -First 1
if (-not $Source) {
    Write-Host ""
    Write-Host "[ABORT] No registered distro named '$SourceDistro'." -ForegroundColor Red
    Write-Host "        Nothing was modified." -ForegroundColor DarkGray
    exit 1
}

# The copy must not land on a name that exists: this script never unregisters
# anything, so a name already taken is a dead end, not something to resolve.
if ($AllDistros | Where-Object { $_.Name -eq $NewDistroName }) {
    Write-Host ""
    Write-Host "[ABORT] An instance named '$NewDistroName' already exists." -ForegroundColor Red
    Write-Host "        Pick another -NewDistroName." -ForegroundColor Yellow
    Write-Host "        Nothing was modified." -ForegroundColor DarkGray
    exit 1
}

# The export stops the source: WSL terminates it to read a consistent disk,
# and whatever a running program has not written yet is gone. Ask rather than
# surprise - only the user knows what is open in there.
$StoppedByUs = $false
if ((Get-DistroNames -Running) -contains $SourceDistro) {
    Write-Host ""
    Write-Host "  '$SourceDistro' is running, and this needs it stopped." -ForegroundColor Yellow
    Write-Host "  Save what you have open in there: stopping it loses anything unsaved." -ForegroundColor Yellow
    $StopIt = [string](Read-Host "Stop it now? [Y/n]")
    if ($StopIt -match "^[nN]") {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
        exit 0
    }
    Invoke-External { wsl.exe --terminate $SourceDistro } "Could not stop '$SourceDistro'."
    Write-Host "  Stopped." -ForegroundColor DarkGray
    $StoppedByUs = $true
}

# 1. Install folder: <Root>\<name>, always. A name already taken has been
# refused above, so this folder cannot be another instance's.
$FullDestination = [System.IO.Path]::GetFullPath((Join-Path $Root $NewDistroName))

# 2. What it costs: the copy is made by reading the instance into an archive
# and unpacking that archive into the new folder. Both exist at the same time.
# The archive is compressed and holds only used data, so it is smaller than
# the disk - but twice the disk is what the peak can reach, and that is the
# number checked here.
#
# The archive route, rather than a raw disk copy (`--format vhd`): measured on
# WSL 2.9.11, a vhd export is refused with ERROR_SHARING_VIOLATION while the
# WSL virtual machine is up - `wsl --terminate` does not release it, only a
# full `wsl --shutdown` does, and that stops every other instance on the
# machine. The copy pays the compression instead.
$VhdxPath = Join-Path $Source.BasePath "ext4.vhdx"
$DiskBytes = if (Test-Path $VhdxPath) { (Get-Item $VhdxPath).Length } else { 0 }
$NeededBytes = 2 * $DiskBytes
$TempArchive = Join-Path $Root "$NewDistroName-export.tar.gz"

$DriveLetter = (Split-Path -Qualifier $FullDestination).TrimEnd(':')
$FreeBytes = (Get-PSDrive -Name $DriveLetter).Free

Write-Host ""
Write-Host "==> Duplicating '$SourceDistro' into '$NewDistroName'" -ForegroundColor Cyan
Write-Host "  * Source disk      : $(Format-Size $DiskBytes)" -ForegroundColor DarkGray
Write-Host "  * Needed on $DriveLetter`:      : $(Format-Size $NeededBytes) (archive + copy at peak)" -ForegroundColor DarkGray
Write-Host "  * Free on $DriveLetter`:        : $(Format-Size $FreeBytes)" -ForegroundColor DarkGray
Write-Host "  * Install folder   : $FullDestination" -ForegroundColor DarkGray

if ($FreeBytes -lt $NeededBytes) {
    Write-Host ""
    Write-Host "[ABORT] Not enough room on $DriveLetter`:." -ForegroundColor Red
    Write-Host "        Needed: $(Format-Size $NeededBytes) - free: $(Format-Size $FreeBytes)." -ForegroundColor Yellow
    Write-Host "        Free some space, or point -Destination at another drive." -ForegroundColor Yellow
    Write-Host "        Nothing was modified." -ForegroundColor DarkGray
    exit 1
}

$DestinationDir = Split-Path -Path $FullDestination -Parent
if (-not (Test-Path -Path $DestinationDir)) {
    New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
}

# 3. Copy: the source is only read. The temporary image is removed in all
# cases - it is worth twice the instance's disk on a drive that has just been
# checked for room, and leaving it behind would eat that room for nothing.
try {
    Write-Host "==> 1. Reading the source (the source itself is not modified)..." -ForegroundColor Cyan
    Invoke-External { wsl.exe --export $SourceDistro $TempArchive --format tar.gz } "The export failed."

    Write-Host "==> 2. Registering '$NewDistroName' from it..." -ForegroundColor Cyan
    Invoke-External { wsl.exe --import $NewDistroName $FullDestination $TempArchive --version $($Source.Version) } "The import failed."
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        The source was not modified." -ForegroundColor DarkGray
    if ($_.Exception.Message -like "*import*") {
        Write-Host "        A half-registered '$NewDistroName' may be left behind:" -ForegroundColor Yellow
        Write-Host "        remove it with .\unregister.ps1 -DistroName $NewDistroName" -ForegroundColor Yellow
    }
    exit 1
} finally {
    if (Test-Path -Path $TempArchive) {
        Remove-Item -Path $TempArchive -Force -ErrorAction SilentlyContinue
    }
}

$CopyVhdx = Join-Path $FullDestination "ext4.vhdx"
$CopyBytes = if (Test-Path $CopyVhdx) { (Get-Item $CopyVhdx).Length } else { 0 }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "       '$NewDistroName' is a copy of '$SourceDistro'" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$FullDestination" -ForegroundColor Cyan
Write-Host "  * Copy on disk     : " -NoNewline; Write-Host "$(Format-Size $CopyBytes)" -ForegroundColor Cyan
Write-Host "  * WSL version      : " -NoNewline; Write-Host "$($Source.Version)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Two things the copy does not inherit:" -ForegroundColor Yellow
Write-Host "    - Windows Terminal: it gets a profile of its own (restart Terminal to" -ForegroundColor DarkGray
Write-Host "      see it). The template's icon, font and colour scheme belong to the" -ForegroundColor DarkGray
Write-Host "      build, and are not copied." -ForegroundColor DarkGray
Write-Host "    - Docker Desktop: add the instance in Settings > Resources > WSL" -ForegroundColor DarkGray
Write-Host "      integration if you need the docker command inside the copy." -ForegroundColor DarkGray
Write-Host ""

# The source was running when this started: leave it the way it was found.
# `--exec` runs a command and returns, so it comes back up without this script
# opening a shell in it.
if ($StoppedByUs) {
    try {
        Invoke-External { wsl.exe -d $SourceDistro --exec /bin/true } "Could not restart '$SourceDistro'."
        Write-Host "'$SourceDistro' is running again." -ForegroundColor Green
    } catch {
        Write-Host "Could not restart '$SourceDistro' - start it with: wsl -d $SourceDistro" -ForegroundColor Yellow
    }
    Write-Host ""
}
