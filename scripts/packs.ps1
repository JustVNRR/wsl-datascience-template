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

# Every pack this checkout carries, with the line the menu shows and the folder
# to copy from. Sorted by name: a menu whose numbers move is a menu you cannot
# trust twice.
function Get-AvailablePacks {
    param([string]$Root = $PacksRoot)

    $Found = @()
    if (-not (Test-Path $Root)) { return @() }
    foreach ($Folder in (Get-ChildItem -Path $Root -Directory | Sort-Object Name)) {
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
    Invoke-InInstance -DistroName $DistroName -Command @("cp", "-r", ".", "$Target/") -WorkingDirectory $PackPath -ExitCode $ExitCode
    return ($ExitCode.Value -eq 0)
}

# Run one of the pack's own scripts from inside its folder. Output streaming on
# purpose: it is what tells the user how far along it is, and it may ask for a
# password.
function Invoke-PackScript {
    param([string]$DistroName, [string]$Target, [string]$Script, [ref]$ExitCode)
    Invoke-InInstance -DistroName $DistroName -Command @("bash", $Script) -WorkingDirectory $Target -ExitCode $ExitCode
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
