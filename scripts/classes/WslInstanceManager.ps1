# ==============================================================================
# THE WHOLE SET, AND WHAT THE COMMANDS ASK IT
# ==============================================================================
# The instances - registered, or left as an archive - the name and path
# conflicts, and the fleet gestures: create, restore, stop everything.
class WslInstanceManager {
    [string]$InstancesRoot
    [string]$ArchivesRoot
    [WslInstance[]]$Instances = @()

    # Folders under the root carrying the marker that no registered instance
    # claims - what an interrupted removal, or an outside `wsl --unregister`,
    # leaves behind. No command removes them: the list shows them, a hand
    # deletes them.
    [string[]]$ForgottenFolders = @()

    WslInstanceManager([string]$instancesRoot) {
        $this.InstancesRoot = $instancesRoot.TrimEnd('\')
        $this.ArchivesRoot  = Join-Path $this.InstancesRoot "archives"
        $this.Refresh()
    }

    # =========================================================================
    # DISCOVERY & INVENTORY
    # =========================================================================

    [void] Refresh() {
        $this.Instances = @()
        $this.ForgottenFolders = @()
        $knownNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $registeredPaths = @()

        # 1. The distributions registered in the Windows registry. Their state
        # comes from one batched question - wsl --list says what runs, about
        # everyone at once - not from one wsl.exe per instance.
        $Running = Get-DistroNames -Running
        foreach ($inst in [WslInstance]::GetAll()) {
            $inst.RefreshArchiveStatus()
            if ($Running -contains $inst.Name) {
                $inst.State = [WslState]::Running
            } else {
                $inst.State = [WslState]::Stopped
            }
            $this.Instances += $inst
            $registeredPaths += $inst.Path
            $null = $knownNames.Add($inst.Name)
        }

        # 2. The archives with no registered distribution left: an instance
        # that lives only as a folder under <root>\archives - the tar inside,
        # and the look beside it.
        if (Test-Path $this.ArchivesRoot) {
            foreach ($archiveDir in (Get-ChildItem -Path $this.ArchivesRoot -Directory | Sort-Object Name)) {
                $tar = Get-ChildItem -Path $archiveDir.FullName -Filter "*.tar*" -File |
                    Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if (-not $tar) { continue }
                if ($knownNames.Contains($archiveDir.Name)) { continue }

                $archivedInst = [WslInstance]::new()
                $archivedInst.Name = $archiveDir.Name
                $archivedInst.Path = Join-Path $this.InstancesRoot $archiveDir.Name
                $archivedInst.HasArchive = $true
                $archivedInst.ArchivePath = $archiveDir.FullName
                $archivedInst.State = [WslState]::Archived

                $this.Instances += $archivedInst
                $null = $knownNames.Add($archiveDir.Name)
            }
        }

        # 3. Marked folders that no instance claims
        if (Test-Path $this.InstancesRoot) {
            foreach ($folder in (Get-ChildItem -Path $this.InstancesRoot -Directory -ErrorAction SilentlyContinue)) {
                if ((Test-TemplateInstance -Folder $folder.FullName) -and
                    ($registeredPaths -notcontains $folder.FullName)) {
                    $this.ForgottenFolders += $folder.FullName
                }
            }
        }
    }

    # =========================================================================
    # LOOKUP & VALIDATION
    # =========================================================================

    # What the commands call "ours": registered, carrying the marker, by name -
    # the filter every list applies before showing anything. Their state comes
    # along, from one batched question - wsl --list says what runs, about
    # everyone at once - so a caller never has to ask a second time.
    static [WslInstance[]] Ours() {
        $Running = Get-DistroNames -Running
        $ours = @([WslInstance]::GetAll() | Where-Object { Test-TemplateInstance -Folder $_.Path })
        foreach ($instance in $ours) {
            if ($Running -contains $instance.Name) {
                $instance.State = [WslState]::Running
            } else {
                $instance.State = [WslState]::Stopped
            }
        }
        return @($ours | Sort-Object Name)
    }

    [WslInstance] FindByName([string]$name) {
        return ($this.Instances | Where-Object { $_.Name -eq $name } | Select-Object -First 1)
    }

    [bool] IsNameAvailable([string]$name) {
        return $null -eq $this.FindByName($name)
    }

    # The name rule every command applies: letters, digits, '.', '_' and '-',
    # starting with a letter or a digit.
    [bool] IsNameUsable([string]$name) {
        return [bool]("$name" -match '^[A-Za-z0-9][A-Za-z0-9_.-]*$')
    }

    [bool] IsPathOccupied([string]$path) {
        return (Test-Path $path) -and (@(Get-ChildItem -Path $path -Force).Count -gt 0)
    }

    # =========================================================================
    # FLEET OPERATIONS
    # =========================================================================

    [WslInstance] CreateNew([string]$name, [string]$tarRootfs, [string]$user, [WslTheme]$look) {
        if (-not $this.IsNameUsable($name)) {
            throw "'$name' is not usable as an instance name (letters, digits, '.', '_' and '-' only)."
        }
        if (-not $this.IsNameAvailable($name)) {
            throw "An instance or archive named '$name' already exists."
        }

        $installPath = Join-Path $this.InstancesRoot $name
        if ($this.IsPathOccupied($installPath)) {
            throw "Installation folder '$installPath' already exists and is not empty."
        }

        $newInstance = [WslInstance]::Build($name, $installPath, $tarRootfs, $user, $look)
        $this.Refresh()
        return $newInstance
    }

    [WslInstance] RestoreFromArchive([string]$name) {
        $inst = $this.FindByName($name)
        if (-not $inst -or -not $inst.HasArchive) {
            throw "No archive found for '$name'."
        }
        if (-not $this.IsNameUsable($name)) {
            throw "'$name' is not usable as an instance name."
        }

        $installPath = Join-Path $this.InstancesRoot $name
        if (Test-Path $installPath) {
            throw "A folder with that name already exists: $installPath"
        }

        $restored = [WslInstance]::Restore($inst.ArchivePath, $name, $installPath)
        $this.Refresh()
        return $restored
    }

    [void] StopAll() {
        foreach ($inst in $this.Instances) {
            if ($inst.State -eq [WslState]::Running) {
                $inst.Stop()
            }
        }
    }
}
