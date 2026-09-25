[CmdletBinding()]
param ()

# Several packs at once: every pack this checkout carries is shown, the ones the
# instance already has arrive checked, and what comes back is applied - the
# missing ones installed, the unchecked ones taken out.
#
# The ORDER of the three steps is the whole point, and it is not the obvious
# one. The folders of the packs to add are copied FIRST, before anything is
# removed. A pack's remove.sh asks which of the packs installed still claims a
# package, and a folder that has just arrived is installed as far as that
# question is concerned - so a package two packs share is left where it is,
# instead of being taken away and put back. The newcomer then finds it already
# there, and apt says so.
#
# Nothing here decides on its own: the list is shown, one question carries both
# lists, and the first failure stops the run where it stands.

$ErrorActionPreference = "Stop"

# What the whole family shares: the instances, the menus, and the moves a pack
# makes - copy its folder in, run one of its scripts, take the folder out.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

# 1. Which instance
$Distro = Select-Distro
$DistroName = $Distro.Name

Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."

$InstanceHome = Get-InstanceHome -DistroName $DistroName
if (-not $InstanceHome) {
    Write-Host ""
    Write-Host "[ABORT] '$DistroName' did not say where its user's home is." -ForegroundColor Red
    exit 1
}
$PacksDirectory = "$InstanceHome/.config/packs"

# 2. Every pack this checkout carries, and what that instance already has
$Available = @(Get-AvailablePacks)
if ($Available.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No pack found in $PacksRoot." -ForegroundColor Red
    Write-Host "        A pack is a folder there carrying a pack.conf." -ForegroundColor Yellow
    exit 1
}
$Installed = @(Get-InstalledPacks -DistroName $DistroName -PacksDirectory $PacksDirectory)

$CheckedIndexes = @()
for ($Index = 0; $Index -lt $Available.Count; $Index++) {
    if ($Installed -contains $Available[$Index].Name) { $CheckedIndexes += $Index }
}

# 3. The checklist: what it has arrives checked, what it could have does not
$Chosen = Select-FromList -Title "Packs for '$DistroName'" -Items $Available -Multi `
    -CheckedIndexes $CheckedIndexes -Label {
        param($Pack)
        "{0,-12} {1}" -f $Pack.Name, $Pack.Description
    }

if ($null -eq $Chosen) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

# Two lists, and each one is read from a different side: what is checked and is
# not installed goes in, what is installed and is not checked comes out. Reading
# the first one off the available packs instead - everything not checked - is
# how a first run installed the pack nobody had asked for.
$Chosen = @($Chosen)
$Kept = @($Chosen | ForEach-Object { $_.Name })
$ToAdd = @($Chosen | Where-Object { $Installed -notcontains $_.Name })
$ToRemove = @($Installed | Where-Object { $Kept -notcontains $_ })

if ($ToAdd.Count -eq 0 -and $ToRemove.Count -eq 0) {
    Write-Host ""
    Write-Host "[OK] Nothing to do: '$DistroName' already has exactly that." -ForegroundColor Green
    exit 0
}

# 4. Both lists, and one question. One confirmation, not one per pack: the
# checklist above was the choice, and asking again pack by pack would only be
# reading it out loud.
Write-Host ""
if ($ToAdd.Count -gt 0) {
    Write-Host "Will install : " -NoNewline
    Write-Host ($ToAdd.Name -join ", ") -ForegroundColor Cyan
}
if ($ToRemove.Count -gt 0) {
    Write-Host "Will remove  : " -NoNewline
    Write-Host ($ToRemove -join ", ") -ForegroundColor Cyan
    Write-Host "               Their tools leave the system, and with them the dependencies" -ForegroundColor DarkGray
    Write-Host "               nothing needs any more." -ForegroundColor DarkGray
}
Write-Host ""

$Confirm = [string](Read-Host "Proceed? [Y/n]")
if ($Confirm -match "^[nN]") {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

$Code = 0

# 5. The newcomers' folders first, before anything leaves. This is the step that
# makes the shared package stay: the remove.sh scripts below ask which packs are
# installed, and these count from here on. A pack whose folder is there but
# whose install.sh has not run yet is a pack with nothing in it - a few seconds,
# inside this one command.
Write-Host ""
foreach ($Pack in $ToAdd) {
    $Target = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Pack.Name
    Write-Host "==> Placing '$($Pack.Name)'..." -ForegroundColor Cyan
    if (-not (Copy-PackIntoInstance -DistroName $DistroName -PackPath $Pack.Path -Target $Target -ExitCode ([ref]$Code))) {
        Write-Host ""
        Write-Host "[FAIL] Could not copy '$($Pack.Name)' into '$DistroName' (exit code $Code)." -ForegroundColor Red
        Write-Host "       Nothing was installed, and nothing was removed." -ForegroundColor Yellow
        Write-Host "       A pack copied by this run before the failure is in place, waiting." -ForegroundColor Yellow
        exit $Code
    }
}

# 6. What leaves. A pack without a remove.sh is one installed before packs had
# one: its folder leaves, nothing of it is undone, and that is said rather than
# discovered later.
foreach ($Name in $ToRemove) {
    $Target = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Name
    Write-Host ""
    if (Test-PackScript -DistroName $DistroName -Target $Target -Script "remove.sh" -ExitCode ([ref]$Code)) {
        Write-Host "==> Removing '$Name'..." -ForegroundColor Cyan
        Invoke-PackScript -DistroName $DistroName -Target $Target -Script "remove.sh" -ExitCode ([ref]$Code)
        if ($Code -ne 0) {
            Write-Host ""
            Write-Host "[FAIL] '$Name' could not remove itself (exit code $Code)." -ForegroundColor Red
            Write-Host "       It is still installed. The packs placed above are in place, and" -ForegroundColor Yellow
            Write-Host "       none of them has been installed yet - run this again to finish." -ForegroundColor Yellow
            exit $Code
        }
    } else {
        Write-Host "==> '$Name' carries no remove.sh: only its files leave." -ForegroundColor Yellow
        Write-Host "    Its tool stays on the system - take it out by hand if you want it gone." -ForegroundColor Yellow
    }

    Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode ([ref]$Code)
    if ($Code -ne 0) {
        Write-Host ""
        Write-Host "[FAIL] The folder of '$Name' could not be deleted (exit code $Code)." -ForegroundColor Red
        Write-Host "       The instance is half way through: run this again to finish." -ForegroundColor Yellow
        exit $Code
    }
}

# 7. What arrives: the folders are already there, so this is their install.sh.
foreach ($Pack in $ToAdd) {
    $Target = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Pack.Name
    Write-Host ""
    Write-Host "==> Installing '$($Pack.Name)' in '$DistroName'..." -ForegroundColor Cyan
    Write-Host "    Your password may be asked: the packages belong to root." -ForegroundColor DarkGray
    Invoke-PackScript -DistroName $DistroName -Target $Target -Script "install.sh" -ExitCode ([ref]$Code)

    # A half-installed pack is worse than none, exactly as in add_pack: the
    # folder is what the menu reads, so it goes back out, and what the install
    # had already written to the system stays.
    if ($Code -ne 0) {
        Write-Host ""
        Write-Host "[FAIL] The installation of '$($Pack.Name)' did not complete (exit code $Code)." -ForegroundColor Red
        Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode ([ref]$Code)
        Write-Host "       Its files were removed. The packs before it are installed." -ForegroundColor Yellow
        Write-Host "       Run this again to finish." -ForegroundColor Yellow
        exit $Code
    }
}

# 8. The dependencies the removals left behind, taken back only where nothing
# can still need them. Nothing to ask when nothing left.
if ($ToRemove.Count -gt 0) {
    Write-Host ""
    Write-Host "==> Taking back what the removed packs left on the system side..." -ForegroundColor Cyan
    $CleanupCode = 0
    if (-not (Invoke-PackOrphanCleanup -DistroName $DistroName -ExitCode ([ref]$CleanupCode))) {
        Write-Host "[WARN] The cleanup stopped early (exit code $CleanupCode)." -ForegroundColor Yellow
        Write-Host "       The packs are in place; some dependencies may remain." -ForegroundColor Yellow
    }
}

# 9. Where things stand, read back from the instance: the folder is the state,
# so the answer is what is there, not what this run meant to do.
$Now = @(Get-InstalledPacks -DistroName $DistroName -PacksDirectory $PacksDirectory)
Write-Host ""
Write-Host "==> '$DistroName' now carries: $(if ($Now.Count -gt 0) { $Now -join ', ' } else { 'no pack' })" -ForegroundColor Green
if ($ToAdd.Count -gt 0) {
    Write-Host "    Open a shell in it to use them:  .\wsl.ps1 shell" -ForegroundColor DarkGray
    Write-Host "    Then, in there:  gmake env_global_enable   (adds their variables)" -ForegroundColor DarkGray
}
exit 0
