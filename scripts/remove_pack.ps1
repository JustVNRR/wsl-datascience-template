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

# 2. Which pack - the ones a user chooses. A pack marked invisible in its own
# pack.conf is not offered here: it arrived because another pack requires it,
# and it leaves with the last one that does. No guard on an empty $Available:
# a pack installed from another checkout is still a pack this command can take
# out, and it is not in this checkout's list at all.
$Available = @(Get-AvailablePacks)
$Installed = @(Get-InstalledPacks -DistroName $DistroName -PacksDirectory $PacksDirectory)
if ($Installed.Count -eq 0) {
    Write-Host ""
    Write-Host "[OK] '$DistroName' carries no pack - there is nothing to remove." -ForegroundColor Green
    exit 0
}

$Offered = @()
foreach ($Name in $Installed) {
    $Pack = @($Available | Where-Object { $_.Name -eq $Name })[0]
    if ($null -ne $Pack -and -not $Pack.Visible) { continue }
    $Offered += $Name
}
if ($Offered.Count -eq 0) {
    Write-Host ""
    Write-Host "[OK] '$DistroName' carries no pack you choose or remove by hand." -ForegroundColor Green
    exit 0
}

$PackName = Select-FromList -Title "Packs installed in '$DistroName':" -Items $Offered

if (-not $PackName) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

# What leaves with it: a pack nothing installed requires any more, so that the
# other packs do not stay on an instance with their base pulled out from under
# them. The chosen pack goes first - the other order would ask a remove.sh
# whether a neighbour still claims its packages while that neighbour is still
# there to say yes.
$ToRemove = @(Resolve-PackRemoval -Available $Available -Installed $Installed -Leaving @($PackName))
$Also = @($ToRemove | Where-Object { $_ -ne $PackName })

# 3. What is about to happen, and only then the question. A pack without a
# remove.sh is one installed before packs had one: its folder can leave, but
# nothing of it will be undone on the system side, and that is said rather than
# discovered afterwards.
$Code = 0
$Missing = @()
foreach ($Name in $ToRemove) {
    $Its = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Name
    if (-not (Test-PackScript -DistroName $DistroName -Target $Its -Script "remove.sh" -ExitCode ([ref]$Code))) {
        $Missing += $Name
    }
}

Write-Host ""
Write-Host "==> Removing from '$DistroName': $($ToRemove -join ', ')" -ForegroundColor Cyan
Write-Host "    Each pack's own remove.sh runs first - what it installed leaves the system." -ForegroundColor DarkGray
Write-Host "    Then its folder leaves, and the gmake menu loses its commands." -ForegroundColor DarkGray
foreach ($Name in $Also) {
    Write-Host "    '$Name' goes with '$PackName': nothing installed requires it any more." -ForegroundColor DarkGray
}
if ($Missing.Count -gt 0) {
    Write-Host "    No remove.sh in: $($Missing -join ', ') - installed before packs had one." -ForegroundColor Yellow
    Write-Host "    Nothing of it is undone on the system side: only its files leave." -ForegroundColor Yellow
    Write-Host "    To take its tool out by hand, open a shell in '$DistroName'." -ForegroundColor Yellow
}
$Confirm = [string](Read-Host "Remove $($ToRemove -join ', ')? [y/N]")

if ($Confirm -notmatch "^[yY]") {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

# 4. What each pack does to leave, run from inside its own folder. Streamed,
# like the install: it may ask for a password. Then its folder, once the
# self-removal is behind us.
foreach ($Name in $ToRemove) {
    $Target = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Name

    if ($Missing -notcontains $Name) {
        Write-Host ""
        Write-Host "==> Removing '$Name'..." -ForegroundColor Cyan
        Invoke-PackScript -DistroName $DistroName -Target $Target -Script "remove.sh" -ExitCode ([ref]$Code)
        $RemoveCode = $Code

        # The folder stays when the script failed: the pack is still half in
        # place, and its files are what a second attempt needs.
        if ($RemoveCode -ne 0) {
            Write-Host ""
            Write-Host "[FAIL] The pack could not remove itself (exit code $RemoveCode)." -ForegroundColor Red
            Write-Host "       Nothing was deleted: '$Name' is still installed in '$DistroName'." -ForegroundColor Yellow
            exit $RemoveCode
        }
    }

    Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode ([ref]$Code)
    if ($Code -ne 0) {
        Write-Host ""
        Write-Host "[FAIL] The pack's folder could not be deleted (exit code $Code)." -ForegroundColor Red
        Write-Host "       '$Name' is out of the gmake menu, but its files are still in the instance." -ForegroundColor Yellow
        exit $Code
    }
}

# 5. What the packs left on the system side: the dependencies their remove.sh
# never named. scripts\cleanup_orphans.sh asks apt and ldd before taking
# anything, and the command says what happened either way. Once, at the end -
# it is a question about the instance, not about a pack.
Write-Host ""
Write-Host "==> Taking back what the removed packs left on the system side..." -ForegroundColor Cyan
Write-Host "    Their remove.sh scripts named what they installed; what remains is what" -ForegroundColor DarkGray
Write-Host "    came in as a dependency. Nothing goes that apt - or a program outside" -ForegroundColor DarkGray
Write-Host "    apt - still needs." -ForegroundColor DarkGray

$CleanupCode = 0
if (-not (Invoke-PackOrphanCleanup -DistroName $DistroName -ExitCode ([ref]$CleanupCode))) {
    # The packs are out either way; this is the tidy-up, not the removal.
    Write-Host ""
    Write-Host "[WARN] The cleanup stopped early (exit code $CleanupCode)." -ForegroundColor Yellow
    Write-Host "       They are gone, but some of their dependencies may remain." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> Removed from '$DistroName': $($ToRemove -join ', ')." -ForegroundColor Green
Write-Host "    Open a shell in it: the gmake menu no longer offers their commands." -ForegroundColor DarkGray
exit 0
