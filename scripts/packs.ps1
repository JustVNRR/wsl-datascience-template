# ==============================================================================
# PACKS: WHAT THE CHECKOUT CARRIES, WHAT AN INSTANCE HAS, HOW ONE TRAVELS
# ==============================================================================
# A pack is a folder. It is installed when its folder is in ~/.config/packs, and
# its folder is the only thing that travels: add_pack copies it from this
# checkout into the instance and runs the pack's own install.sh there, as the
# user; remove_pack runs remove.sh, takes the folder back out, and then asks
# what the pack left on the system side.
#
# Add, remove, and the bulk command that manages several at once all need the
# same moves. They are here, once, for the same reason the instance helpers are
# in instance.ps1: a second copy is how the copies start.
#
# Nothing here sends a bash script as text through wsl.exe. Only plain paths
# travel, one argument at a time - a script handed over as text loses its quotes
# on the way, and the failure reads like the instance's fault.
# ==============================================================================

# Where the packs live, and the cleanup that travels with a removal. Read here,
# at load time, and not inside the functions: $PSScriptRoot means the file being
# executed, and a function belongs to whichever script called it.
$PacksRoot = Join-Path (Split-Path $PSScriptRoot -Parent) "packs"
$OrphanCleanupScript = Join-Path $PSScriptRoot "cleanup_orphans.sh"

# Every pack this checkout carries, with the line the menu shows, the folder to
# copy from, and the two declarations the checklist reads: what it requires, and
# whether it is offered at all. Sorted by name: a menu whose numbers move is a
# menu you cannot trust twice.
#
# Both declarations are optional, and absent means the ordinary case: a pack
# that requires nothing, and one the user chooses. Only `PACK_VISIBLE := no`
# hides a pack - a value that is neither yes nor no leaves it visible, which is
# where a typo should land: a pack that never appears is a pack nobody can
# report.
function Get-AvailablePacks {
    param([string]$Root = $PacksRoot)

    $Found = @()
    if (-not (Test-Path $Root)) { return @() }
    foreach ($Folder in (Get-ChildItem -Path $Root -Directory | Sort-Object Name)) {
        $Conf = Join-Path $Folder.FullName "pack.conf"
        if (-not (Test-Path $Conf)) { continue }

        $Description = ""
        $Requires = @()
        $Visible = $true
        $Welcome = ""
        foreach ($Line in (Get-Content -Path $Conf -Encoding UTF8)) {
            if ($Line -match '^\s*PACK_DESCRIPTION\s*:=\s*(.+?)\s*$') { $Description = $Matches[1] }
            elseif ($Line -match '^\s*PACK_REQUIRES\s*:=\s*(.*)$') { $Requires = @($Matches[1] -split '\s+' | Where-Object { $_ }) }
            elseif ($Line -match '^\s*PACK_VISIBLE\s*:=\s*(\S+)') { $Visible = ($Matches[1] -notmatch '^(?i)no$') }
            elseif ($Line -match '^\s*PACK_WELCOME\s*:=\s*(.+?)\s*$') { $Welcome = $Matches[1] }
        }

        $Found += [PSCustomObject]@{
            Name        = $Folder.Name
            Path        = $Folder.FullName
            Description = $Description
            Requires    = $Requires
            Visible     = $Visible
            Welcome     = $Welcome
        }
    }
    return @($Found)
}

# Does this pack bring anything for the user's own .env files? Read from the
# folder, like everything else here: a sample is a file, and a pack that ships
# none has nothing to merge. It decides whether a command ends by pointing at
# `gmake env_global_enable` - the target itself comes with the dev pack, which
# is to say with the samples.
function Test-PackShipsSamples {
    param([string]$Path)

    return (Test-Path (Join-Path $Path "env.global.sample")) -or (Test-Path (Join-Path $Path "env.project.sample"))
}

# What a pack needs, added to what was chosen. A pack is installed ON TOP of
# what it requires - its install.sh may call a macro or read a variable the
# other one brought - so the order is the whole point of this one: what a pack
# requires is placed before it, and a requirement two levels down before both.
function Add-PackRequires {
    param(
        [object[]]$Available,
        [string]$Name,
        [string[]]$Installed,
        [hashtable]$Seen,
        [System.Collections.ArrayList]$Ordered
    )

    if ($Seen.ContainsKey($Name)) { return }
    $Seen[$Name] = $true

    # A requirement this checkout does not carry is not a pack that can be
    # installed; it is named in a pack.conf and absent from packs/. Nothing to
    # do about it here, and the pack that asked is the one that will fail.
    $Pack = @($Available | Where-Object { $_.Name -eq $Name })[0]
    if ($null -eq $Pack) { return }

    # Through it even when it is already there: what IT requires may be missing.
    foreach ($Need in $Pack.Requires) {
        Add-PackRequires -Available $Available -Name $Need -Installed $Installed -Seen $Seen -Ordered $Ordered
    }

    # And it is not placed a second time. A pack the instance already carries is
    # not copied over and its install.sh does not run again - the arrival of gcp
    # on an instance that has carried python all along must not touch dev, whose
    # folder is right there and whose install would be an install on top of
    # itself. It is the same move in every command: what travels is what is
    # missing.
    if ($Installed -notcontains $Name) { [void]$Ordered.Add($Name) }
}

# The list to install, in the order to install it: what was chosen and is not
# there yet, each one after what it requires. One place resolves it so that
# add_pack, the checklist and the run itself cannot disagree about what travels
# with what.
function Resolve-PackSelection {
    param([object[]]$Available, [string[]]$Names, [string[]]$Installed = @())

    $Seen = @{}
    $Ordered = New-Object System.Collections.ArrayList
    foreach ($Name in $Names) {
        Add-PackRequires -Available $Available -Name $Name -Installed $Installed -Seen $Seen -Ordered $Ordered
    }
    return @($Ordered)
}

# What leaves, with what has to leave with it. A pack that is not visible is
# never in the checklist, so nobody can untick it - it is not offered. It leaves
# when the last pack that requires it does, and $Leaving is what the user let go
# of: the two together, in that order, are what a removal takes out.
#
# Repeated until nothing changes, because an invisible pack may itself require
# another one, and the second loses its claimant the moment the first does.
function Resolve-PackRemoval {
    param([object[]]$Available, [string[]]$Installed, [string[]]$Leaving, [string[]]$Arriving = @())

    $Gone = New-Object System.Collections.ArrayList
    foreach ($Name in $Leaving) { [void]$Gone.Add($Name) }

    do {
        $Added = 0
        # Who is there once the run is over: what stays, plus what is arriving in
        # the same run. A pack that is on its way in is a claimant like any
        # other - it is the reason the run happens - so an invisible pack it
        # requires must be left where it is rather than removed and not put back.
        $Remaining = @($Installed | Where-Object { $Gone -notcontains $_ }) + @($Arriving)

        foreach ($Name in $Installed) {
            if ($Gone -contains $Name) { continue }

            # Not carried by this checkout: not in the checklist either, and left
            # alone for the same reason. Same for a visible one, which only ever
            # leaves because the user unticked it.
            $Pack = @($Available | Where-Object { $_.Name -eq $Name })[0]
            if ($null -eq $Pack) { continue }
            if ($Pack.Visible) { continue }

            $Claimed = $false
            foreach ($Other in $Remaining) {
                $OtherPack = @($Available | Where-Object { $_.Name -eq $Other })[0]
                if ($null -ne $OtherPack -and $OtherPack.Requires -contains $Name) { $Claimed = $true; break }
            }
            if (-not $Claimed) {
                [void]$Gone.Add($Name)
                $Added++
            }
        }
    } while ($Added -gt 0)

    return @($Gone)
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

# Where a pack's folder is, once it is in the instance. One place, so that the
# three commands cannot disagree about where a pack lives.
function Get-PackFolder {
    param([string]$PacksDirectory, [string]$Name)
    return "$PacksDirectory/$Name"
}

# Does the pack carry that script? Asked before anything is promised: a pack
# installed before packs had a remove.sh is one whose folder can leave, but
# nothing of it will be undone on the system side.
function Test-PackScript {
    param([string]$DistroName, [string]$Target, [string]$Script, [ref]$ExitCode)

    Invoke-InInstance -DistroName $DistroName -Command @("test", "-f", "$Target/$Script") -ExitCode $ExitCode -Quiet
    return ($ExitCode.Value -eq 0)
}

# Copy a pack's folder into the instance - the whole of what "travelling" means.
# It is copied from inside: the pack's own folder becomes the working directory,
# which wsl.exe knows how to do with a Windows path (`--cd`), and `.` is then
# all there is to name. No path translation on purpose: the obvious candidate is
# `wslpath`, which the instance does not carry at all.
function Copy-PackIntoInstance {
    param([string]$DistroName, [string]$PackPath, [string]$Target, [ref]$ExitCode)

    Invoke-InInstance -DistroName $DistroName -Command @("mkdir", "-p", $Target) -ExitCode $ExitCode -Quiet
    if ($ExitCode.Value -ne 0) { return $false }
    # | Out-Host for the reason written above Invoke-PackScript: this function
    # answers a value, and the copy must not speak through it.
    Invoke-InInstance -DistroName $DistroName -Command @("cp", "-r", ".", "$Target/") -WorkingDirectory $PackPath -ExitCode $ExitCode | Out-Host
    return ($ExitCode.Value -eq 0)
}

# Run one of the pack's own scripts from inside its folder. Output streaming on
# purpose: it is what tells the user how far along it is, and it may ask for a
# password.
#
# Streaming to the HOST, and that word is the whole point of the line. The
# callers of this function hand something back - a folder placed, a pack that
# failed - so they write that result into a variable or read it in a condition;
# and a function whose output is captured captures whatever its own calls print
# as well. That is how a pack's install went SILENT: apt's lines, the pack's
# progress, everything the script said, went into the variable that was holding
# the answer and never reached the screen - while apt's own errors, which travel
# on the error stream, still showed. Out-Host writes the text to the screen and
# leaves the value where it was.
function Invoke-PackScript {
    param([string]$DistroName, [string]$Target, [string]$Script, [ref]$ExitCode)
    Invoke-InInstance -DistroName $DistroName -Command @("bash", $Script) -WorkingDirectory $Target -ExitCode $ExitCode | Out-Host
}

# The folder, and with it the pack: the Makefile loads whatever folder is there,
# so a folder that stays is a pack that stays.
function Remove-PackFolder {
    param([string]$DistroName, [string]$Target, [ref]$ExitCode)
    Invoke-InInstance -DistroName $DistroName -Command @("rm", "-rf", $Target) -ExitCode $ExitCode -Quiet
}

# What the pack left on the system side. Its remove.sh took back what it had
# named; what stays is what arrived as a DEPENDENCY - nobody's to name, and
# heavy: the vision pack leaves 203 packages and 462 MB behind. The script asks
# apt (no installed package needs them any more) and ldd (nothing outside apt
# links them), and only then removes. It travels the way a pack does - a copy,
# then a plain path, never as text.
function Invoke-PackOrphanCleanup {
    param([string]$DistroName, [ref]$ExitCode)

    if (-not (Test-Path $OrphanCleanupScript)) {
        # Nothing to run: the caller says so rather than pretend it happened.
        return $false
    }

    $RemoteScript = "/tmp/cleanup_orphans.sh"
    $Sent = 0
    Invoke-InInstance -DistroName $DistroName -Command @("cp", "cleanup_orphans.sh", $RemoteScript) `
        -WorkingDirectory $PSScriptRoot -ExitCode ([ref]$Sent) -Quiet
    if ($Sent -ne 0) { return $false }

    Invoke-PackScript -DistroName $DistroName -Target "/tmp" -Script "cleanup_orphans.sh" -ExitCode $ExitCode
    $Cleaned = $ExitCode.Value

    $Gone = 0
    Invoke-InInstance -DistroName $DistroName -Command @("rm", "-f", $RemoteScript) -ExitCode ([ref]$Gone) -Quiet
    return ($Cleaned -eq 0)
}

# ---------------------------------------------------------------------------
# ASKING WHICH PACKS, AND DOING WHAT THE ANSWER SAYS
# ---------------------------------------------------------------------------
# Two commands ask the same question - manage_packs, about an instance that
# exists, and build, about one that is about to. It is asked here, once, like
# the moves above, so that the two commands cannot drift apart.

# The checklist, the two lists, and the one question that carries them. What
# comes back:
#
#   $null               the user backed out - Escape, or "n" to the confirmation
#   { ToAdd; ToRemove } the answer, either list possibly empty. Empty is an
#                       answer ("nothing"), not a cancellation: the two callers
#                       do different things with it.
#
# -Installed and -Checked are two different facts, and they differ at build
# time: a rebuilt instance has no pack yet, so there is nothing to remove, while
# the boxes a user expects ticked are the ones its predecessor carried.
#
# The two lists come back ready to apply: a pack's requirements are already in
# them, in the order they have to leave or arrive in.
function Select-Packs {
    param(
        [string]$Title,
        [object[]]$Available,
        [string[]]$Installed = @(),
        [string[]]$Checked = $null
    )

    if ($null -eq $Checked) { $Checked = $Installed }

    # What the checklist shows: the packs a user chooses. An invisible one is
    # installed by a visible pack that requires it and leaves with the last one,
    # so it is in neither list and is never named here.
    $Offered = @($Available | Where-Object { $_.Visible })
    $OfferedNames = @($Offered | ForEach-Object { $_.Name })

    $CheckedIndexes = @()
    for ($Index = 0; $Index -lt $Offered.Count; $Index++) {
        if ($Checked -contains $Offered[$Index].Name) { $CheckedIndexes += $Index }
    }

    $Chosen = Select-FromList -Title $Title -Items $Offered -Multi `
        -CheckedIndexes $CheckedIndexes -Label {
            param($Pack)
            "{0,-12} {1}" -f $Pack.Name, $Pack.Description
        }

    if ($null -eq $Chosen) { return $null }

    # Two lists, and each one is read from a different side: what is checked and
    # is not installed goes in, what is installed and is not checked comes out.
    # Reading the first one off the available packs instead - everything not
    # checked - is how a first run installed the pack nobody had asked for.
    $Chosen = @($Chosen)
    $Kept = @($Chosen | ForEach-Object { $_.Name })
    $Carried = @($Available | ForEach-Object { $_.Name })

    # What leaves is what the checklist showed and the user unchecked - and only
    # that. A folder installed in the instance that this checkout does not carry
    # - another checkout's pack, one copied in by hand, one since removed from
    # the repository - is not in the checklist at all, so nobody can have
    # unchecked it, and taking it away would be taking away something that was
    # never shown. It is named instead, in grey, before the list.
    $Unticked = @($Installed | Where-Object { $OfferedNames -contains $_ -and $Kept -notcontains $_ })
    $NotCarried = @($Installed | Where-Object { $Carried -notcontains $_ })
    if ($NotCarried.Count -gt 0) {
        Write-Host ""
        Write-Host ("       Installed here, not from this repository - left alone: {0}" -f ($NotCarried -join ", ")) -ForegroundColor DarkGray
    }

    # What a pack requires travels with it, and what nothing requires any more
    # leaves with it. Both additions are made here, once, so that the lines
    # below, the question and the run all read the same two lists.
    #
    # Ticked and installed is not added: the resolver is given what the instance
    # already has, and answers what is missing - a whole list of ticked boxes on
    # an instance that carries them all comes back empty, which is exactly what
    # the caller must do about it, nothing.
    $ToAdd = @()
    foreach ($Name in @(Resolve-PackSelection -Available $Available -Names $Kept -Installed $Installed)) {
        $Pack = @($Available | Where-Object { $_.Name -eq $Name })[0]
        if ($null -ne $Pack) { $ToAdd += $Pack }
    }
    # -Arriving after -ToAdd, and that order matters: a pack on its way in holds
    # the invisible pack it requires, so the removal must know about it.
    $ToRemove = @(Resolve-PackRemoval -Available $Available -Installed $Installed -Leaving $Unticked `
        -Arriving @($ToAdd | ForEach-Object { $_.Name }))

    if ($ToAdd.Count -eq 0 -and $ToRemove.Count -eq 0) {
        return [PSCustomObject]@{ ToAdd = @(); ToRemove = @() }
    }

    # Both lists, and one question. One confirmation, not one per pack: the
    # checklist above was the choice, and asking again pack by pack would only
    # be reading it out loud. A list with nothing in it gets no line - at build
    # time the second one is always empty.
    #
    # A pack the user did not tick is named with its reason under the list: it
    # arrives because something requires it, or leaves because nothing does, and
    # a pack that comes or goes without that line reads like a mistake.
    Write-Host ""
    if ($ToAdd.Count -gt 0) {
        Write-Host "Will install : " -NoNewline
        Write-Host (($ToAdd | ForEach-Object { $_.Name }) -join ", ") -ForegroundColor Cyan
        $Because = @()
        foreach ($Pack in $ToAdd) {
            if ($Kept -notcontains $Pack.Name) {
                $Who = @($ToAdd | Where-Object { $_.Requires -contains $Pack.Name } | ForEach-Object { $_.Name })
                $Because += ("{0}: required by {1}" -f $Pack.Name, ($Who -join " and "))
            }
        }
        if ($Because.Count -gt 0) { Write-Host ("               (" + ($Because -join "; ") + ")") -ForegroundColor DarkGray }
    }
    if ($ToRemove.Count -gt 0) {
        Write-Host "Will remove  : " -NoNewline
        Write-Host ($ToRemove -join ", ") -ForegroundColor Cyan
        $Because = @()
        foreach ($Name in $ToRemove) {
            if ($Unticked -notcontains $Name) { $Because += ("{0}: nothing installed requires it any more" -f $Name) }
        }
        if ($Because.Count -gt 0) { Write-Host ("               (" + ($Because -join "; ") + ")") -ForegroundColor DarkGray }
        Write-Host "               Their tools leave the system, and with them the dependencies" -ForegroundColor DarkGray
        Write-Host "               nothing needs any more." -ForegroundColor DarkGray
    }
    Write-Host ""

    $Confirm = [string](Read-Host "Proceed? [Y/n]")
    if ($Confirm -match "^[nN]") { return $null }

    return [PSCustomObject]@{ ToAdd = $ToAdd; ToRemove = $ToRemove }
}

# Do what the two lists say, in the one order that works: the newcomers' folders
# are copied FIRST, before anything is removed, so that a remove.sh asking which
# installed pack still claims a package sees them and leaves a shared package
# where it is; then what leaves; then the installs; and last the dependencies
# the removals left behind.
#
# It prints as it goes - a pack's install.sh may ask for a password - and it
# hands back $null when everything landed, or the pack that stopped the run.
# What that means is the caller's sentence, not this one's: "run this again" and
# "the build went through, finish later" are not the same news.
function Invoke-PackApply {
    param(
        [string]$DistroName,
        [string]$PacksDirectory,
        [object[]]$ToAdd = @(),
        [string[]]$ToRemove = @(),
        [string]$ResumeHint = "Run this again to finish."
    )

    $Code = 0

    # 1. The newcomers' folders first, before anything leaves. This is the step
    # that makes the shared package stay: the remove.sh scripts below ask which
    # packs are installed, and these count from here on. A pack whose folder is
    # there but whose install.sh has not run yet is a pack with nothing in it - a
    # few seconds, inside this one call.
    Write-Host ""
    foreach ($Pack in $ToAdd) {
        $Target = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Pack.Name
        Write-Host "==> Placing '$($Pack.Name)'..." -ForegroundColor Cyan
        if (-not (Copy-PackIntoInstance -DistroName $DistroName -PackPath $Pack.Path -Target $Target -ExitCode ([ref]$Code))) {
            Write-Host ""
            Write-Host "[FAIL] Could not copy '$($Pack.Name)' into '$DistroName' (exit code $Code)." -ForegroundColor Red
            Write-Host "       Nothing was installed, and nothing was removed." -ForegroundColor Yellow
            Write-Host "       A pack copied by this run before the failure is in place, waiting." -ForegroundColor Yellow
            Write-Host "       $ResumeHint" -ForegroundColor Yellow
            return [PSCustomObject]@{ Pack = $Pack.Name; ExitCode = $Code }
        }
    }

    # 2. What leaves. A pack without a remove.sh is one installed before packs
    # had one: its folder leaves, nothing of it is undone, and that is said
    # rather than discovered later.
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
                Write-Host "       none of them has been installed yet." -ForegroundColor Yellow
                Write-Host "       $ResumeHint" -ForegroundColor Yellow
                return [PSCustomObject]@{ Pack = $Name; ExitCode = $Code }
            }
        } else {
            Write-Host "==> '$Name' carries no remove.sh: only its files leave." -ForegroundColor Yellow
            Write-Host "    Its tool stays on the system - take it out by hand if you want it gone." -ForegroundColor Yellow
        }

        Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode ([ref]$Code)
        if ($Code -ne 0) {
            Write-Host ""
            Write-Host "[FAIL] The folder of '$Name' could not be deleted (exit code $Code)." -ForegroundColor Red
            Write-Host "       The instance is half way through." -ForegroundColor Yellow
            Write-Host "       $ResumeHint" -ForegroundColor Yellow
            return [PSCustomObject]@{ Pack = $Name; ExitCode = $Code }
        }
    }

    # 3. What arrives: the folders are already there, so this is their install.sh.
    foreach ($Pack in $ToAdd) {
        $Target = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Pack.Name
        Write-Host ""
        Write-Host "==> Installing '$($Pack.Name)' in '$DistroName'..." -ForegroundColor Cyan
        Write-Host "    Your password may be asked: the packages belong to root." -ForegroundColor DarkGray
        Invoke-PackScript -DistroName $DistroName -Target $Target -Script "install.sh" -ExitCode ([ref]$Code)

        # A half-installed pack is worse than none, exactly as in add_pack: the
        # folder is what the menu reads, so it goes back out, and what the
        # install had already written to the system stays.
        if ($Code -ne 0) {
            # Kept aside before the folder goes back out: Remove-PackFolder
            # answers through the same [ref], and the code this run reports has
            # to be the install's - a failed install that says 0 is a failure
            # the caller cannot see.
            $InstallCode = $Code
            Write-Host ""
            Write-Host "[FAIL] The installation of '$($Pack.Name)' did not complete (exit code $InstallCode)." -ForegroundColor Red
            Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode ([ref]$Code)
            Write-Host "       Its files were removed. The packs before it are installed." -ForegroundColor Yellow
            Write-Host "       $ResumeHint" -ForegroundColor Yellow
            return [PSCustomObject]@{ Pack = $Pack.Name; ExitCode = $InstallCode }
        }
    }

    # 4. The dependencies the removals left behind, taken back only where
    # nothing can still need them. Nothing to ask when nothing left.
    if ($ToRemove.Count -gt 0) {
        Write-Host ""
        Write-Host "==> Taking back what the removed packs left on the system side..." -ForegroundColor Cyan
        $CleanupCode = 0
        if (-not (Invoke-PackOrphanCleanup -DistroName $DistroName -ExitCode ([ref]$CleanupCode))) {
            Write-Host "[WARN] The cleanup stopped early (exit code $CleanupCode)." -ForegroundColor Yellow
            Write-Host "       The packs are in place; some dependencies may remain." -ForegroundColor Yellow
        }
    }

    return $null
}
