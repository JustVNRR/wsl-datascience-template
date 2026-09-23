[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$DistroName = "ubuntu-datascience-build",

    [Parameter(Mandatory = $false)]
    [string]$InstallPath
)

# Dynamically set the install path if not provided by the user
if (-not $InstallPath) {
    if (Test-Path "D:\") {
        $InstallPath = "D:\WSL\$DistroName"
    } else {
        # Fallback to the C: drive in the user's profile
        $InstallPath = "$env:USERPROFILE\WSL\$DistroName"
    }
}

$ErrorActionPreference = "Stop"

# What the whole family shares: how to tell one of our instances from any other
# registered one. Not a command, and not optional - without it this script
# would build an instance no other command could recognise as ours.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

# Halts script execution if an external command (like docker or wsl) fails
function Invoke-External {
    param([scriptblock]$Command, [string]$ErrorMessage)
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$ErrorMessage (Exit code: $LASTEXITCODE)"
    }
}

# Detects and silently installs a compatible Nerd Font (MesloLGS NF) for the current user.
# Uses CurrentUser scope (HKCU and LocalAppData) to completely bypass the need for Administrator privileges.
# Returns $true if the font is already configured, or $false if user action is required.
function Install-NerdFont {
    $FontName = "MesloLGS NF"
    $FontFile = "MesloLGS NF Regular.ttf"
    
    # 1. Check HKCU (Current User Registry) instead of HKLM (System Registry)
    $FontRegPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    
    # Ensure registry path exists just in case
    if (-not (Test-Path $FontRegPath)) {
        New-Item -Path $FontRegPath -Force | Out-Null
    }
    
    $FontsInReg = Get-ItemProperty -Path $FontRegPath -ErrorAction SilentlyContinue | Select-Object -Property *
    
    $IsFontInstalled = $false
    if ($FontsInReg) {
        foreach ($Property in $FontsInReg.psobject.properties) {
            if ($Property.Name -match $FontName) {
                $IsFontInstalled = $true
                break
            }
        }
    }

    if ($IsFontInstalled) {
        Write-Host "  * Font Status       : " -NoNewline; Write-Host "Compatible Nerd Font detected ($FontName)." -ForegroundColor Green
        return $true
    }

    Write-Host "==> Starship prompt requires a Nerd Font. Downloading $FontName..." -ForegroundColor Yellow

    # 2. Download, then install the font PER-USER (no admin required). Both are
    # best effort: the prompt looks worse without the font, but neither a download
    # that fails nor a registry that refuses may turn a finished deployment into
    # a failed one - this function never throws.
    try {
        $FontUrl = "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        $TempFontPath = Join-Path $env:TEMP $FontFile
        Invoke-WebRequest -Uri $FontUrl -OutFile $TempFontPath -UseBasicParsing

        $UserFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"

        # Create user fonts directory if it doesn't exist
        if (-not (Test-Path $UserFontsDir)) {
            New-Item -ItemType Directory -Path $UserFontsDir -Force | Out-Null
        }

        $DestFontPath = Join-Path $UserFontsDir $FontFile

        # The file and its registry entry are two separate facts: an interrupted
        # run leaves one without the other. Guarding both with the same test
        # skipped the registration, and Windows Terminal then asked for a font
        # Windows did not know about - boxes in the prompt, and no message.
        if (-not (Test-Path $DestFontPath)) {
            Copy-Item -Path $TempFontPath -Destination $DestFontPath -Force
        }
        if (-not (Get-ItemProperty -Path $FontRegPath -Name "$FontName (TrueType)" -ErrorAction SilentlyContinue)) {
            New-ItemProperty -Path $FontRegPath -Name "$FontName (TrueType)" -Value $DestFontPath -PropertyType String -Force | Out-Null
        }
        Write-Host "  * Font Status       : " -NoNewline; Write-Host "Successfully installed $FontName for current user." -ForegroundColor Green
        return $false
    } catch {
        Write-Host "  * Font Status       : " -NoNewline; Write-Host "Could not auto-install font: $_" -ForegroundColor Red
        return $false
    }
}

# The repository root, one level above this script: it holds the Dockerfile,
# and that is the context the build below must run in - not this folder.
$RepoRoot = Split-Path -Path $PSScriptRoot -Parent
Set-Location -Path $RepoRoot

$ImageTag = "wsl-datascience-template:latest"
$ContainerName = "wsl-temp-export-$([guid]::NewGuid().ToString().Substring(0, 8))"

# 0. Preflight: Docker must answer BEFORE the destructive confirmation below,
# which asks the user to type the distro name. Failing here aborts cleanly,
# with nothing confirmed and nothing touched.
# "Continue" + "*> $null" is deliberate: under $ErrorActionPreference = "Stop",
# docker's stderr becomes a TERMINATING error, and a plain 2>$null does not
# silence it - the user would see a raw daemon error instead of this message.
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "[ABORT] Docker is not installed, or not on the PATH." -ForegroundColor Red
    Write-Host "        Install Docker Desktop (see Prerequisites in the README), then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "==> 0. Checking Docker..." -ForegroundColor Cyan
$PreviousEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$null = docker info *> $null
$DockerExitCode = $LASTEXITCODE
$ErrorActionPreference = $PreviousEAP

if ($DockerExitCode -ne 0) {
    Write-Host ""
    Write-Host "[ABORT] Docker is not responding." -ForegroundColor Red
    Write-Host "        Start Docker Desktop, wait for it to finish starting, then run this script again." -ForegroundColor Yellow
    Write-Host "        Nothing was modified." -ForegroundColor DarkGray
    exit 1
}

# 0-bis. Preflight: -InstallPath must be a folder of its own. The deletion in
# step 4 is recursive, so a forgotten name - `-InstallPath "D:\WSL"` - would
# take every distribution installed under it. Checked here, before the
# confirmation below and before anything is created, like the Docker probe:
# this must hold on a first build too, where no distro exists yet and the
# banner never shows.
$FullInstallPath = [System.IO.Path]::GetFullPath($InstallPath).TrimEnd('\')

if ($FullInstallPath -match '^[A-Za-z]:$') {
    Write-Host ""
    Write-Host "[ABORT] -InstallPath must name a folder, not a drive root: $InstallPath" -ForegroundColor Red
    Write-Host "        Nothing was modified." -ForegroundColor DarkGray
    exit 1
}

foreach ($Key in Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss -ErrorAction SilentlyContinue) {
    $Props = Get-ItemProperty $Key.PSPath
    if ($Props.DistributionName -and $Props.DistributionName -ne $DistroName -and $Props.BasePath) {
        $OtherPath = ($Props.BasePath -replace '^\\\\\?\\', '').TrimEnd('\')
        if ($OtherPath -eq $FullInstallPath -or $OtherPath.StartsWith("$FullInstallPath\", [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Host ""
            Write-Host "[ABORT] $InstallPath is, or contains, the install folder of '$($Props.DistributionName)'." -ForegroundColor Red
            Write-Host "        Erasing it would take that distribution with it: $OtherPath" -ForegroundColor Yellow
            Write-Host "        Give -InstallPath a folder of its own." -ForegroundColor Yellow
            Write-Host "        Nothing was modified." -ForegroundColor DarkGray
            exit 1
        }
    }
}

# 1. Place temporary export tar next to InstallPath to prevent filling drive C:
$ParentInstallDir = Split-Path -Path $InstallPath -Parent
if (-not (Test-Path -Path $ParentInstallDir)) {
    New-Item -ItemType Directory -Path $ParentInstallDir -Force | Out-Null
}
$TarPath = Join-Path -Path $ParentInstallDir -ChildPath "$DistroName-rootfs.tar"

# 2. Safety check: prevent accidental deletion of existing distro
# Strip out potential UTF-16 null characters (`0) returned by wsl.exe
$ExistingDistros = (wsl.exe --list --quiet 2>$null) | ForEach-Object { ($_ -replace "`0", "").Trim() }

if ($ExistingDistros -contains $DistroName) {
    [Console]::Beep(1000, 400)
    Write-Host ""
    Write-Host " /!\ ================================================================ /!\" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host " |                     DANGER: TOTAL DATA LOSS IMMINENT               |" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host " \!/ ================================================================ \!/" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host ""
    Write-Host "  A WSL distribution named '$DistroName' ALREADY exists." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Proceeding will PERMANENTLY DESTROY this distribution:" -ForegroundColor Yellow
    Write-Host "    - Executing: wsl --unregister $DistroName" -ForegroundColor DarkGray
    Write-Host "    - Erasing the install folder: $InstallPath" -ForegroundColor DarkGray
    Write-Host "    - IRREVERSIBLE DELETION of the virtual disk (VHDX)" -ForegroundColor DarkGray
    Write-Host "    - TOTAL LOSS of projects, SSH keys, and all files in /home" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  THIS OPERATION CANNOT BE UNDONE." -ForegroundColor Red
    Write-Host ""
    Write-Host " ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " Press ENTER to abort immediately." -ForegroundColor Yellow
    Write-Host " To confirm DESTRUCTION, type the exact name of the distribution:" -ForegroundColor Yellow
    $Confirmation = Read-Host " Confirm"
    Write-Host " ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    # -cne, not -ne: PowerShell's -ne ignores case, while the banner above asks
    # for the exact name. The point is that the name is read and typed, not
    # that a reflexive Enter carries through.
    if ($Confirmation -cne $DistroName) {
        Write-Host "[ABORT] Operation cancelled. No data was modified." -ForegroundColor Green
        exit 0
    }
}

# Set once the distro is registered. The finally block reads it to tell a
# deployment from a failure, and the exit code below is derived from it.
$Deployed = $false

try {
    Write-Host "==> 1. Building Docker rootfs image..." -ForegroundColor Cyan
    Invoke-External { docker build -t $ImageTag . } "Docker build failed."

    Write-Host "==> 2. Creating temporary export container..." -ForegroundColor Cyan
    Invoke-External { docker create --name $ContainerName $ImageTag } "Container creation failed."

    Write-Host "==> 3. Exporting filesystem to temporary archive ($TarPath)..." -ForegroundColor Cyan
    Invoke-External { docker export -o $TarPath $ContainerName } "Docker export failed."

    Write-Host "==> 4. Preparing installation folder: $InstallPath" -ForegroundColor Cyan
    # Same trap as the Docker probe above: 2>$null does not silence wsl.exe,
    # which writes a mojibake UTF-16 error whenever the distro does not exist
    # yet - i.e. on every first build. The exit code is ignored on purpose.
    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $null = wsl.exe --unregister $DistroName *> $null
    $ErrorActionPreference = $PreviousEAP
    if (Test-Path -Path $InstallPath) {
        Remove-Item -Recurse -Force $InstallPath
    }
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

    Write-Host "==> 5. Importing into WSL ($DistroName)..." -ForegroundColor Cyan
    Invoke-External { wsl.exe --import $DistroName $InstallPath $TarPath --version 2 } "WSL import failed."

    # Marked the moment it is registered, before the steps that can still fail:
    # from here on the instance exists and is ours, and the other commands have
    # to be able to see it - a build that stops at the font step leaves a real
    # instance behind, not an invisible one.
    New-InstanceMarker -Folder $InstallPath -By "build"

    Write-Host "==> 6. Running initial onboarding setup..." -ForegroundColor Cyan
    Invoke-External { wsl.exe -d $DistroName -u root /root/first_boot.sh } "The first_boot.sh configuration script failed."

    # Retrieve configured username from temporary file
    $ConfiguredUser = (wsl.exe -d $DistroName -u root cat /tmp/installed_user).Trim()
    wsl.exe -d $DistroName -u root rm -f /tmp/installed_user

    Write-Host "==> 7. Shutting down distro to persist systemd and user configuration..." -ForegroundColor Cyan
    wsl.exe --terminate $DistroName

    Write-Host "==> 8. Checking Windows Terminal Font compatibility..." -ForegroundColor Cyan
    # The function prints its own status line; discard the boolean it returns
    # (a bare call would print True/False to the console).
    Install-NerdFont | Out-Null

    Write-Host "==> 9. Configuring the Windows Terminal profile (icon, font, color scheme, tab title)..." -ForegroundColor Cyan
    Copy-Item "$RepoRoot\assets\terminal-icon.png" "$InstallPath\terminal-icon.png" -Force

    # Find the distro's Terminal profile GUID: WSL writes one fragment file per
    # import under Fragments\Microsoft.WSL (named {guid}.json, containing the
    # profile) - the guid changes on every rebuild. Scan newest-first and keep
    # the full set of live guids for the ghost pruning below.
    $WslFragmentsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Microsoft.WSL"
    $ProfileGuid = $null
    $LiveGuids = @()
    if (Test-Path $WslFragmentsDir) {
        foreach ($File in (Get-ChildItem $WslFragmentsDir -Filter *.json | Sort-Object LastWriteTime -Descending)) {
            try {
                $Fragment = Get-Content $File.FullName -Raw | ConvertFrom-Json
                foreach ($Entry in $Fragment.profiles) {
                    if ($Entry.guid) { $LiveGuids += $Entry.guid }
                    if (-not $ProfileGuid -and $Entry.name -eq $DistroName -and $Entry.guid) { $ProfileGuid = $Entry.guid }
                }
            } catch { }
        }
    }

    $OurFragmentDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-datascience-template"

    # Prune ghost profiles: every rebuild orphans the previous profile into the
    # user's settings.json (Terminal persists it when its source disappears).
    # Remove this distro's entries that match no live WSL fragment. If Terminal
    # writes the newest orphan after this point, the next build cleans it up.
    if ($LiveGuids.Count -gt 0) {
        foreach ($SettingsPath in @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        )) {
            if (-not (Test-Path $SettingsPath)) { continue }
            try {
                $Settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
                $All = @($Settings.profiles.list)
                $Kept = @($All | Where-Object { -not ($_.source -eq "Microsoft.WSL" -and $_.name -eq $DistroName -and $LiveGuids -notcontains $_.guid) })
                if ($Kept.Count -ne $All.Count) {
                    Copy-Item $SettingsPath "$SettingsPath.bak" -Force
                    $Settings.profiles.list = $Kept
                    $Settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding Utf8
                    Write-Host "  * Terminal profile : pruned $($All.Count - $Kept.Count) ghost '$DistroName' entries from settings.json" -ForegroundColor Green
                }
            } catch {
                Write-Host "  * Terminal profile : ghost entries NOT pruned in $SettingsPath" -ForegroundColor Yellow
                Write-Host "                       (unreadable JSON - a // comment breaks ConvertFrom-Json; remove them by hand)" -ForegroundColor DarkGray
            }
        }
    }

    # Prune our own fragment files whose distro no longer exists (same rule:
    # the target guid must be live). One file per distro, named <DistroName>.json,
    # so several distros can carry the template appearance side by side.
    if ((Test-Path $OurFragmentDir) -and ($LiveGuids.Count -gt 0)) {
        foreach ($File in (Get-ChildItem $OurFragmentDir -Filter *.json)) {
            try {
                $Fragment = Get-Content $File.FullName -Raw | ConvertFrom-Json
                $Target = ($Fragment.profiles | Where-Object { $_.updates } | Select-Object -First 1).updates
                if ($Target -and ($LiveGuids -notcontains $Target)) {
                    Remove-Item $File.FullName -Force
                    Write-Host "  * Terminal profile : removed stale fragment $($File.Name)" -ForegroundColor Green
                }
            } catch { }
        }
    }

    if ($ProfileGuid) {
        $IconPath = Join-Path $InstallPath "terminal-icon.png"
        New-Item -ItemType Directory -Force $OurFragmentDir | Out-Null
        # Layered over WSL's own profile via "updates"; the user's settings.json
        # is never touched. UTF-8 matters: PowerShell's default encoding is not.
        $FragmentJson = @"
{
    "profiles": [
        {
            "updates": "$ProfileGuid",
            "icon": "$($IconPath -replace '\\','\\')",
            "font": { "face": "MesloLGS NF" },
            "colorScheme": "One Half Dark",
            "suppressApplicationTitle": true
        }
    ]
}
"@
        Set-Content -Path (Join-Path $OurFragmentDir "$DistroName.json") -Value $FragmentJson -Encoding Utf8
        Write-Host "  * Terminal profile : icon + font + color scheme + tab title applied (profile $ProfileGuid)" -ForegroundColor Green
        $TerminalProfileOk = $true
    } else {
        Write-Host "  * Terminal profile : no WSL fragment found for '$DistroName'; icon not automated" -ForegroundColor Yellow
        $TerminalProfileOk = $false
    }

    Clear-Host
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "       WSL Data Science Instance Successfully Deployed!     " -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  * Distribution Name : " -NoNewline; Write-Host "$DistroName" -ForegroundColor Cyan
    Write-Host "  * Default User      : " -NoNewline; Write-Host "$ConfiguredUser" -ForegroundColor Cyan
    Write-Host "  * Install Path      : " -NoNewline; Write-Host "$InstallPath" -ForegroundColor DarkGray
    Write-Host "  * Terminal profile  : " -NoNewline
    if ($TerminalProfileOk) {
        Write-Host "icon, font, color scheme, tab title (restart Windows Terminal to load)" -ForegroundColor Green
    } else {
        Write-Host "not automated - configure the appearance manually (Ctrl+,)" -ForegroundColor Yellow
    }
    Write-Host ""

    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "To launch your session, run:" -ForegroundColor Yellow
    Write-Host "  wsl -d $DistroName" -ForegroundColor White
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    $Deployed = $true
}
catch {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host " [ERROR] DURING DEPLOYMENT" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
}
finally {
    Write-Host "==> Cleaning up temporary build artifacts..." -ForegroundColor Yellow

    # The trap of step 0 again: under $ErrorActionPreference = "Stop" docker
    # writes its errors as TERMINATING ones, and one raised here would bury the
    # message the catch block has just printed.
    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    docker rm -f $ContainerName *> $null
    $ErrorActionPreference = $PreviousEAP

    if (Test-Path -Path $TarPath) {
        Remove-Item -Path $TarPath -Force -ErrorAction SilentlyContinue
    }

    if ($Deployed) {
        # Prompt whether to retain or purge the local Docker image
        Write-Host ""
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        $KeepDockerImage = Read-Host "Keep Docker image [Y/n]?"

        if ($KeepDockerImage -match "^[nN]$") {
            Write-Host "==> Removing Docker image '$ImageTag'..." -ForegroundColor Yellow
            $PreviousEAP = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            docker rmi -f $ImageTag *> $null
            $RemoveExitCode = $LASTEXITCODE
            $ErrorActionPreference = $PreviousEAP
            if ($RemoveExitCode -eq 0) {
                Write-Host "Docker image removed." -ForegroundColor Green
            } else {
                Write-Host "The image could not be removed - a container is probably using it. It stays on disk." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Docker image retained." -ForegroundColor Green
        }
    } else {
        # Nothing was deployed: the image is what a retry starts from, and there
        # is no deployment to ask about. The retry is only cheap while the run
        # stopped before the import - past that point a distro exists, and the
        # next run opens on the destruction prompt instead.
        Write-Host ""
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        $StillRegistered = (wsl.exe --list --quiet 2>$null) | ForEach-Object { ($_ -replace "`0", "").Trim() }
        if ($StillRegistered -contains $DistroName) {
            Write-Host "A distribution named '$DistroName' is registered: the next run will offer to destroy and rebuild it." -ForegroundColor Yellow
        } else {
            Write-Host "The Docker image was kept: the next run reuses it and rebuilds only what changed." -ForegroundColor DarkGray
        }
    }
}

# Docker Desktop injects its docker client into the distros it lists, and reads
# that list only when it starts. Being in that list proves nothing: a rebuild
# takes the client away and leaves the name behind. So the question is asked
# every time rather than answered from the file - and it belongs to another
# program, which is why it is asked rather than assumed. It restarts Docker
# Desktop, so it defaults to yes and Enter carries through.
if ($Deployed) {
    $DockerSettings = Join-Path $env:APPDATA "Docker\settings-store.json"
    if (Test-Path $DockerSettings) {
        try {
            Write-Host ""
            $AddToDocker = Read-Host "Restart Docker Desktop to add support for '$DistroName'? [Y/n]"
            if ($AddToDocker -notmatch "^[nN]$") {
                $DockerConfig = Get-Content $DockerSettings -Raw | ConvertFrom-Json
                Copy-Item $DockerSettings "$DockerSettings.bak" -Force
                # Rebuilt without this distro and without empty entries, then
                # appended once: a name already there would be added twice.
                $DockerConfig.IntegratedWslDistros =
                    @($DockerConfig.IntegratedWslDistros | Where-Object { $_ -and $_ -ne $DistroName }) + $DistroName
                # Written beside the file and swapped in, so an interrupted
                # write cannot leave Docker Desktop with half a JSON - and with
                # WriteAllText rather than Set-Content, because PowerShell's
                # -Encoding Utf8 prepends a byte-order mark that this file,
                # written by Docker Desktop, does not carry.
                $DockerJson = ($DockerConfig | ConvertTo-Json -Depth 10) -replace "`r`n", "`n"
                [System.IO.File]::WriteAllText("$DockerSettings.tmp", $DockerJson, (New-Object System.Text.UTF8Encoding($false)))
                Move-Item "$DockerSettings.tmp" $DockerSettings -Force

                $PreviousEAP = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                $null = docker desktop restart *> $null
                $DockerExitCode = $LASTEXITCODE
                $ErrorActionPreference = $PreviousEAP

                if ($DockerExitCode -eq 0) {
                    Write-Host "Docker Desktop successfully restarted." -ForegroundColor Green
                } else {
                    Write-Host "Restart failed. Restart it manually." -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "Docker Desktop settings not updated ($($_.Exception.Message))" -ForegroundColor Yellow
        }
    }

    # The distro is built and registered: clear the run's output and hand the
    # user a shell in it, which is what they came for. --cd ~ lands in their
    # home rather than in the Windows folder the script was launched from -
    # which it would otherwise map into the fresh distro.
    # Two lines are printed first, so the shell opens on the answer to "who am
    # I, where, and what now" instead of on an anonymous prompt. ~/projects
    # comes from /etc/skel, and fnew refuses to run from anywhere else.
    Clear-Host
    Write-Host "Welcome, $ConfiguredUser - you are now logged in to your brand new '$DistroName' WSL instance." -ForegroundColor Green
    Write-Host "Run 'cd projects' and type 'fnew' to create your first project." -ForegroundColor Yellow
    Write-Host ""
    wsl.exe -d $DistroName --cd ~
}

# A failed deployment must not look like a success to whatever called this
# script - a shortcut, a wrapper, a future CI job.
if (-not $Deployed) { exit 1 }
