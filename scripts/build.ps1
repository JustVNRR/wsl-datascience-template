[CmdletBinding()]
param (
    # An old command line lands in -Ignored, kept only so the refusal below can
    # say so: PowerShell's own binding error would name a parameter and explain
    # nothing.
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$Ignored
)

$ErrorActionPreference = "Stop"

# What the whole family shares: how to tell one of our instances from any other
# registered one. Not a command, and not optional - without it this script
# would build an instance no other command could recognise as ours.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
    exit 1
}
. $InstanceLib

if ($Ignored) {
    Write-Host ""
    Write-Host "[ABORT] This command takes no options." -ForegroundColor (Get-MessageColour error)
    Write-Host "        Run it on its own:  .\wsl.ps1 build" -ForegroundColor (Get-MessageColour hint)
    exit 1
}

# Nerd Font (MesloLGS NF), per-user (HKCU, LocalAppData): no admin needed, and
# the function never throws - the prompt looks worse without the font, and that
# is not a failed deployment.
# Step 0, as a piece of its own: Docker answers before the questions, and a
# docker that does not aborts with nothing confirmed and nothing touched. It
# exits rather than throws - there is nothing to catch above it.
function Assert-DockerReady {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "[ABORT] Docker is not installed, or not on the PATH." -ForegroundColor (Get-MessageColour error)
        Write-Host "        Install Docker Desktop (see Prerequisites in the README), then run this script again." -ForegroundColor (Get-MessageColour hint)
        exit 1
    }

    if (-not (Test-NativeCommand { docker info })) {
        Write-Host ""
        Write-Host "[ABORT] Docker is not responding." -ForegroundColor (Get-MessageColour error)
        Write-Host "        Start Docker Desktop, wait for it to finish starting, then run this script again." -ForegroundColor (Get-MessageColour hint)
        Write-Host "        Nothing was modified." -ForegroundColor (Get-MessageColour muted)
        exit 1
    }
}

# Windows' own list of what is registered, where every decision to erase comes
# from. Its failure is kept apart from its answer: a list that cannot be read
# is not an empty machine. A missing key is not a failure - it is WSL never
# having registered anything here.
function Get-RegisteredDistros {
    $Lxss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    if (-not (Test-Path $Lxss)) { return @() }

    $Found = @()
    foreach ($Key in Get-ChildItem $Lxss -ErrorAction Stop) {
        $Props = Get-ItemProperty $Key.PSPath -ErrorAction Stop
        if ($Props.DistributionName) {
            $Found += [PSCustomObject]@{
                Name = $Props.DistributionName
                Path = ($Props.BasePath -replace '^\\\\\?\\', '').TrimEnd('\')
            }
        }
    }
    return @($Found)
}

# The last look before erasing: the image was built in between, and the machine
# may have moved. A distribution that was never confirmed must not be destroyed,
# a folder that has become another instance's must not be taken with it, and a
# list that cannot be read is a refusal - not an absence. Answers with the
# registration found now, or nothing when the name is free.
function Assert-DestructionStillMatches {
    param([string]$DistroName, [string]$InstallPath, [bool]$ConfirmedDestruction)

    try {
        $Now = @(Get-RegisteredDistros)
    } catch {
        throw "The list of registered WSL distributions cannot be read: refusing to erase anything."
    }

    $Here = $Now | Where-Object { $_.Name -eq $DistroName } | Select-Object -First 1
    if ($Here -and -not $ConfirmedDestruction) {
        throw "'$DistroName' is registered now and was not when the questions were asked: it was never confirmed for destruction."
    }

    $Invader = $Now | Where-Object {
        $_.Name -ne $DistroName -and
        ($_.Path -eq $InstallPath -or $_.Path.StartsWith("$InstallPath\", [System.StringComparison]::OrdinalIgnoreCase))
    } | Select-Object -First 1
    if ($Invader) {
        throw "$InstallPath is now, or holds, the folder of '$($Invader.Name)': erasing it would take that instance with it."
    }

    return $Here
}

# The folder question, whole: the proposal, the three refusals, the folder
# asked again, and the two checks the erasing below depends on. An empty answer
# cancels the run, like the question it replaces.
function Resolve-InstallPath {
    param([string]$DistroName, [string]$Root, [object[]]$Registered)

    $Folder = $Root
    $InstallPath = $null
    while (-not $InstallPath) {
        # A path Windows refuses is a typo, not a reason to stop. The refused
        # characters are spelled out: .NET Framework - 5.1 - threw on them from
        # inside GetFullPath, .NET Core - 7 - walks past them.
        $Full = $null
        $Refused = ($Folder.IndexOfAny([char[]]'"<>|') -ge 0) -or ($Folder -match '[\x00-\x1f]')
        if (-not $Refused) {
            try {
                $Full = [System.IO.Path]::GetFullPath((Join-Path $Folder $DistroName)).TrimEnd('\')
            } catch { }
        }

        # Step 4 erases this path recursively: a folder holding another instance
        # would take that instance with it.
        $Elsewhere = $null
        if ($Full) {
            $Elsewhere = $Registered | Where-Object {
                $_.Name -ne $DistroName -and
                ($_.Path -eq $Full -or $_.Path.StartsWith("$Full\", [System.StringComparison]::OrdinalIgnoreCase))
            } | Select-Object -First 1
        }

        # The rebuild is the only case where this folder is ours to erase, and
        # the instance's own name is what says so.
        $ItsOwn = $Registered | Where-Object { $_.Name -eq $DistroName -and $_.Path -eq $Full } | Select-Object -First 1
        $Occupied = $false
        if ($Full -and (Test-Path $Full) -and (-not $ItsOwn)) {
            $Occupied = @(Get-ChildItem -Path $Full -Force -ErrorAction SilentlyContinue).Count -gt 0
        }

        if (-not $Full) {
            Write-Host "  '$Folder' is not a usable path." -ForegroundColor (Get-MessageColour warning)
        } elseif ($Elsewhere) {
            Write-Host "  $Full is, or holds, the folder of '$($Elsewhere.Name)'." -ForegroundColor (Get-MessageColour warning)
            Write-Host "  Erasing it would take that instance with it." -ForegroundColor (Get-MessageColour warning)
        } elseif ($Occupied) {
            Write-Host "  $Full already exists, please choose another location." -ForegroundColor (Get-MessageColour warning)
        } else {
            # Shown before it is created; a no is a change of mind about the
            # location - nothing has been written yet.
            $Answer = [string](Read-Host "Create [$Full]? [Y/n]")
            if ($Answer -notmatch "^[nN]") {
                $InstallPath = $Full
                continue
            }
        }

        # Another folder, asked the same way; an empty answer cancels.
        $Answer = [string](Read-Host "Folder for '$DistroName' (or Enter to cancel)")
        if ([string]::IsNullOrWhiteSpace($Answer)) {
            Write-Host ""
            Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor (Get-MessageColour success)
            exit 0
        }
        $Folder = $Answer.Trim()
    }
    return $InstallPath
}

# The deployment's steps, named one by one: each goes through the checked
# wrapper, so a program that fails stops the run instead of writing a line the
# script walks past.
function Invoke-DockerBuild {
    param([string]$Tag)
    Invoke-NativeCommand { docker build -t $Tag . } "Docker build failed."
}

function New-DockerContainer {
    param([string]$Name, [string]$Image)
    Invoke-NativeCommand { docker create --name $Name $Image } "Container creation failed."
}

function Export-DockerContainer {
    param([string]$Container, [string]$OutputPath)
    Invoke-NativeCommand { docker export -o $OutputPath $Container } "Docker export failed."
}

function Stop-WslDistro {
    param([string]$Name)
    Invoke-NativeCommand { wsl.exe --terminate $Name } "Could not stop '$Name'." -SuppressOutput
}

function Invoke-WslFirstBoot {
    param([string]$DistroName)
    Invoke-NativeCommand { wsl.exe -d $DistroName -u root /root/first_boot.sh } "The first_boot.sh configuration script failed."
}

# The user the instance will open as: read from the file the bootstrap wrote,
# the file then taken away - the answer and the cleanup both read, not assumed.
function Get-ConfiguredWslUser {
    param([string]$DistroName)

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $Answer = wsl.exe -d $DistroName -u root cat /tmp/installed_user 2>$null
    $ExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousEAP

    $User = "$Answer".Trim()
    if ($ExitCode -ne 0 -or -not $User) {
        throw "The onboarding script did not say which user it configured."
    }
    Invoke-NativeCommand { wsl.exe -d $DistroName -u root rm -f /tmp/installed_user } `
        "Could not remove the temporary file in '$DistroName'." -SuppressOutput
    return $User
}

# Best effort, and nothing here may raise: the finally block calls this after a
# failure, and an error raised here would bury the message the catch has
# printed. The container may never have existed - removing nothing succeeds.
function Remove-DeploymentArtifacts {
    param([string]$ContainerName, [string]$TarPath)

    $null = Test-NativeCommand { docker rm -f $ContainerName }

    if (Test-Path -Path $TarPath) {
        Remove-Item -Path $TarPath -Force -ErrorAction SilentlyContinue
    }
}

# Step 9 in one place: the icon drawn from the instance's own name, the ghost
# profiles a rebuild orphaned, the fragment this instance is given, and the
# look left in its folder - the file an archive carries. Answers whether a
# profile could be applied at all.
function Configure-TerminalProfile {
    param([string]$DistroName, [string]$InstallPath)

    # The icon is drawn from the instance's own name, letters and colours both.
    # Nothing is said about a drawing that worked. It is decoration: a failure
    # is reported, leaves no file, and the fragment below drops the icon line.
    $IconPath = Join-Path $InstallPath "terminal-icon.png"
    $IconDrawn = $false
    $Icon = @{}
    try {
        # -What: the letters and colours read back into the instance's file, so
        # a later change of one keeps the other.
        $Drawn = & "$RepoRoot\assets\make-icon.ps1" -Name $DistroName -Out $IconPath -Quiet -What | ConvertFrom-Json
        $IconDrawn = $true
        $Icon = @{ Text = $Drawn.Text; Top = $Drawn.Top; Bottom = $Drawn.Bottom; TextColor = $Drawn.TextColor }
    } catch {
        Remove-Item $IconPath -Force -ErrorAction SilentlyContinue
        Write-Host "  * Terminal profile : no icon ($($_.Exception.Message))" -ForegroundColor (Get-MessageColour warning)
    }

    # WSL writes one fragment per import under Fragments\Microsoft.WSL - the
    # guid changes on every rebuild. The shared scan gives this name's guid
    # and the full set of live ones, for the ghost pruning below.
    $Fragments = Get-WslFragmentGuids -Name $DistroName
    $ProfileGuid = $Fragments.Guid
    $LiveGuids = $Fragments.Guids

    # Prune ghost profiles: every rebuild orphans the previous profile into the
    # user's settings.json. This distro's entries matching no live fragment go;
    # an orphan Terminal writes after this point waits for the next build.
    if ($LiveGuids.Count -gt 0) {
        $Ghosts = Remove-TerminalGhostEntries -Name $DistroName -LiveGuids $LiveGuids
        foreach ($Pruned in $Ghosts.Files) {
            Write-Host "  * Terminal profile : pruned $($Pruned.Pruned) ghost '$DistroName' entries from settings.json" -ForegroundColor (Get-MessageColour success)
        }
        foreach ($SettingsPath in $Ghosts.Unreadable) {
            Write-Host "  * Terminal profile : ghost entries NOT pruned in $SettingsPath" -ForegroundColor (Get-MessageColour warning)
            Write-Host "                       (unreadable JSON - a // comment breaks ConvertFrom-Json; remove them by hand)" -ForegroundColor (Get-MessageColour muted)
        }
    }

    # Our own fragment files whose distro no longer exists go too - one file
    # per distro, named <DistroName>.json.
    foreach ($Name in (Remove-StaleAppearanceFragments -LiveGuids $LiveGuids)) {
        Write-Host "  * Terminal profile : removed stale fragment $Name" -ForegroundColor (Get-MessageColour success)
    }

    if ($ProfileGuid) {
        # No icon drawn, no icon line: Terminal shows its own.
        $Theme = [WslTheme]::new($(if ($IconDrawn) { $IconPath } else { "" }), "One Half Dark", "MesloLGS NF", $DistroName)
        Set-InstanceFragment -Name $DistroName -Guid $ProfileGuid -Theme $Theme
        Write-Host "  * Terminal profile applied" -ForegroundColor (Get-MessageColour success)
        $TerminalProfileOk = $true
    } else {
        Write-Host "  * Terminal profile : no WSL fragment found for '$DistroName'; icon not automated" -ForegroundColor (Get-MessageColour warning)
        $TerminalProfileOk = $false
    }

    # What this instance looks like, in its own folder - the file an archive
    # carries. Written here, the fragment in place, so the font and colours it
    # reads are the ones just applied, icon recipe included.
    Set-InstanceLook -InstallPath $InstallPath -Look (New-InstanceLook -Name $DistroName -Icon $Icon)

    return $TerminalProfileOk
}

# The packs, asked earlier and installed now - in a try of their own, because a
# pack that fails must not reach the deployment's catch, which would announce
# "[ERROR] DURING DEPLOYMENT" for an instance that is built, registered and
# usable. Answers the lines to print and the colour they take.
function Install-SelectedPacks {
    param([string]$DistroName, [object]$PackSelection)

    $Report = @()
    $Colour = "Green"
    if ($null -eq $PackSelection) { return @{ Report = $Report; Colour = $Colour } }

    try {
        # Asked of the instance after the install rather than trusted from the
        # answer: a pack whose install failed took its folder back out.
        $NewHome = Get-InstanceHome -DistroName $DistroName
        if (-not $NewHome) { throw "'$DistroName' did not say where its user's home is." }
        $PacksDirectory = "$NewHome/.config/packs"

        Write-Host ""
        Write-Host "==> Installing the packs..." -ForegroundColor (Get-MessageColour info)
        $PackFailure = Invoke-PackApply -DistroName $DistroName -PacksDirectory $PacksDirectory `
            -ToAdd $PackSelection.ToAdd -ResumeHint "Run .\wsl.ps1 manage_packs to finish."

        $PacksNow = @(Get-InstalledPacks -DistroName $DistroName -PacksDirectory $PacksDirectory)
        if ($null -ne $PackFailure) {
            # Three facts, each only when it has something to say: what is
            # really installed, the pack that stopped the run, and the packs
            # that never ran - their folders went back out with it, so they
            # cannot be read as installed anywhere (packs.ps1).
            $Skipped = @($PackSelection.ToAdd |
                Where-Object { $_.Name -ne $PackFailure.Pack -and $PacksNow -notcontains $_.Name } |
                ForEach-Object { $_.Name })

            $Report = @()
            if ($PacksNow.Count -gt 0) {
                $Report += "$($PacksNow -join ', ') successfully installed."
            }
            $Report += "'$($PackFailure.Pack)' installation failed."
            if ($Skipped.Count -gt 0) {
                $Report += "$($Skipped -join ', ') installation skipped."
            }
            $Report += "Run .\wsl.ps1 manage_packs on '$DistroName' to finish."
            $Colour = "Red"
        } else {
            # What is there now, and nothing else: falling back on the names
            # asked for is how a fresh build announced "Packs: claude
            # installed." over an instance whose install had declined.
            $Landed = $PacksNow
            if ($Landed.Count -eq 0) {
                $Report = @("none installed.")
            } else {
                $Report = @("$($Landed -join ', ') installed.")
            }
        }
    } catch {
        $Report = @("not installed - $($_.Exception.Message)")
        $Colour = "Red"
    }
    return @{ Report = $Report; Colour = $Colour }
}

# The Docker Desktop question, moved whole: Docker Desktop injects its docker
# client into the distros it lists and reads that list only when it starts, so
# being in the settings file proves nothing and the question is asked every
# time - it restarts Docker Desktop, so it defaults to yes. Answers the lines
# to print once the shell is open and their colour, or nothing when the user
# said no and there is nothing to say.
function Configure-DockerDesktopIntegration {
    param([string]$DistroName)

    $DockerSettings = Join-Path $env:APPDATA "Docker\settings-store.json"
    if (-not (Test-Path $DockerSettings)) { return $null }

    try {
        Write-Host ""
        $AddToDocker = Read-Host "Restart Docker Desktop to add support for '$DistroName'? [Y/n]"
        if ($AddToDocker -match "^[nN]$") { return $null }

        # The shared recipe: a backup beside the file, the name rebuilt rather
        # than appended twice, and a byte-order-mark-free write - Docker
        # Desktop's file carries none.
        Set-DockerState -Name $DistroName

        if (Test-NativeCommand { docker desktop restart }) {
            # The restart says nothing about what happened inside: the client is
            # injected at Docker Desktop's own pace, and the user can be left
            # without the right to use it - which only shows up in the session
            # this build is about to open. So the thing itself is asked, as the
            # default user and never as root, which would pass whatever the
            # answer is.
            $DockerUsable = $false
            for ($Attempt = 1; $Attempt -le 5 -and -not $DockerUsable; $Attempt++) {
                $DockerUsable = Test-NativeCommand { wsl.exe -d $DistroName -- docker version }
                if (-not $DockerUsable) { Start-Sleep -Seconds 2 }
            }
            if ($DockerUsable) {
                return @{ Lines = @("Docker Desktop: ready - 'docker' works in this instance."); Colour = "Green" }
            }
            return @{
                Lines  = @(
                    "Docker Desktop: 'docker' does not answer in this instance yet.",
                    "  Run 'docker version' in there; if it names the socket's permissions, restart",
                    "  Docker Desktop and open a new terminal."
                )
                Colour = "Yellow"
            }
        }
        return @{ Lines = @("Docker Desktop: not restarted - 'docker' will not work in this instance yet."); Colour = "Yellow" }
    } catch {
        return @{ Lines = @("Docker Desktop: settings not updated - $($_.Exception.Message)"); Colour = "Yellow" }
    }
}

# The repository root, one level above this script: it holds the Dockerfile,
# and that is the context the build below must run in - not this folder.
$RepoRoot = Split-Path -Path $PSScriptRoot -Parent
Set-Location -Path $RepoRoot

$ImageTag = "wsl-stack:latest"
$ContainerName = "wsl-temp-export-$([guid]::NewGuid().ToString().Substring(0, 8))"

# One build at a time: two runs would fight over the same image tag, container,
# tar and distribution name. Taken before anything is asked or created, and let
# go when the deployment ends. A run that stops before that closes it with its
# process; a run already waiting when its holder dies reads it as abandoned and
# takes it (the catch below).
$BuildMutex = [System.Threading.Mutex]::new($false, "Global\wsl-stack-build")
$MutexHeld = $false
try {
    $MutexHeld = $BuildMutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
    $MutexHeld = $true
} catch {
    Write-Host ""
    Write-Host "[ABORT] The build lock cannot be taken - another session may be holding it." -ForegroundColor (Get-MessageColour error)
    Write-Host "        Nothing was modified." -ForegroundColor (Get-MessageColour muted)
    $BuildMutex.Dispose()
    exit 1
}
if (-not $MutexHeld) {
    Write-Host ""
    Write-Host "[ABORT] Another build is already running." -ForegroundColor (Get-MessageColour error)
    Write-Host "        Let it finish, then run this one again." -ForegroundColor (Get-MessageColour hint)
    Write-Host "        Nothing was modified." -ForegroundColor (Get-MessageColour muted)
    $BuildMutex.Dispose()
    exit 1
}

# 0. Preflight: Docker must answer BEFORE the destructive confirmation below -
# failing here aborts with nothing confirmed and nothing touched.
Assert-DockerReady

# 0-bis. What is being built, asked: both answers checked here - before the
# banner and before anything is created. The checks hold on a first build too,
# where no distro exists yet and the banner never shows.
Write-Host ""
Write-Host "==> Creating a new instance" -ForegroundColor (Get-MessageColour info)

$DistroName = $null
while (-not $DistroName) {
    $Answer = [string](Read-Host "Name of the instance (CTRL+C to abort)")
    if ([string]::IsNullOrWhiteSpace($Answer)) {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor (Get-MessageColour success)
        exit 0
    }
    $Answer = $Answer.Trim()
    if ($Answer -match '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
        $DistroName = $Answer
    } else {
        Write-Host "  Letters, digits, '.', '_' and '-' only." -ForegroundColor (Get-MessageColour hint)
    }
}

# Where it will live. The proposal is the folder every command of this family
# writes to, shown and confirmed rather than typed: the folder question is
# there for a second drive, or a folder of your own.
$Root = if (Test-Path "D:\") { "D:\WSL" } else { "$env:USERPROFILE\WSL" }

# What Windows already knows, read once and read strictly: this one list
# answers "is this path another instance's folder" below, "is this name taken"
# for the banner, and "may this still be erased" just before the erasing. A
# list that cannot be read stops the run rather than passing for an empty one.
try {
    $Registered = @(Get-RegisteredDistros)
} catch {
    Write-Host ""
    Write-Host "[ABORT] The list of registered WSL distributions cannot be read." -ForegroundColor (Get-MessageColour error)
    Write-Host "        See what 'wsl --list --verbose' says, then run this script again." -ForegroundColor (Get-MessageColour hint)
    Write-Host "        Nothing was modified." -ForegroundColor (Get-MessageColour muted)
    exit 1
}
$WasRegistered = [bool]($Registered | Where-Object { $_.Name -eq $DistroName } | Select-Object -First 1)

$InstallPath = Resolve-InstallPath -DistroName $DistroName -Root $Root -Registered $Registered

# 1. The export tar lands beside the install path - never on C:.
$ParentInstallDir = Split-Path -Path $InstallPath -Parent
if (-not (Test-Path -Path $ParentInstallDir)) {
    New-Item -ItemType Directory -Path $ParentInstallDir -Force | Out-Null
}
$TarPath = Join-Path -Path $ParentInstallDir -ChildPath "$DistroName-rootfs.tar"

# 2. Safety check: prevent accidental deletion of an existing distribution -
# the list read above already answers it.
if ($WasRegistered) {
    [Console]::Beep(1000, 400)
    Write-Host ""
    Write-DangerBanner
    Write-Host ""
    Write-Host "  A WSL distribution named '$DistroName' ALREADY exists." -ForegroundColor (Get-MessageColour error)
    Write-Host ""
    Write-Host "  Proceeding will PERMANENTLY DESTROY this distribution:" -ForegroundColor (Get-MessageColour warning)
    Write-Host "    - Executing: wsl --unregister $DistroName" -ForegroundColor (Get-MessageColour muted)
    Write-Host "    - Erasing the install folder: $InstallPath" -ForegroundColor (Get-MessageColour muted)
    Write-Host "    - IRREVERSIBLE DELETION of the virtual disk (VHDX)" -ForegroundColor (Get-MessageColour muted)
    Write-Host "    - TOTAL LOSS of projects, SSH keys, and all files in /home" -ForegroundColor (Get-MessageColour muted)
    Write-Host ""
    Write-Host "  THIS OPERATION CANNOT BE UNDONE." -ForegroundColor (Get-MessageColour error)
    Write-Host ""
    Write-Host " ----------------------------------------------------------------------" -ForegroundColor (Get-MessageColour muted)
    Write-Host " Press ENTER to abort immediately." -ForegroundColor (Get-MessageColour hint)
    Write-Host " To confirm DESTRUCTION, type the exact name of the distribution:" -ForegroundColor (Get-MessageColour hint)
    $Confirmation = Read-Host " Confirm"
    Write-Host " ----------------------------------------------------------------------" -ForegroundColor (Get-MessageColour muted)
    Write-Host ""

    # -cne, not -ne: PowerShell's -ne ignores case, while the banner above asks
    # for the exact name. The point is that the name is read and typed, not
    # that a reflexive Enter carries through.
    if ($Confirmation -cne $DistroName) {
        Write-Host "[ABORT] Operation cancelled. No data was modified." -ForegroundColor (Get-MessageColour success)
        exit 0
    }
}

# 0-ter. The packs, asked here with everything else: nothing asks again once
# the machine starts working - the answer waits in a variable and is applied
# below. Empty, or Escape, means none, and the build goes on either way.
$PackSelection = $null
$PackCatalog = Get-PackCatalog
if ($PackCatalog.AvailablePacks.Count -gt 0) {
    # The instance being replaced still exists here: what it carries is what
    # the boxes show. A first build opens on an empty checklist.
    $PreChecked = @()
    if ($WasRegistered) {
        $PreviousHome = Get-InstanceHome -DistroName $DistroName
        if ($PreviousHome) {
            $PreChecked = @(Get-InstalledPacks -DistroName $DistroName -PacksDirectory "$PreviousHome/.config/packs")
        } else {
            Write-Host "  Could not read what '$DistroName' carries: no pack arrives checked." -ForegroundColor (Get-MessageColour warning)
        }
    }

    # -Installed stays at its default: the instance this build makes carries
    # nothing yet - boxes to tick, no removal to compute.
    $PackSelection = Select-Packs -Title "Packs for '$DistroName'" -Catalog $PackCatalog -Checked $PreChecked

    if ($null -eq $PackSelection -or $PackSelection.ToAdd.Count -eq 0) {
        Write-Host ""
        Write-Host "[OK] No pack selected: '$DistroName' will be built without one." -ForegroundColor (Get-MessageColour success)
        $PackSelection = $null
    }
}

# What this run has done, for the finally block and the exit code to read:
# whether the instance that was there went away, whether this run registered
# one, and whether it reached the end. Read from the run rather than asked of
# WSL again - a list that fails to come back must never read as "no
# distribution".
$Deployment = [ordered]@{
    OldDistroRemoved = $false
    DistroRegistered = $false
    Succeeded        = $false
}

try {
    Write-Host "==> 1. Building Docker rootfs image..." -ForegroundColor (Get-MessageColour info)
    Invoke-DockerBuild -Tag $ImageTag

    Write-Host "==> 2. Creating temporary export container..." -ForegroundColor (Get-MessageColour info)
    New-DockerContainer -Name $ContainerName -Image $ImageTag

    Write-Host "==> 3. Exporting filesystem to temporary archive ($TarPath)..." -ForegroundColor (Get-MessageColour info)
    Export-DockerContainer -Container $ContainerName -OutputPath $TarPath

    Write-Host "==> 4. Preparing installation folder: $InstallPath" -ForegroundColor (Get-MessageColour info)
    
    # The image was built and exported in between: the machine may have moved.
    # The last look before anything is erased - an answer that cannot be
    # trusted stops the run.
    $StillRegistered = Assert-DestructionStillMatches -DistroName $DistroName `
        -InstallPath $InstallPath -ConfirmedDestruction $WasRegistered

    if ($StillRegistered) {
        Stop-WslDistro -Name $DistroName
        Start-Sleep -Seconds 1
        Invoke-NativeCommand { wsl.exe --unregister $DistroName } "Could not unregister '$DistroName'." -SuppressOutput
        $Deployment.OldDistroRemoved = $true
    }

    if (Test-Path -Path $InstallPath) {
        Remove-Item -Recurse -Force $InstallPath
    }
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

    Write-Host "==> 5. Importing into WSL ($DistroName)..." -ForegroundColor (Get-MessageColour info)
    # The import and the marker in one gesture, on the model: the instance is
    # marked the moment it is registered, before the steps that can still
    # fail - a build that stops at the font step leaves a real instance
    # behind, not an invisible one.
    $Instance = [WslInstance]::Build($DistroName, $InstallPath, $TarPath, "", $null)
    $Deployment.DistroRegistered = $true

    Write-Host "==> 6. Running initial onboarding setup..." -ForegroundColor (Get-MessageColour info)
    Invoke-WslFirstBoot -DistroName $DistroName
    $ConfiguredUser = Get-ConfiguredWslUser -DistroName $DistroName

    Write-Host "==> 7. Shutting down distro to persist systemd and user configuration..." -ForegroundColor (Get-MessageColour info)
    Stop-WslDistro -Name $DistroName

    Write-Host "==> 8. Checking Windows Terminal Font compatibility..." -ForegroundColor (Get-MessageColour info)
    # The font every look starts from: present, installed here, or beyond this
    # build's reach - the three news there are. Best effort either way.
    if (-not $Instance.FontMissing()) {
        Write-Host "  * Font Status       : " -NoNewline; Write-Host "Compatible Nerd Font detected (MesloLGS NF)." -ForegroundColor (Get-MessageColour success)
    } else {
        Write-Host "==> Starship prompt requires a Nerd Font. Downloading MesloLGS NF..." -ForegroundColor (Get-MessageColour info)
        $FontStatus = $Instance.EnsureFont()
        if ($FontStatus.State -eq "installed") {
            Write-Host "  * Font Status       : " -NoNewline; Write-Host "Successfully installed MesloLGS NF for current user." -ForegroundColor (Get-MessageColour success)
        } else {
            Write-Host "  * Font Status       : " -NoNewline; Write-Host "Could not auto-install font: $($FontStatus.Error)" -ForegroundColor (Get-MessageColour error)
        }
    }

    Write-Host "==> 9. Configuring the Windows Terminal profile (icon, font, color scheme, tab title)..." -ForegroundColor (Get-MessageColour info)
    $TerminalProfileOk = Configure-TerminalProfile -DistroName $DistroName -InstallPath $InstallPath

    # Terminal is asked to look again: the new profile appears without closing.
    Update-TerminalSettings

    # Installed after the instance exists; the news lands in the summary below
    # and on the screen the shell opens on.
    $PackResult = Install-SelectedPacks -DistroName $DistroName -PackSelection $PackSelection
    $PackReport = $PackResult.Report
    $PackReportColour = $PackResult.Colour

    Clear-Host
    Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
    Write-Host "         WSL Stack Instance Successfully Deployed!          " -ForegroundColor (Get-MessageColour success)
    Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
    Write-Host ""
    Write-Host "  * Distribution Name : " -NoNewline; Write-Host "$DistroName" -ForegroundColor (Get-MessageColour info)
    Write-Host "  * Default User      : " -NoNewline; Write-Host "$ConfiguredUser" -ForegroundColor (Get-MessageColour info)
    Write-Host "  * Install Path      : " -NoNewline; Write-Host "$InstallPath" -ForegroundColor (Get-MessageColour muted)
    Write-Host "  * Terminal profile  : " -NoNewline
    if ($TerminalProfileOk) {
        Write-Host "icon, font, color scheme, tab title" -ForegroundColor (Get-MessageColour success)
    } else {
        Write-Host "not automated - configure the appearance manually (Ctrl+,)" -ForegroundColor (Get-MessageColour hint)
    }
    Write-Host "  * Packs             : " -NoNewline
    if ($PackReport.Count -eq 0) {
        Write-Host "none" -ForegroundColor "DarkGray"
    } else {
        Write-Host "$($PackReport[0])" -ForegroundColor $PackReportColour
        foreach ($Line in @($PackReport | Select-Object -Skip 1)) {
            Write-Host "$(' ' * 24)$Line" -ForegroundColor $PackReportColour
        }
    }
    Write-Host ""

    Write-Host "------------------------------------------------------------" -ForegroundColor (Get-MessageColour muted)
    Write-Host "To launch your session, run:" -ForegroundColor (Get-MessageColour hint)
    Write-Host "  wsl -d $DistroName" -ForegroundColor (Get-MessageColour hint)
    Write-Host "------------------------------------------------------------" -ForegroundColor (Get-MessageColour muted)
    Write-Host ""

    $Deployment.Succeeded = $true
}
catch {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor (Get-MessageColour error)
    Write-Host " [ERROR] DURING DEPLOYMENT" -ForegroundColor (Get-MessageColour error)
    Write-Host "============================================================" -ForegroundColor (Get-MessageColour error)
    Write-Host $_.Exception.Message -ForegroundColor (Get-MessageColour error)
    Write-Host ""
}
finally {
    Write-Host "==> Cleaning up temporary build artifacts..." -ForegroundColor (Get-MessageColour info)

    Remove-DeploymentArtifacts -ContainerName $ContainerName -TarPath $TarPath

    if ($Deployment.Succeeded) {
        Write-Host ""
        Write-Host ("-" * 60) -ForegroundColor (Get-MessageColour muted)
        $KeepDockerImage = Read-Host "Keep Docker image [Y/n]?"

        if ($KeepDockerImage -match "^[nN]$") {
            Write-Host "==> Removing Docker image '$ImageTag'..." -ForegroundColor (Get-MessageColour info)
            if (Test-NativeCommand { docker rmi -f $ImageTag }) {
                Write-Host "Docker image removed." -ForegroundColor (Get-MessageColour success)
            } else {
                Write-Host "The image could not be removed - a container is probably using it. It stays on disk." -ForegroundColor (Get-MessageColour warning)
            }
        } else {
            Write-Host "Docker image retained." -ForegroundColor (Get-MessageColour success)
        }
    } else {
        # Nothing was deployed: the image is what a retry starts from, and there
        # is no deployment to ask about. The retry is only cheap while the run
        # stopped before the import - past that point a distro exists, and the
        # next run opens on the destruction prompt instead.
        Write-Host ""
        Write-Host ("-" * 60) -ForegroundColor (Get-MessageColour muted)
        # Read off the run rather than asked of WSL again: a list that fails to
        # come back must never read as "no distribution".
        $RegisteredNow = $Deployment.DistroRegistered -or ($WasRegistered -and (-not $Deployment.OldDistroRemoved))
        if ($RegisteredNow) {
            Write-Host "A distribution named '$DistroName' is registered: the next run will offer to destroy and rebuild it." -ForegroundColor (Get-MessageColour warning)
        } else {
            Write-Host "The Docker image was kept: the next run reuses it and rebuilds only what changed." -ForegroundColor (Get-MessageColour muted)
        }

        # The packs were chosen before the machine started; the deployment
        # stopped before they could be installed, and the variable still says
        # which ones, so the news is exact rather than a guess.
        if ($null -ne $PackSelection) {
            $WantedPacks = ($PackSelection.ToAdd | ForEach-Object { $_.Name }) -join ", "
            Write-Host "The packs chosen earlier ($WantedPacks) were not installed: the build stopped before them." -ForegroundColor (Get-MessageColour warning)
            if ($RegisteredNow) {
                Write-Host "Once it is usable, .\wsl.ps1 manage_packs installs them in it." -ForegroundColor (Get-MessageColour muted)
            }
        }
    }

    if ($MutexHeld) {
        $BuildMutex.ReleaseMutex()
    }
    $BuildMutex.Dispose()
}

if ($Deployment.Succeeded) {
    # The report waits for the screen the shell opens on: the Clear-Host below
    # wipes everything written before it, and an answer nobody reads is not an
    # answer.
    $DockerReport = $null
    $DockerReportColour = "Yellow"
    $Docker = Configure-DockerDesktopIntegration -DistroName $DistroName
    if ($Docker) {
        $DockerReport = $Docker.Lines
        $DockerReportColour = $Docker.Colour
    }

    # The shell the user came for, in the fresh instance - the instance's own
    # gesture, the same one the shell command uses. Two lines first, so it
    # opens on "who am I, where, and what now" instead of an anonymous prompt.
    #
    # A pack's welcome line (scaffold's points at fnew) comes from its own
    # pack.conf: no sentence of this script names a pack or a command.
    Clear-Host
    Write-Host "Welcome, $ConfiguredUser." -ForegroundColor (Get-MessageColour success)
    Write-Host "You are now logged in to $DistroName." -ForegroundColor (Get-MessageColour success)
    if ($null -ne $PackSelection) {
        foreach ($Pack in $PackSelection.ToAdd) {
            if ($Pack.Welcome) { Write-Host $Pack.Welcome -ForegroundColor (Get-MessageColour hint) }
        }
    }
    if ($PackReport) {
        Write-Host "Packs: $($PackReport[0])" -ForegroundColor $PackReportColour
        foreach ($Line in @($PackReport | Select-Object -Skip 1)) {
            Write-Host "       $Line" -ForegroundColor $PackReportColour
        }
    }
    if ($DockerReport) {
        foreach ($Line in $DockerReport) { Write-Host $Line -ForegroundColor $DockerReportColour }
    }
    Write-Host ""
    $null = $Instance.Shell()
}

# A failed deployment must not look like a success to whatever called this
# script - a shortcut, a wrapper, a future CI job.
if (-not $Deployment.Succeeded) { exit 1 }
