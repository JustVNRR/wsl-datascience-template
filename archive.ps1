[CmdletBinding()]
param (
    # Not part of the interface: run bare, this command lists the instances and
    # you pick one. The parameter exists because shrink.ps1 and unregister.ps1
    # call it with the instance already chosen.
    [string]$DistroName,

    [ValidateSet("tar", "tar.gz", "tar.xz")]
    [string]$Format = "tar.gz",

    # Skip the naming question and use this as the name. unregister.ps1 and
    # shrink.ps1 pass the instance's name: they are mid-operation, with nobody
    # to ask, and the name they want is obvious.
    [string]$Name,

    # What to do with the instance once the archive is written. "Ask" is the
    # default and puts the question to the user; unregister.ps1 passes "Leave"
    # because it is about to delete the instance anyway.
    [ValidateSet("Ask", "Start", "Delete", "Leave")]
    [string]$AfterExport = "Ask"
)

$ErrorActionPreference = "Stop"

# One working folder, no guessing: an instance lives in <Root>\<name>, and
# every archive in <Root>\archives. It is the same rule as build.ps1's default
# -InstallPath, so everything this repository manages sits under one folder.
$Root = if (Test-Path "D:\") { "D:\WSL" } else { "$env:USERPROFILE\WSL" }
$ArchiveFolder = Join-Path $Root "archives"

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

# The registry holds the instance's real folder and its WSL version (1 or 2)
function Get-Distro {
    param([string]$Name)
    foreach ($Key in Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss -ErrorAction SilentlyContinue) {
        $Props = Get-ItemProperty $Key.PSPath
        if ($Props.DistributionName -eq $Name) {
            return [PSCustomObject]@{
                Name     = $Name
                Version  = if ($Props.Version) { [int]$Props.Version } else { 2 }
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

# The choice every command in this family offers: the instances that exist,
# numbered, with what is worth knowing about each, and a way out. The question
# comes back until the answer is one of the numbers - an empty answer cancels,
# so a run with no console can never loop forever.
function Select-Distro {
    # Sorted by name: the registry order changes between runs, and a menu
    # whose numbers move is a menu you cannot trust twice.
    $All = Get-Distros | Sort-Object Name
    if ($All.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] No WSL instance is registered on this machine." -ForegroundColor Red
        Write-Host "        Build one with  .\build.ps1" -ForegroundColor Yellow
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

# 1. Which instance. Named on the command line, or picked from the list.
if ($DistroName) {
    $Distro = Get-Distro $DistroName
    if (-not $Distro) {
        Write-Host ""
        Write-Host "[ABORT] No registered distro named '$DistroName'." -ForegroundColor Red
        Write-Host "        Nothing was modified." -ForegroundColor DarkGray
        exit 1
    }
} else {
    $Distro = Select-Distro
    $DistroName = $Distro.Name
}

$VhdxPath = Join-Path $Distro.BasePath "ext4.vhdx"
$DiskBytes = if (Test-Path $VhdxPath) { (Get-Item $VhdxPath).Length } else { 0 }

# 2. The export stops the instance: WSL terminates it to read a consistent
# disk, and whatever a running program has not written yet is gone. Ask rather
# than surprise - only the user knows what is open in there.
$StoppedByUs = $false
if ((Get-DistroNames -Running) -contains $DistroName) {
    Write-Host ""
    Write-Host "  '$DistroName' is running, and this needs it stopped." -ForegroundColor Yellow
    Write-Host "  Save what you have open in there: stopping it loses anything unsaved." -ForegroundColor Yellow
    $StopIt = [string](Read-Host "Stop it now? [Y/n]")
    if ($StopIt -match "^[nN]") {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
        exit 0
    }
    Invoke-External { wsl.exe --terminate $DistroName } "Could not stop '$DistroName'."
    Write-Host "  Stopped." -ForegroundColor DarkGray
    $StoppedByUs = $true
}

# 3. The name. Not a timestamp: an archive is a copy you name, and a dated pile
# would only be one more thing to clean up. The instance's name is proposed,
# a name already taken gets the next free suffix, and the user can type
# another one - typing a name that exists is how an archive is replaced.
$Extension = ".$Format"
if (-not (Test-Path -Path $ArchiveFolder)) {
    New-Item -ItemType Directory -Path $ArchiveFolder -Force | Out-Null
}

$Proposal = "$DistroName$Extension"
$Suffix = 0
while (Test-Path (Join-Path $ArchiveFolder $Proposal)) {
    $Suffix++
    $Proposal = "$DistroName-$Suffix$Extension"
}

if ($Name) {
    $Chosen = $Name.Trim()
} else {
    $Existing = @(Get-ChildItem -Path $ArchiveFolder -File | Sort-Object Name)
    Write-Host ""
    if ($Existing.Count -eq 0) {
        Write-Host "No archive yet in $ArchiveFolder." -ForegroundColor DarkGray
    } else {
        Write-Host "Archives already in ${ArchiveFolder}:" -ForegroundColor Cyan
        foreach ($Entry in $Existing) {
            Write-Host ("  {0,-45} {1,10}  {2}" -f $Entry.Name, (Format-Size $Entry.Length),
                $Entry.LastWriteTime.ToString("yyyy-MM-dd HH:mm")) -ForegroundColor DarkGray
        }
    }
    Write-Host ""
    $Answer = [string](Read-Host "Name of the archive? [$Proposal]")
    $Chosen = if ([string]::IsNullOrWhiteSpace($Answer)) { $Proposal } else { $Answer.Trim() }
}

if ($Chosen -match '[\\/]') {
    Write-Host ""
    Write-Host "[ABORT] '$Chosen' is a path. Give a file name - it lands in:" -ForegroundColor Red
    Write-Host "        $ArchiveFolder" -ForegroundColor Yellow
    Write-Host "        Nothing was modified." -ForegroundColor DarkGray
    exit 1
}
if (-not $Chosen.EndsWith($Extension)) {
    $Chosen = "$Chosen$Extension"
}

$Destination = [System.IO.Path]::GetFullPath((Join-Path $ArchiveFolder $Chosen))

# The proposal above never lands on a taken name, so getting here means the
# name was typed - and typing a name that exists is how you replace an archive.
# Said out loud rather than done quietly.
if (Test-Path -Path $Destination) {
    Write-Host "  '$Chosen' exists: replacing it." -ForegroundColor Yellow
}

# 4. Say what it costs before it costs it. The archive only holds what the
# instance actually uses, so it is usually smaller than the virtual disk -
# but "usually" is not a guarantee, and a full drive stops the export.
$FreeBytes = (Get-PSDrive -Name (Split-Path -Qualifier $Destination).TrimEnd(':')).Free
Write-Host ""
Write-Host "==> Backing up '$DistroName'" -ForegroundColor Cyan
Write-Host "  * Instance disk    : $(Format-Size $DiskBytes)" -ForegroundColor DarkGray
Write-Host "  * Free on target   : $(Format-Size $FreeBytes)" -ForegroundColor DarkGray
Write-Host "  * Archive          : $Destination ($Format)" -ForegroundColor DarkGray

if ($DiskBytes -gt 0 -and $FreeBytes -lt $DiskBytes) {
    Write-Host "  * Note             : less free space than the disk's size." -ForegroundColor Yellow
    Write-Host "                       The archive is normally much smaller - it holds used" -ForegroundColor DarkGray
    Write-Host "                       data, not free blocks. If it does not fit, the export" -ForegroundColor DarkGray
    Write-Host "                       stops and leaves a partial file, which this script deletes." -ForegroundColor DarkGray
}

# 5. Export
$Started = Get-Date
try {
    Invoke-External { wsl.exe --export $DistroName $Destination --format $Format } "The export failed."
} catch {
    # A partial archive left on disk would look exactly like a backup later on.
    if (Test-Path -Path $Destination) {
        Remove-Item -Path $Destination -Force -ErrorAction SilentlyContinue
    }
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        The partial archive was removed. Nothing else was modified." -ForegroundColor DarkGray
    exit 1
}

$Archive = Get-Item -Path $Destination
$Elapsed = (Get-Date) - $Started

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "       Backup of '$DistroName' written" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  * Archive          : " -NoNewline; Write-Host "$($Archive.FullName)" -ForegroundColor Cyan
Write-Host "  * Size             : " -NoNewline; Write-Host "$(Format-Size $Archive.Length) (instance disk: $(Format-Size $DiskBytes))" -ForegroundColor Cyan
Write-Host "  * Time             : " -NoNewline; Write-Host "$([int]$Elapsed.TotalMinutes) min $($Elapsed.Seconds) s" -ForegroundColor Cyan
Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "To restore it as a new instance:" -ForegroundColor Yellow
Write-Host "  .\restore.ps1        (it lists the archives, this one included)" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# 6. What becomes of the instance now that its archive is on disk. All three
# answers are reasonable - the copy exists either way - and only the user
# knows which one they want. The default is the state it was found in.
if ($AfterExport -eq "Ask") {
    Write-Host "What should happen to '$DistroName' now?" -ForegroundColor Yellow
    Write-Host "  a. Start it"
    Write-Host "  b. Delete it (the archive stays)"
    Write-Host "  c. Leave it stopped"
    $DefaultAnswer = if ($StoppedByUs) { "a" } else { "c" }
    # [string]: Read-Host returns $null when its input is closed, and a $null
    # answer makes the test below return $null instead of a verdict - so the
    # default would never be applied and the line after would fail on it.
    $Answer = [string](Read-Host "Answer (a/b/c) [default: $DefaultAnswer]")
    if ($Answer -notmatch "^[aAbBcC]$") { $Answer = $DefaultAnswer }
    $AfterExport = switch ($Answer.ToLower()) { "a" { "Start" } "b" { "Delete" } "c" { "Leave" } }
    Write-Host ""
}

if ($AfterExport -eq "Start") {
    # `--exec` runs a command and returns: the instance comes back up without
    # this script opening a shell in it.
    try {
        Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."
        Write-Host "'$DistroName' is running." -ForegroundColor Green
    } catch {
        Write-Host "Could not start '$DistroName' - start it with: wsl -d $DistroName" -ForegroundColor Yellow
    }
    Write-Host ""
} elseif ($AfterExport -eq "Delete") {
    # The archive exists, so this is a decision and not an accident - but it
    # still goes through unregister.ps1, whose typed-name confirmation is what
    # this repository asks for before anything destroys an instance.
    $UnregisterScript = Join-Path $PSScriptRoot "unregister.ps1"
    if (Test-Path $UnregisterScript) {
        # unregister.ps1 takes no name: it lists and the user picks again.
        Write-Host "Pick '$DistroName' in the list below, and type its name to confirm." -ForegroundColor DarkGray
        & $UnregisterScript
        if ($LASTEXITCODE -eq 0) {
            Write-Host "The archive is the only copy of '$DistroName' left." -ForegroundColor DarkGray
        }
    } else {
        Write-Host "unregister.ps1 is not next to this script. To delete it, run:" -ForegroundColor Yellow
        Write-Host "  wsl --unregister $DistroName" -ForegroundColor White
    }
    Write-Host ""
} else {
    Write-Host "'$DistroName' is left stopped." -ForegroundColor DarkGray
    Write-Host ""
}
