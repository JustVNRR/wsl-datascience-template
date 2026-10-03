# ==============================================================================
# AN INSTANCE
# ==============================================================================
# One distribution: registered, or left as an archive. Its folder, its user,
# its WSL version, the look Windows Terminal gives it, the packs it carries -
# and the gestures: start, stop, restart, shell, shrink, archive, restore,
# duplicate, unregister.
class WslInstance {
    [string]$Name
    [string]$Path
    [string]$DefaultUser

    # The WSL version the instance runs as (1 or 2). A copy is imported with
    # the version of its source.
    [int]$Version = 2

    # Archive tracking: an archive is a folder under <root>\archives - the tar
    # inside, and the look (instance.json, terminal-icon.png) beside it.
    [bool]$HasArchive = $false
    [string]$ArchivePath

    [WslState]$State = [WslState]::Unknown

    [WslTheme]$Look

    # The packs the instance carries, by name: inside an instance a pack is its
    # folder - what it requires and whether it is ever offered come from the
    # catalog, the rule the commands have always followed.
    [string[]]$InstalledPacks = @()

    WslInstance() {}

    WslInstance([string]$name, [string]$path, [string]$user, [WslTheme]$look) {
        $this.Name        = $name
        $this.Path        = $path
        $this.DefaultUser = $user
        $this.Look        = $look
        $this.RefreshArchiveStatus()
        $this.RefreshState()
    }

    # =========================================================================
    # INSTANCE METHODS: Lifecycle (State, Start, Stop, Restart, Shrink)
    # =========================================================================

    [void] RefreshArchiveStatus() {
        $archiveDir = $null
        if ($this.Path) {
            $archiveDir = Join-Path (Split-Path $this.Path -Parent) "archives\$($this.Name)"
        }
        if ($archiveDir -and (Test-Path $archiveDir)) {
            $this.HasArchive  = $true
            $this.ArchivePath = $archiveDir
            return
        }
        $this.HasArchive  = $false
        $this.ArchivePath = $null
    }

    [void] RefreshState() {
        # Asked of wsl.exe: the registry does not say whether one is RUNNING.
        # An instance that is not there at all reads as Archived when an
        # archive carries its name, Unknown otherwise.
        $pattern = "^\s*\*?\s*$([regex]::Escape($this.Name))\s+(\w+)"
        $rawState = $null
        foreach ($line in @(& wsl.exe -l -v 2>$null)) {
            if ("$line" -match $pattern) { $rawState = $Matches[1]; break }
        }
        if ($rawState) {
            $this.State = if ($rawState -eq "Running") { [WslState]::Running } else { [WslState]::Stopped }
        } elseif ($this.HasArchive) {
            $this.State = [WslState]::Archived
        } else {
            $this.State = [WslState]::Unknown
        }
    }

    [void] Start() {
        if ($this.State -eq [WslState]::Archived) {
            throw "Cannot start an archived instance. Restore it first."
        }
        # --exec runs a command and returns: it comes up without opening a shell.
        & wsl.exe -d $this.Name --exec /bin/true
        if ($LASTEXITCODE -ne 0) { throw "Could not start '$($this.Name)'." }
        $this.State = [WslState]::Running
    }

    [void] Stop() {
        & wsl.exe --terminate $this.Name
        if ($LASTEXITCODE -ne 0) { throw "Could not stop '$($this.Name)'." }
        $this.State = [WslState]::Stopped
    }

    [void] Restart() {
        $this.Stop()
        $this.Start()
    }

    # Opens a shell and steps aside: the terminal belongs to it until the user
    # leaves. Returns the shell's own exit code - handed over, not interpreted.
    [int] Shell() {
        & wsl.exe -d $this.Name --cd ~
        return $LASTEXITCODE
    }

    # The .vhdx's size on disk, not what its filesystem holds.
    [long] DiskSize() {
        $vhdx = Join-Path $this.Path "ext4.vhdx"
        if (Test-Path $vhdx) { return (Get-Item $vhdx).Length }
        return 0
    }

    # One command, in place, on a running instance; it refuses on its own when
    # the disk cannot be compacted. Returns the sizes for the caller's report.
    [object] Shrink() {
        $before = $this.DiskSize()
        & wsl.exe --manage $this.Name --compact
        if ($LASTEXITCODE -ne 0) { throw "The compact of '$($this.Name)' failed." }
        $after = $this.DiskSize()
        return [PSCustomObject]@{ Before = $before; After = $after; Freed = $before - $after }
    }

    # =========================================================================
    # INSTANCE METHODS: Duplication, Archival & Destruction
    # =========================================================================

    [WslInstance] Duplicate([string]$newName) {
        # TODO: capture the look before the export and re-apply it to the copy
        # (instance.json refreshed, then reapplied once the copy exists - the
        # same pair the restore uses).
        $this.Stop()

        $targetRoot = Split-Path $this.Path -Parent
        $newPath = Join-Path $targetRoot $newName
        $tempTar = Join-Path $targetRoot "$newName-export.tar.gz"

        try {
            & wsl.exe --export $this.Name $tempTar --format tar.gz
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to export '$($this.Name)' for duplication."
            }
            # The copy is imported as the version of its source.
            & wsl.exe --import $newName $newPath $tempTar --version $this.Version
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to import '$newName'."
            }

            # TODO: write the marker (.wsl-stack, by "duplicate") right after
            # the import, then re-apply the captured look.

            $newLook = $null
            if ($this.Look) {
                $newLook = [WslTheme]::new($this.Look.IconPath, $this.Look.ColorScheme, $this.Look.FontName, $newName)
            }
            return [WslInstance]::new($newName, $newPath, $this.DefaultUser, $newLook)
        } finally {
            if (Test-Path $tempTar) {
                Remove-Item -Path $tempTar -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Writes the instance to <root>\archives\<name>: the tar (<name>.<format>),
    # and the look beside it - a tar carries neither the icon nor the colours.
    # Returns the archive folder. Two signatures because a class method takes
    # no default: the one-argument call is the ordinary tar.gz.
    [string] Archive([string]$name) {
        return $this.Archive($name, "tar.gz")
    }

    [string] Archive([string]$name, [string]$format) {
        $this.Stop()

        $archiveDir = Join-Path (Split-Path $this.Path -Parent) "archives\$name"
        if (-not (Test-Path $archiveDir)) {
            New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
        }

        $archiveFile = Join-Path $archiveDir "$name.$format"
        & wsl.exe --export $this.Name $archiveFile --format $format
        if ($LASTEXITCODE -ne 0) {
            # A partial archive left on disk would look like a backup later.
            if (Test-Path $archiveFile) {
                Remove-Item -Path $archiveFile -Force -ErrorAction SilentlyContinue
            }
            throw "The export of '$($this.Name)' failed."
        }

        # TODO: capture the look into the archive folder (instance.json and
        # terminal-icon.png), once the export succeeded - a half-written
        # archive folder is worse than one missing the look.

        $this.HasArchive  = $true
        $this.ArchivePath = $archiveDir
        return $archiveDir
    }

    [void] Unregister([bool]$toArchive) {
        $this.Stop()

        # The archive first, when asked for: the copy exists before anything is
        # destroyed.
        if ($toArchive) {
            [void]$this.Archive($this.Name)
        }

        # wsl --unregister right after the terminate would run too early.
        Start-Sleep -Seconds 1
        & wsl.exe --unregister $this.Name
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to unregister WSL distribution '$($this.Name)'."
        }

        # wsl --unregister removes the install folder with the disk; anything
        # left here is the exception.
        if ($this.Path -and (Test-Path $this.Path)) {
            Remove-Item -Path $this.Path -Recurse -Force
        }

        # Our appearance fragment for this instance.
        $fragmentPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-stack\$($this.Name).json"
        if (Test-Path $fragmentPath) {
            Remove-Item -Path $fragmentPath -Force -ErrorAction SilentlyContinue
        }

        # TODO: the rest of the Windows-side housekeeping, shared with the
        # build's profile step: prune the ghost entries left in the user's
        # settings.json, remove the other fragments pointing at a dead distro,
        # and take the name out of Docker Desktop's integrated list.

        if ($this.HasArchive) {
            $this.State = [WslState]::Archived
        } else {
            $this.State = [WslState]::Unknown
        }
    }

    # =========================================================================
    # INSTANCE METHODS: Terminal Appearance
    # =========================================================================

    [void] SetFont([string]$fontName) {
        if (-not $this.Look) { $this.Look = [WslTheme]::new() }
        $this.Look.FontName = $fontName
        $this.ApplyTerminalProfile()
    }

    [void] SetColorScheme([string]$schemeName) {
        if (-not $this.Look) { $this.Look = [WslTheme]::new() }
        $this.Look.ColorScheme = $schemeName
        $this.ApplyTerminalProfile()
    }

    # The image case: a file of the user's replaces the icon. Changing the
    # recipe (letters, colours) instead redraws it, with assets\make-icon.ps1.
    [void] SetIcon([string]$iconPath) {
        if (-not $this.Look) { $this.Look = [WslTheme]::new() }
        $this.Look.IconPath = $iconPath
        $this.ApplyTerminalProfile()
    }

    [void] ApplyTerminalProfile() {
        # TODO: write this instance's fragment (Set-InstanceFragment): the
        # guid WSL gave it, then font, colour scheme and icon - each Set* above
        # changes one and keeps the others. Also refreshes the instance's own
        # instance.json, which is what an archive carries.
    }

    # =========================================================================
    # INSTANCE METHODS: Packs Management
    # =========================================================================

    # Explicit, and the constructor does not run it: it asks the instance,
    # which boots it on the way - only the commands that need the packs pay.
    # A pack's folder is the one HOLDING pack.conf, and the path comes from the
    # home the instance names - a tilde only expands inside a shell.
    [void] RefreshPacks() {
        $this.InstalledPacks = @()
        $home = @(& wsl.exe -d $this.Name -- printenv HOME 2>$null |
            ForEach-Object { ($_ -replace "`0", "").Trim() } | Where-Object { $_ })
        if (-not $home) { return }

        $packsDirectory = "$($home[0])/.config/packs"
        $found = & wsl.exe -d $this.Name -- find $packsDirectory -mindepth 2 -maxdepth 2 -name pack.conf 2>$null
        foreach ($conf in @($found)) {
            $clean = "$conf".Trim()
            if (-not $clean) { continue }
            $packName = (($clean -replace "/pack.conf$", "").Split("/") | Select-Object -Last 1)
            $this.InstalledPacks += $packName
        }
    }

    [bool] HasPack([string]$packName) {
        return ($this.InstalledPacks -contains $packName)
    }

    # The one order that works, mirrored from the real engine (packs.ps1):
    # newcomers' folders first (a remove.sh asking which installed pack claims
    # a package must see them), then what leaves, then the installs, then the
    # dependencies the removals left behind. Answers $null, or the pack that
    # stopped the run and its exit code - what that means is the caller's
    # sentence.
    #
    # TODO: port the moves from packs.ps1 - the copy into the instance (/mnt,
    # or \\wsl.localhost when the drives are unmounted), the scripts run from
    # inside the folder, the decline code (2: the folder goes back out, nothing
    # failed), the rollback of placed folders, and the cleanup_orphans.sh pass
    # when something left.
    #
    # The newcomers are the catalog's packs, requirements already resolved;
    # what leaves is named. Both lists are explicit, @() included: a class
    # method takes no default.
    [object] ApplyPacks([WslPack[]]$toAdd, [string[]]$toRemove) {
        return $null
    }

    # =========================================================================
    # STATIC METHODS: Factory, Restore & Queries
    # =========================================================================

    static [WslInstance] Build([string]$name, [string]$installPath, [string]$tarPath, [string]$user, [WslTheme]$look) {
        if (-not (Test-Path $installPath)) {
            New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        }

        & wsl.exe --import $name $installPath $tarPath --version 2
        if ($LASTEXITCODE -ne 0) {
            throw "WSL import failed for '$name'."
        }

        # TODO: write the marker (.wsl-stack, by "build") right here - before
        # anything else can fail, so the other commands see the instance even
        # when a later step stops the run.

        $instance = [WslInstance]::new($name, $installPath, $user, $look)
        if ($look) {
            $instance.ApplyTerminalProfile()
        }
        return $instance
    }

    # From an archive folder: the tar inside it is the one to import (the
    # newest *.tar*), and the look comes back from the instance.json beside it.
    # TODO: re-apply that look - the instance.json beside the tar.
    static [WslInstance] Restore([string]$archiveDir, [string]$name, [string]$installPath) {
        $tar = Get-ChildItem -Path $archiveDir -Filter "*.tar*" -File |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $tar) {
            throw "No tar in the archive folder: $archiveDir"
        }
        return [WslInstance]::Build($name, $installPath, $tar.FullName, "root", $null)
    }

    static [void] Unregister([string]$name, [bool]$toArchive) {
        $instance = [WslInstance]::GetByName($name)
        if ($instance) {
            $instance.Unregister($toArchive)
        } else {
            # No metadata to archive from: unregister only.
            & wsl.exe --unregister $name
        }
    }

    static [WslInstance] GetByName([string]$name) {
        $all = [WslInstance]::GetAll()
        return ($all | Where-Object { $_.Name -eq $name } | Select-Object -First 1)
    }

    static [WslInstance[]] GetAll() {
        $found = @()
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
        if (-not (Test-Path $regPath)) { return $found }

        foreach ($key in Get-ChildItem $regPath) {
            $props = Get-ItemProperty $key.PSPath
            if ($props.DistributionName) {
                $basePath = ($props.BasePath -replace '^\\\\\?\\', '').TrimEnd('\')
                $instance = [WslInstance]::new($props.DistributionName, $basePath, "root", $null)
                if ($props.Version) { $instance.Version = [int]$props.Version }
                $found += $instance
            }
        }
        return $found
    }
}
