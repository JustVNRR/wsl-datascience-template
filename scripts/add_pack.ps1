[CmdletBinding()]
param ()

# No parameter on purpose: the instance and the pack both come from lists -
# typing either by heart is a name you can get wrong.
#
# Then the pack's folder is copied into the instance and its install script runs
# there, in front of you. It may ask for your password - the packages belong to
# root - and the prompt does travel through wsl.exe: no sudoers rule is written.

$ErrorActionPreference = "Stop"

# The family's shared half: the marker.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
    exit 1
}
. $InstanceLib

# The moves that make a pack travel live in scripts\packs.ps1, loaded above
# with everything the commands share. This file is the flow: which instance,
# which pack, and what it says on the way.

# 1. Which instance the pack goes into
$Distro = Select-Distro
$DistroName = $Distro.Name

# The copy and the install happen inside it, so it has to be up: WSL starts it
# on the way in, and this call waits for it.
Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."

# Where its user's things live, asked of the instance itself.
$InstanceHome = Get-InstanceHome -DistroName $DistroName
if (-not $InstanceHome) {
    Write-Host ""
    Write-Host "[ABORT] '$DistroName' did not say where its user's home is." -ForegroundColor (Get-MessageColour error)
    exit 1
}
$PacksDirectory = "$InstanceHome/.config/packs"

# 2. Which pack - the ones this repository carries and that instance lacks
$Catalog = Get-PackCatalog
if ($Catalog.AvailablePacks.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No pack found in $PacksRoot." -ForegroundColor (Get-MessageColour error)
    Write-Host "        A pack is a folder there carrying a pack.conf." -ForegroundColor (Get-MessageColour hint)
    exit 1
}

$Installed = @(Get-InstalledPacks -DistroName $DistroName -PacksDirectory $PacksDirectory)
# Only the packs a user chooses: an invisible one arrives with the pack that
# requires it, never offered.
$Candidates = @($Catalog.AvailablePacks | Where-Object { $_.Offered -and $Installed -notcontains $_.Name })

if ($Candidates.Count -eq 0) {
    Write-Host ""
    Write-Host "[OK] '$DistroName' already has every pack this repository offers." -ForegroundColor (Get-MessageColour success)
    exit 0
}

# Said before the list, not after it: with the arrows the rows are drawn in
# place, and anything under them gets painted over.
if ($Installed.Count -gt 0) {
    Write-Host ""
    Write-Host ("       Already in '$DistroName': {0}" -f ($Installed -join ", ")) -ForegroundColor (Get-MessageColour muted)
}

$Pack = Select-FromList -Title "Packs available for '$DistroName':" -Items $Candidates -Label {
    param($Entry)
    "{0,-12} {1}" -f $Entry.Name, $Entry.Description
}

if (-not $Pack) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor (Get-MessageColour success)
    exit 0
}

$PackName = $Pack.Name

# 3. What travels: the pack and whatever it requires, requirements first - and
# resolved by the same helper the checklist uses, so that "what arrives" means
# the same thing in both commands.
$ToInstall = @()
foreach ($Name in @($Catalog.ResolveSelection(@($PackName), $Installed))) {
    $Entry = $Catalog.GetPack($Name)
    if ($null -ne $Entry) { $ToInstall += $Entry }
}

# 4. Each pack's folder copied in, then what it does to install itself from
# inside it - both in scripts\packs.ps1.
foreach ($Entry in $ToInstall) {
    $Target = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Entry.Name

    Write-Host ""
    Write-Host "==> Installing '$($Entry.Name)' in '$DistroName'..." -ForegroundColor (Get-MessageColour info)
    if ($Entry.Name -ne $PackName) {
        Write-Host "    It comes with '$PackName', which requires it." -ForegroundColor (Get-MessageColour muted)
    }
    Write-Host "    Your password may be asked." -ForegroundColor (Get-MessageColour muted)

    $Code = 0
    if (-not (Copy-PackIntoInstance -DistroName $DistroName -PackPath $Entry.Path -Target $Target -ExitCode ([ref]$Code))) {
        Write-Host "[ABORT] Could not copy the pack's files into '$DistroName' (exit code $Code)." -ForegroundColor (Get-MessageColour error)
        Write-Host "        The message above says what refused: the instance, or Windows." -ForegroundColor (Get-MessageColour hint)
        exit $Code
    }

    Invoke-PackScript -DistroName $DistroName -Target $Target -Script "install.sh" -ExitCode ([ref]$Code)
    $InstallCode = $Code

    # Exit code 2: the pack asked a question and the answer was no (the claude
    # pack asks about a second copy installed on Windows). Its folder goes back
    # out, and the command ends on exit 0: nothing is broken, nothing to run
    # again.
    if ($InstallCode -eq 2) {
        Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode ([ref]$Code)
        Write-Host "       The pack's files were removed: it is not installed in '$DistroName'." -ForegroundColor (Get-MessageColour hint)
        exit 0
    }

    # A half-installed pack is worse than none: the Makefile loads whatever
    # folder is there, so the menu would offer commands whose tool was never
    # installed. The folder goes back out - and only it: what the install
    # already wrote stays, and running this again picks up there.
    if ($InstallCode -ne 0) {
        Write-Host ""
        Write-Host "[FAIL] The installation did not complete (exit code $InstallCode)." -ForegroundColor (Get-MessageColour error)
        Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode ([ref]$Code)
        Write-Host "       The pack's files were removed." -ForegroundColor (Get-MessageColour hint)
        Write-Host "       Whatever the install had already put in place is still there - run this again to finish." -ForegroundColor (Get-MessageColour hint)
        exit $InstallCode
    }
}

Write-Host ""
Write-Host "==> '$PackName' is installed in '$DistroName'." -ForegroundColor (Get-MessageColour success)
# The pack's samples travelled with its folder, but nothing merged them into
# the user's .env files - those are theirs, and no install writes into them.
# Said once, and only when a sample travelled.
if (@($ToInstall | Where-Object { $_.ShipsSamples() }).Count -gt 0) {
    Write-Host "    Then, in there:  gmake env_global_enable   (adds the pack's variables)" -ForegroundColor (Get-MessageColour muted)
}
exit 0
