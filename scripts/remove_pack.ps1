[CmdletBinding()]
param ()

# No parameter on purpose: the instance and the pack both come from lists.
#
# The pack's own remove.sh runs first - the copy INSIDE the instance, not the
# one in this checkout: what has to come out is what the code that installed it
# put in, and that code travelled with the pack. Then the folder goes, and the
# gmake menu loses the commands with it.

$ErrorActionPreference = "Stop"

# The family's shared half: the marker.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
    exit 1
}
. $InstanceLib

# The moves that take a pack out live in scripts\packs.ps1, loaded above. This
# file is the flow: which instance, which pack, and the one question asked
# before anything leaves.

# 1. Which instance the pack comes out of
$Distro = Select-Distro
$DistroName = $Distro.Name

Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."

# Where its user's things live, asked of the instance itself.
$InstanceHome = Get-InstanceHome -DistroName $DistroName
if (-not $InstanceHome) {
    Write-Host ""
    Write-Host "[ABORT] '$DistroName' did not say where its user's home is." -ForegroundColor (Get-MessageColour error)
    exit 1
}
$PacksDirectory = "$InstanceHome/.config/packs"

# 2. Which pack - the ones a user chooses. A pack marked invisible in its own
# pack.conf is not offered: it leaves with the last pack that requires it. No
# guard on an empty $Available: a pack installed from another checkout is still
# a pack this command can take out.
$Available = @(Get-AvailablePacks)
$Installed = @(Get-InstalledPacks -DistroName $DistroName -PacksDirectory $PacksDirectory)
if ($Installed.Count -eq 0) {
    Write-Host ""
    Write-Host "[OK] '$DistroName' carries no pack - there is nothing to remove." -ForegroundColor (Get-MessageColour success)
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
    Write-Host "[OK] '$DistroName' carries no pack you choose or remove by hand." -ForegroundColor (Get-MessageColour success)
    exit 0
}

$PackName = Select-FromList -Title "Packs installed in '$DistroName':" -Items $Offered

if (-not $PackName) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor (Get-MessageColour success)
    exit 0
}

# What leaves with it: a pack nothing installed requires any more, so the other
# packs do not stay with their base pulled out. The chosen pack goes first - the
# other order would ask a remove.sh whether a neighbour still claims its
# packages while that neighbour can still say yes.
$ToRemove = @(Resolve-PackRemoval -Available $Available -Installed $Installed -Leaving @($PackName))
$Also = @($ToRemove | Where-Object { $_ -ne $PackName })

# 3. What is about to happen, and only then the question. A pack without a
# remove.sh was installed before packs had one: its folder can leave, but
# nothing is undone on the system side - said, not discovered afterwards.
$Code = 0
$Missing = @()
foreach ($Name in $ToRemove) {
    $Its = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Name
    if (-not (Test-PackScript -DistroName $DistroName -Target $Its -Script "remove.sh" -ExitCode ([ref]$Code))) {
        $Missing += $Name
    }
}

Write-Host ""
Write-Host "==> Removing from '$DistroName': $($ToRemove -join ', ')" -ForegroundColor (Get-MessageColour info)
Write-Host "    What each pack installed leaves the system, and the gmake menu loses its commands." -ForegroundColor (Get-MessageColour muted)
foreach ($Name in $Also) {
    Write-Host "    '$Name' goes with '$PackName': nothing installed requires it any more." -ForegroundColor (Get-MessageColour muted)
}
if ($Missing.Count -gt 0) {
    Write-Host "    No remove.sh in: $($Missing -join ', ') - installed before packs had one." -ForegroundColor (Get-MessageColour warning)
    Write-Host "    Nothing of it is undone on the system side: only its files leave." -ForegroundColor (Get-MessageColour hint)
    Write-Host "    To take its tool out by hand, open a shell in '$DistroName'." -ForegroundColor (Get-MessageColour hint)
}
$Confirm = [string](Read-Host "Remove $($ToRemove -join ', ')? [y/N]")

if ($Confirm -notmatch "^[yY]") {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor (Get-MessageColour success)
    exit 0
}

# 4. What each pack does to leave, run from inside its own folder and streamed
# (it may ask for a password) - then its folder, once the self-removal is behind
# us.
foreach ($Name in $ToRemove) {
    $Target = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Name

    if ($Missing -notcontains $Name) {
        Write-Host ""
        Write-Host "==> Removing '$Name'..." -ForegroundColor (Get-MessageColour info)
        Invoke-PackScript -DistroName $DistroName -Target $Target -Script "remove.sh" -ExitCode ([ref]$Code)
        $RemoveCode = $Code

        # The folder stays when the script failed: the pack is still half in
        # place, and its files are what a second attempt needs.
        if ($RemoveCode -ne 0) {
            Write-Host ""
            Write-Host "[FAIL] The pack could not remove itself (exit code $RemoveCode)." -ForegroundColor (Get-MessageColour error)
            Write-Host "       Nothing was deleted: '$Name' is still installed in '$DistroName'." -ForegroundColor (Get-MessageColour hint)
            exit $RemoveCode
        }
    }

    Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode ([ref]$Code)
    if ($Code -ne 0) {
        Write-Host ""
        Write-Host "[FAIL] The pack's folder could not be deleted (exit code $Code)." -ForegroundColor (Get-MessageColour error)
        Write-Host "       '$Name' is out of the gmake menu, but its files are still in the instance." -ForegroundColor (Get-MessageColour warning)
        exit $Code
    }
}

# 5. What the packs left on the system side: the dependencies their remove.sh
# never named. scripts\cleanup_orphans.sh asks apt and ldd before taking
# anything. Once, at the end: a question about the instance, not about a pack.
Write-Host ""
Write-Host "==> Taking back what the removed packs left on the system side..." -ForegroundColor (Get-MessageColour info)
Write-Host "    Their remove.sh scripts named what they installed; what remains is what" -ForegroundColor (Get-MessageColour muted)
Write-Host "    came in as a dependency. Nothing goes that apt - or a program outside" -ForegroundColor (Get-MessageColour muted)
Write-Host "    apt - still needs." -ForegroundColor (Get-MessageColour muted)

$CleanupCode = 0
if (-not (Invoke-PackOrphanCleanup -DistroName $DistroName -ExitCode ([ref]$CleanupCode))) {
    # The packs are out either way; this is the tidy-up, not the removal.
    Write-Host ""
    Write-Host "[WARN] The cleanup stopped early (exit code $CleanupCode)." -ForegroundColor (Get-MessageColour warning)
    Write-Host "       They are gone, but some of their dependencies may remain." -ForegroundColor (Get-MessageColour hint)
}

Write-Host ""
Write-Host "==> Removed from '$DistroName': $($ToRemove -join ', ')." -ForegroundColor (Get-MessageColour success)
Write-Host "    Open a shell in it: the gmake menu no longer offers their commands." -ForegroundColor (Get-MessageColour muted)
exit 0
