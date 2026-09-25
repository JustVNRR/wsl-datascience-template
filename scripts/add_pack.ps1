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

# What the checkout carries, what an instance has, and the moves that make a
# pack travel all live in scripts\packs.ps1, loaded by instance.ps1 above. This
# file is the flow: which instance, which pack, and what it says on the way.

# 1. Which instance the pack goes into
$Distro = Select-Distro
$DistroName = $Distro.Name

# It may be stopped: the copy and the install happen inside it, so it has to be
# up. WSL starts it on the way in and this call is what waits for it.
Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."

# Where its user's things live, asked of the instance itself.
$InstanceHome = Get-InstanceHome -DistroName $DistroName
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
# Only the packs a user chooses: an invisible one is not offered, here any more
# than in the checklist - it arrives with the pack that requires it.
$Candidates = @($Available | Where-Object { $_.Visible -and $Installed -notcontains $_.Name })

if ($Candidates.Count -eq 0) {
    Write-Host ""
    Write-Host "[OK] '$DistroName' already has every pack this repository offers." -ForegroundColor Green
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

# 3. What travels: the pack, and whatever it requires, the requirements first -
# a pack lands on top of what it needs. Resolved here, by the same helper the
# checklist uses, so that "what arrives" means the same thing in both commands.
$ToInstall = @()
foreach ($Name in @(Resolve-PackSelection -Available $Available -Names @($PackName))) {
    $Entry = @($Available | Where-Object { $_.Name -eq $Name })[0]
    if ($null -ne $Entry) { $ToInstall += $Entry }
}

# 4. Each pack's folder, copied into the instance, then what the pack does to
# install itself from inside its own folder. Both live in scripts\packs.ps1.
foreach ($Entry in $ToInstall) {
    $Target = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Entry.Name

    Write-Host ""
    Write-Host "==> Installing '$($Entry.Name)' in '$DistroName'..." -ForegroundColor Cyan
    if ($Entry.Name -ne $PackName) {
        Write-Host "    It comes with '$PackName', which requires it." -ForegroundColor DarkGray
    }
    Write-Host "    Your password may be asked: the packages belong to root." -ForegroundColor DarkGray

    $Code = 0
    if (-not (Copy-PackIntoInstance -DistroName $DistroName -PackPath $Entry.Path -Target $Target -ExitCode ([ref]$Code))) {
        Write-Host "[ABORT] Could not copy the pack's files into '$DistroName' (exit code $Code)." -ForegroundColor Red
        Write-Host "        The message above is the instance's own answer." -ForegroundColor Yellow
        exit $Code
    }

    Invoke-PackScript -DistroName $DistroName -Target $Target -Script "install.sh" -ExitCode ([ref]$Code)
    $InstallCode = $Code

    # A half-installed pack is worse than none: the Makefile loads whatever
    # folder is there, so the menu would offer commands whose tool was never
    # installed. The folder goes back out, and only it - what the install
    # already wrote to the system stays, and running this again picks up where
    # it stopped.
    if ($InstallCode -ne 0) {
        Write-Host ""
        Write-Host "[FAIL] The installation did not complete (exit code $InstallCode)." -ForegroundColor Red
        Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode ([ref]$Code)
        Write-Host "       The pack's files were removed: nothing of it stays in the instance." -ForegroundColor Yellow
        Write-Host "       Whatever the install had already put in place is still there - run this again to finish." -ForegroundColor Yellow
        exit $InstallCode
    }
}

Write-Host ""
Write-Host "==> '$PackName' is installed in '$DistroName'." -ForegroundColor Green
Write-Host "    Open a shell in it to use it:  .\wsl.ps1 shell" -ForegroundColor DarkGray
# The pack's samples travelled with its folder, but nothing has merged them into
# the user's own .env files - those are theirs, and no install writes into them.
# Said here, once, because it is the one step an install leaves over - and only
# when a sample travelled: a pack that ships none has nothing to merge, and
# `gmake env_global_enable` itself comes with the dev pack.
if (@($ToInstall | Where-Object { Test-PackShipsSamples -Path $_.Path }).Count -gt 0) {
    Write-Host "    Then, in there:  gmake env_global_enable   (adds the pack's variables)" -ForegroundColor DarkGray
}
exit 0
