[CmdletBinding()]
param (
)

# No parameter on purpose: the source comes from the list, never from the
# command line, and the copy's name is asked for.

$ErrorActionPreference = "Stop"

# One working folder, no guessing: the copy is installed in <Root>\<name>,
# the folder build.ps1 proposes when it asks where an instance should live.
$Root = if (Test-Path "D:\") { "D:\WSL" } else { "$env:USERPROFILE\WSL" }

# What the whole family shares: how to tell one of our instances from any other
# registered one, and what Windows knows about its look - captured off the
# source here, and re-applied to the copy after the import.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

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

# The choice every command in this family offers: the instances that exist,
# numbered, with what is worth knowing about each, and a way out. The question
# comes back until the answer is one of the numbers - an empty answer cancels,
# so a run with no console can never loop forever.
function Select-Distro {
    # Sorted by name: the registry order changes between runs, and a menu whose
    # numbers move is a menu you cannot trust twice. Filtered on the marker:
    # the machine holds other distributions - Docker Desktop's, a colleague's -
    # and none of them are ours to touch.
    $All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.BasePath } | Sort-Object Name)
    if ($All.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor Red
        Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor Yellow
        Write-Host "        Already have one? Make it ours with  .\wsl.ps1 adopt" -ForegroundColor Yellow
        exit 1
    }

    $Running = Get-DistroNames -Running

    Write-Host ""
    Write-Host "Instances registered on this machine:" -ForegroundColor Cyan
    for ($Index = 0; $Index -lt $All.Count; $Index++) {
        $Entry = $All[$Index]
        $State = if ($Running -contains $Entry.Name) { "running" } else { "stopped" }
        Write-Host ("  {0,2}.  {1,-30} {2,-8} {3,10}" -f ($Index + 1), $Entry.Name, $State,
            (Format-Size (Get-VhdxSize $Entry.BasePath)))
    }
    Write-Host "   0.  Cancel"

    while ($true) {
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
            if ($Number -ge 1 -and $Number -le $All.Count) {
                return $All[$Number - 1]
            }
        }
        Write-Host "  '$Answer' is not one of the numbers above." -ForegroundColor Yellow
    }
}

# 0. Which instance to copy
$AllDistros = Get-Distros
$Source = Select-Distro
$SourceDistro = $Source.Name

# Captured now, while the source's profile is still the one it was built with:
# a copy that comes out bare is not a copy.
$Look = Get-InstanceAppearance -Name $SourceDistro
$Look | Add-Member -NotePropertyName Docker -NotePropertyValue (Get-DockerState -Name $SourceDistro)

# 0-bis. The copy's name. Typed, because there is nothing to pick from - it
# does not exist yet. The question comes back until the name is usable.
while ($true) {
    $Answer = [string](Read-Host "Name of the copy")
    if ([string]::IsNullOrWhiteSpace($Answer)) {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was created." -ForegroundColor Green
        exit 0
    }
    if ($Answer.Trim() -match '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
        $NewDistroName = $Answer.Trim()
        break
    }
    Write-Host "  Letters, digits, '.', '_' and '-' only." -ForegroundColor Yellow
}

# The copy must not land on a name that exists: this script never unregisters
# anything, so a name already taken is a dead end, not something to resolve.
if ($AllDistros | Where-Object { $_.Name -eq $NewDistroName }) {
    Write-Host ""
    Write-Host "[ABORT] An instance named '$NewDistroName' already exists." -ForegroundColor Red
    Write-Host "        Pick another name." -ForegroundColor Yellow
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
    Write-Host "        Free some space, then run this again." -ForegroundColor Yellow
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
        Write-Host "        remove it with  .\wsl.ps1 unregister        (pick '$NewDistroName' in the list)" -ForegroundColor Yellow
    }
    exit 1
} finally {
    if (Test-Path -Path $TempArchive) {
        Remove-Item -Path $TempArchive -Force -ErrorAction SilentlyContinue
    }
}

$CopyVhdx = Join-Path $FullDestination "ext4.vhdx"
$CopyBytes = if (Test-Path $CopyVhdx) { (Get-Item $CopyVhdx).Length } else { 0 }

# Ours from here on, like the source it was copied from.
New-InstanceMarker -Folder $FullDestination -By "duplicate"

# The copy has its own profile now, and its own guid: the look is re-applied to
# that one, from the values captured off the source before the export - and so
# is Docker Desktop's knowledge of it, which is keyed by name.
Set-InstanceState -Name $NewDistroName -InstallPath $FullDestination -Appearance $Look

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "       '$NewDistroName' is a copy of '$SourceDistro'" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$FullDestination" -ForegroundColor Cyan
Write-Host "  * Copy on disk     : " -NoNewline; Write-Host "$(Format-Size $CopyBytes)" -ForegroundColor Cyan
Write-Host "  * WSL version      : " -NoNewline; Write-Host "$($Source.Version)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Windows Terminal: the copy gets a profile of its own, with the icon," -ForegroundColor DarkGray
Write-Host "  the font and the colours of the source. Restart Terminal to see it." -ForegroundColor DarkGray
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
