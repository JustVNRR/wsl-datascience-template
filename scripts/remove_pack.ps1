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

# What an instance carries, and the moves that take a pack out, live in
# scripts\packs.ps1, loaded by instance.ps1 above. This file is the flow: which
# instance, which pack, what it says on the way, and the one question asked
# before anything leaves.

# 1. Which instance the pack comes out of
$Distro = Select-Distro
$DistroName = $Distro.Name

Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."

# Where its user's things live, asked of the instance itself.
$InstanceHome = Get-InstanceHome -DistroName $DistroName
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

$Target = Get-PackFolder -PacksDirectory $PacksDirectory -Name $PackName

# 3. What is about to happen, and only then the question. A pack without a
# remove.sh is one installed before packs had one: its folder can leave, but
# nothing of it will be undone on the system side, and that is said rather than
# discovered afterwards.
$Code = 0
$HasRemove = Test-PackScript -DistroName $DistroName -Target $Target -Script "remove.sh" -ExitCode ([ref]$Code)

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
    Invoke-PackScript -DistroName $DistroName -Target $Target -Script "remove.sh" -ExitCode ([ref]$Code)
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
Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode ([ref]$Code)
if ($Code -ne 0) {
    Write-Host ""
    Write-Host "[FAIL] The pack's folder could not be deleted (exit code $Code)." -ForegroundColor Red
    Write-Host "       '$PackName' is out of the gmake menu, but its files are still in the instance." -ForegroundColor Yellow
    exit $Code
}

# 6. What the pack left on the system side: the dependencies its remove.sh never
# named. scripts\cleanup_orphans.sh asks apt and ldd before taking anything, and
# the command says what happened either way.
Write-Host ""
Write-Host "==> Taking back what '$PackName' left on the system side..." -ForegroundColor Cyan
Write-Host "    Its remove.sh named what it installed; what remains is what came in" -ForegroundColor DarkGray
Write-Host "    as a dependency. Nothing goes that apt - or a program outside apt -" -ForegroundColor DarkGray
Write-Host "    still needs." -ForegroundColor DarkGray

$CleanupCode = 0
if (-not (Invoke-PackOrphanCleanup -DistroName $DistroName -ExitCode ([ref]$CleanupCode))) {
    # The pack is out either way; this is the tidy-up, not the removal.
    Write-Host ""
    Write-Host "[WARN] The cleanup stopped early (exit code $CleanupCode)." -ForegroundColor Yellow
    Write-Host "       '$PackName' is gone, but some of its dependencies may remain." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> '$PackName' is gone from '$DistroName'." -ForegroundColor Green
Write-Host "    Open a shell in it: the gmake menu no longer offers its commands." -ForegroundColor DarkGray
exit 0
