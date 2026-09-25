[CmdletBinding()]
param ()

# No parameter on purpose, like everywhere in this family: the instance comes
# from a list, and so does the pack.
#
# The pack's own remove.sh runs first - the copy that lives INSIDE the instance,
# not the one in this checkout: what has to come out is what the code that
# installed it put in, and that code travelled with the pack. Then the folder
# goes, and the gmake menu loses the commands with it.

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

# Run a command in the instance. Its output is streamed - a pack's remove.sh
# may ask for a password - so the exit code cannot be the return value: a
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

# Which packs an instance carries, read from the instance itself. Not from
# packs\ in this checkout: a pack installed by an older copy of the repository,
# or one this repository no longer carries, is still removable - its remove.sh
# travelled with it.
#
# Wrap the call in @(): PowerShell unrolls a one-element list into its element,
# and the caller then holds a string - where [0] is its first LETTER, not the
# pack. Cost of finding out the other way: a menu that offers 'g', and a
# deletion aimed at a folder of that name.
function Get-InstalledPacks {
    param([string]$DistroName, [string]$PacksDirectory)
    return Get-InInstanceOutput -DistroName $DistroName -Command @("ls", "-1", $PacksDirectory)
}

# 1. Which instance the pack comes out of
$Distro = Select-Distro
$DistroName = $Distro.Name

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

# 2. Which pack
$Installed = @(Get-InstalledPacks -DistroName $DistroName -PacksDirectory $PacksDirectory)
if ($Installed.Count -eq 0) {
    Write-Host ""
    Write-Host "[OK] '$DistroName' carries no pack - there is nothing to remove." -ForegroundColor Green
    exit 0
}

$PackName = Select-FromList -Title "Packs installed in '$DistroName':" -Items $Installed

if (-not $PackName) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

$Target = "$PacksDirectory/$PackName"

# 3. What is about to happen, and only then the question. A pack without a
# remove.sh is one installed before packs had one: its folder can leave, but
# nothing of it will be undone on the system side, and that is said rather than
# discovered afterwards.
$Code = 0
Invoke-InInstance -DistroName $DistroName -Command @("test", "-f", "$Target/remove.sh") -ExitCode ([ref]$Code) -Quiet
$HasRemove = ($Code -eq 0)

Write-Host ""
if ($HasRemove) {
    Write-Host "==> Removing '$PackName' from '$DistroName'..." -ForegroundColor Cyan
    Write-Host "    Its own remove.sh runs first - what it installed leaves the system." -ForegroundColor DarkGray
    Write-Host "    Then its folder leaves, and the gmake menu loses its commands." -ForegroundColor DarkGray
    $Confirm = [string](Read-Host "Remove '$PackName'? [y/N]")
} else {
    Write-Host "==> '$PackName' carries no remove.sh: it was installed before packs had one." -ForegroundColor Yellow
    Write-Host "    Nothing will be undone on the system side - only the pack's files leave." -ForegroundColor Yellow
    Write-Host "    To take the tool itself out, open a shell in '$DistroName' and remove it by hand." -ForegroundColor Yellow
    $Confirm = [string](Read-Host "Delete the pack's files anyway? [y/N]")
}

if ($Confirm -notmatch "^[yY]") {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

# 4. What the pack does to leave, run from inside its own folder. Streamed,
# like the install: it may ask for a password.
if ($HasRemove) {
    Invoke-InInstance -DistroName $DistroName -Command @("bash", "remove.sh") -WorkingDirectory $Target -ExitCode ([ref]$Code)
    $RemoveCode = $Code

    # The folder stays when the script failed: the pack is still half in place,
    # and its files are what a second attempt needs.
    if ($RemoveCode -ne 0) {
        Write-Host ""
        Write-Host "[FAIL] The pack could not remove itself (exit code $RemoveCode)." -ForegroundColor Red
        Write-Host "       Nothing was deleted: '$PackName' is still installed in '$DistroName'." -ForegroundColor Yellow
        exit $RemoveCode
    }
}

# 5. The folder, once the self-removal is behind us
Invoke-InInstance -DistroName $DistroName -Command @("rm", "-rf", $Target) -ExitCode ([ref]$Code) -Quiet
if ($Code -ne 0) {
    Write-Host ""
    Write-Host "[FAIL] The pack's folder could not be deleted (exit code $Code)." -ForegroundColor Red
    Write-Host "       '$PackName' is out of the gmake menu, but its files are still in the instance." -ForegroundColor Yellow
    exit $Code
}

# 6. What the pack left on the system side. Its remove.sh took back what it had
# named; what stays is what arrived as a DEPENDENCY - nobody's to name, and
# heavy: the vision pack leaves 203 packages and 462 MB behind. apt knows which
# of them nothing installed depends on any more, but it will not touch them
# unless asked, and it cannot see a program living outside its own graph (a
# venv, a tool under /usr/local). scripts\cleanup_orphans.sh asks both
# questions and only then removes - the script travels into the instance the
# same way a pack does, because a bash script handed over as text loses its
# quotes on the way through wsl.exe.
$Cleanup = Join-Path $PSScriptRoot "cleanup_orphans.sh"
$CleanupCode = 0
if (Test-Path $Cleanup) {
    $RemoteScript = "/tmp/cleanup_orphans.sh"
    Invoke-InInstance -DistroName $DistroName -Command @("cp", "cleanup_orphans.sh", $RemoteScript) `
        -WorkingDirectory $PSScriptRoot -ExitCode ([ref]$Code) -Quiet

    if ($Code -eq 0) {
        Write-Host ""
        Write-Host "==> Taking back what '$PackName' left on the system side..." -ForegroundColor Cyan
        Write-Host "    Its remove.sh named what it installed; what remains is what came in" -ForegroundColor DarkGray
        Write-Host "    as a dependency. Nothing goes that apt - or a program outside apt -" -ForegroundColor DarkGray
        Write-Host "    still needs." -ForegroundColor DarkGray
        Invoke-InInstance -DistroName $DistroName -Command @("bash", $RemoteScript) -ExitCode ([ref]$CleanupCode)
        Invoke-InInstance -DistroName $DistroName -Command @("rm", "-f", $RemoteScript) -ExitCode ([ref]$Code) -Quiet
        if ($CleanupCode -ne 0) {
            # The pack is out either way; this is the tidy-up, not the removal.
            Write-Host ""
            Write-Host "[WARN] The cleanup stopped early (exit code $CleanupCode)." -ForegroundColor Yellow
            Write-Host "       '$PackName' is gone, but some of its dependencies may remain." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "==> '$PackName' is gone from '$DistroName'." -ForegroundColor Green
Write-Host "    Open a shell in it: the gmake menu no longer offers its commands." -ForegroundColor DarkGray
exit 0
