[CmdletBinding()]
param ()

# No parameter on purpose: the instance comes from a list, and the pack comes
# from a list too - the ones this repository carries and that instance does not
# have yet. Typing either by heart is a name you can get wrong.
#
# What it does, in order: which instance, which pack, then the pack's folder is
# copied into the instance and its install script runs there, in front of you.
# That script may ask for your password - the packages belong to root - and the
# prompt does travel through wsl.exe: nothing is carried around, and no sudoers
# rule is written for it.

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

# Where the packs live in this checkout. The folder is the registry: a
# directory under packs\ carrying a pack.conf is a pack, and nothing else in
# the repository lists them - the same rule the gmake Makefile follows.
$PacksRoot = Join-Path (Split-Path $PSScriptRoot -Parent) "packs"

# ---------------------------------------------------------------------------
# RUNNING THINGS IN AN INSTANCE
# ---------------------------------------------------------------------------
# Commands are passed one argument at a time and run without a shell: the only
# string that ever travels through wsl.exe is a plain path. A bash script
# handed over as text is what breaks quietly - the quotes do not survive the
# round trip, and a command split in the wrong place fails in a way that looks
# like the instance's fault.
#
# stderr is non-terminating for the duration of these calls: under
# $ErrorActionPreference = "Stop" a redirection turns it into a TERMINATING
# error, and WSL itself writes there (it warns about the proxy configuration,
# for instance). The exit code is what says whether the command worked - the
# same guard build.ps1 uses around `docker info` and `wsl --unregister`.

# Run a command in the instance. Its output is streamed - an install takes
# minutes and asks questions - so the exit code cannot be the return value: a
# `return $code` would put the output in the caller's variable and the code in
# the console. It comes back through a [ref] instead.
function Invoke-InInstance {
    param(
        [string]$DistroName,
        [string[]]$Command,
        [string]$WorkingDirectory,
        [ref]$ExitCode,
        [switch]$Quiet
    )

    $WslArgs = @("-d", $DistroName)
    if ($WorkingDirectory) { $WslArgs += @("--cd", $WorkingDirectory) }
    $WslArgs += @("--") + $Command

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    if ($Quiet) {
        & wsl.exe @WslArgs *> $null
    } else {
        & wsl.exe @WslArgs
    }
    $ExitCode.Value = $LASTEXITCODE
    $ErrorActionPreference = $PreviousEAP
}

# Run a command in the instance and read what it printed, one line per entry.
function Get-InInstanceOutput {
    param([string]$DistroName, [string[]]$Command)

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $Output = & wsl.exe -d $DistroName -- @Command 2>$null
    $ErrorActionPreference = $PreviousEAP

    return @($Output | ForEach-Object { ($_ -replace "`0", "").Trim() } | Where-Object { $_ })
}

# The packs this checkout carries. A folder under packs\ without a pack.conf is
# not a pack: it is skipped rather than offered, because nothing could install
# it - that file is where the name and the description are read from.
function Get-AvailablePacks {
    $Found = @()
    if (-not (Test-Path $PacksRoot)) { return @() }
    foreach ($Folder in (Get-ChildItem -Path $PacksRoot -Directory | Sort-Object Name)) {
        $Conf = Join-Path $Folder.FullName "pack.conf"
        if (-not (Test-Path $Conf)) { continue }

        $Description = ""
        foreach ($Line in (Get-Content -Path $Conf -Encoding UTF8)) {
            if ($Line -match '^\s*PACK_DESCRIPTION\s*:=\s*(.+?)\s*$') { $Description = $Matches[1] }
        }

        $Found += [PSCustomObject]@{
            Name        = $Folder.Name
            Path        = $Folder.FullName
            Description = $Description
        }
    }
    return @($Found)
}

# Which packs an instance already has. The folder IS the state: the gmake
# Makefile reads ~/.config/packs/*/ to decide what to load, so a folder that is
# there is an installed pack, and one that is not is not.
#
# Wrap the call in @(): PowerShell unrolls a one-element list into its element,
# and the caller then holds a string - where [0] is its first LETTER, not the
# pack. Cost of finding out the other way: a menu that offers 'g', and a
# deletion aimed at a folder of that name.
function Get-InstalledPacks {
    param([string]$DistroName, [string]$PacksDirectory)
    return Get-InInstanceOutput -DistroName $DistroName -Command @("ls", "-1", $PacksDirectory)
}

# 1. Which instance the pack goes into
$Distro = Select-Distro
$DistroName = $Distro.Name

# It may be stopped: the copy and the install happen inside it, so it has to be
# up. WSL starts it on the way in and this call is what waits for it.
Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."

# Where its user's things live. Asked, not guessed: the home path belongs to the
# instance, and `~` only expands in a shell - which is what the calls below
# avoid on purpose.
$InstanceHome = (Get-InInstanceOutput -DistroName $DistroName -Command @("printenv", "HOME") | Select-Object -First 1)
if (-not $InstanceHome) {
    Write-Host ""
    Write-Host "[ABORT] '$DistroName' did not say where its user's home is." -ForegroundColor Red
    exit 1
}
$PacksDirectory = "$InstanceHome/.config/packs"

# 2. Which pack - the ones this repository carries and that instance lacks
$Available = @(Get-AvailablePacks)
if ($Available.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No pack found in $PacksRoot." -ForegroundColor Red
    Write-Host "        A pack is a folder there carrying a pack.conf." -ForegroundColor Yellow
    exit 1
}

$Installed = @(Get-InstalledPacks -DistroName $DistroName -PacksDirectory $PacksDirectory)
$Candidates = @($Available | Where-Object { $Installed -notcontains $_.Name })

if ($Candidates.Count -eq 0) {
    Write-Host ""
    Write-Host "[OK] '$DistroName' already has every pack this repository carries." -ForegroundColor Green
    exit 0
}

# Said before the list rather than after it: with the arrows the rows are
# drawn in place, and anything printed under them gets painted over.
if ($Installed.Count -gt 0) {
    Write-Host ""
    Write-Host ("       Already in '$DistroName': {0}" -f ($Installed -join ", ")) -ForegroundColor DarkGray
}

$Pack = Select-FromList -Title "Packs available for '$DistroName':" -Items $Candidates -Label {
    param($Entry)
    "{0,-12} {1}" -f $Entry.Name, $Entry.Description
}

if (-not $Pack) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

$PackName = $Pack.Name
$Target = "$PacksDirectory/$PackName"

# 3. The pack's folder, copied into the instance: the same files the image used
# to carry. It is copied from inside - the pack's own folder becomes the working
# directory, which wsl.exe knows how to do with a Windows path (`--cd`), and `.`
# is then all there is to name. No path is translated here on purpose: the
# obvious candidate is `wslpath`, which the instance does not carry at all (the
# Ubuntu base image has no wslu, and nothing installs it).
Write-Host ""
Write-Host "==> Installing '$PackName' in '$DistroName'..." -ForegroundColor Cyan
Write-Host "    Your password may be asked: the packages belong to root." -ForegroundColor DarkGray

$Code = 0
Invoke-InInstance -DistroName $DistroName -Command @("mkdir", "-p", $Target) -ExitCode ([ref]$Code) -Quiet
if ($Code -ne 0) {
    Write-Host "[ABORT] Could not create $Target in '$DistroName' (exit code $Code)." -ForegroundColor Red
    exit $Code
}

Invoke-InInstance -DistroName $DistroName -Command @("cp", "-r", ".", "$Target/") -WorkingDirectory $Pack.Path -ExitCode ([ref]$Code)
if ($Code -ne 0) {
    Write-Host "[ABORT] Could not copy the pack's files into '$DistroName' (exit code $Code)." -ForegroundColor Red
    Write-Host "        The message above is the instance's own answer." -ForegroundColor Yellow
    exit $Code
}

# 4. What the pack does to install itself, run from inside its own folder. Its
# output is streamed, not captured: it is what tells the user how far along it
# is, and it may ask for a password.
Invoke-InInstance -DistroName $DistroName -Command @("bash", "install.sh") -WorkingDirectory $Target -ExitCode ([ref]$Code)
$InstallCode = $Code

# A half-installed pack is worse than none: the Makefile loads whatever folder
# is there, so the menu would offer commands whose tool was never installed.
# The folder goes back out, and only it - what the install already wrote to the
# system stays, and running this again picks up where it stopped.
if ($InstallCode -ne 0) {
    Write-Host ""
    Write-Host "[FAIL] The installation did not complete (exit code $InstallCode)." -ForegroundColor Red
    Invoke-InInstance -DistroName $DistroName -Command @("rm", "-rf", $Target) -ExitCode ([ref]$Code) -Quiet
    Write-Host "       The pack's files were removed: nothing of it stays in the instance." -ForegroundColor Yellow
    Write-Host "       Whatever the install had already put in place is still there - run this again to finish." -ForegroundColor Yellow
    exit $InstallCode
}

Write-Host ""
Write-Host "==> '$PackName' is installed in '$DistroName'." -ForegroundColor Green
Write-Host "    Open a shell in it to use it:  .\wsl.ps1 shell" -ForegroundColor DarkGray
# The pack's samples travelled with its folder, but nothing has merged them into
# the user's own .env files - those are theirs, and no install writes into them.
# Said here, once, because it is the one step an install leaves over.
Write-Host "    Then, in there:  gmake env_global_enable   (adds the pack's variables)" -ForegroundColor DarkGray
exit 0
