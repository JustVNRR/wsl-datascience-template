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
    
    # 2. Download the font
    $FontUrl = "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    $TempFontPath = Join-Path $env:TEMP $FontFile
    Invoke-WebRequest -Uri $FontUrl -OutFile $TempFontPath -UseBasicParsing
    
    # 3. Install the font PER-USER (No admin required!)
    try {
        $UserFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
        
        # Create user fonts directory if it doesn't exist
        if (-not (Test-Path $UserFontsDir)) {
            New-Item -ItemType Directory -Path $UserFontsDir -Force | Out-Null
        }
        
        $DestFontPath = Join-Path $UserFontsDir $FontFile
        
        # Copy file and add to registry with the full path
        if (-not (Test-Path $DestFontPath)) {
            Copy-Item -Path $TempFontPath -Destination $DestFontPath -Force
            New-ItemProperty -Path $FontRegPath -Name "$FontName (TrueType)" -Value $DestFontPath -PropertyType String -Force | Out-Null
        }
        Write-Host "  * Font Status       : " -NoNewline; Write-Host "Successfully installed $FontName for current user." -ForegroundColor Green
        return $false
    } catch {
        Write-Host "  * Font Status       : " -NoNewline; Write-Host "Could not auto-install font: $_" -ForegroundColor Red
        return $false
    }
}

# Ensure script runs from its directory
$RepoRoot = $PSScriptRoot
Set-Location -Path $RepoRoot

$ImageTag = "wsl-datascience-template:latest"
$ContainerName = "wsl-temp-export-$([guid]::NewGuid().ToString().Substring(0, 8))"

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

    if ($Confirmation -ne $DistroName) {
        Write-Host "[ABORT] Operation cancelled. No data was modified." -ForegroundColor Green
        exit 0
    }
}

try {
    Write-Host "==> 1. Building Docker rootfs image..." -ForegroundColor Cyan
    Invoke-External { docker build -t $ImageTag . } "Docker build failed."

    Write-Host "==> 2. Creating temporary export container..." -ForegroundColor Cyan
    Invoke-External { docker create --name $ContainerName $ImageTag } "Container creation failed."

    Write-Host "==> 3. Exporting filesystem to temporary archive ($TarPath)..." -ForegroundColor Cyan
    Invoke-External { docker export -o $TarPath $ContainerName } "Docker export failed."

    Write-Host "==> 4. Preparing installation folder: $InstallPath" -ForegroundColor Cyan
    wsl.exe --unregister $DistroName 2>$null
    if (Test-Path -Path $InstallPath) {
        Remove-Item -Recurse -Force $InstallPath
    }
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

    Write-Host "==> 5. Importing into WSL ($DistroName)..." -ForegroundColor Cyan
    Invoke-External { wsl.exe --import $DistroName $InstallPath $TarPath --version 2 } "WSL import failed."

    Write-Host "==> 6. Running initial onboarding setup..." -ForegroundColor Cyan
    Invoke-External { wsl.exe -d $DistroName -u root /root/first_boot.sh } "The first_boot.sh configuration script failed."

    # Retrieve configured username from temporary file
    $ConfiguredUser = (wsl.exe -d $DistroName -u root cat /tmp/installed_user).Trim()
    wsl.exe -d $DistroName -u root rm -f /tmp/installed_user

    Write-Host "==> 7. Shutting down distro to persist systemd and user configuration..." -ForegroundColor Cyan
    wsl.exe --terminate $DistroName

    Write-Host "==> 8. Checking Windows Terminal Font compatibility..." -ForegroundColor Cyan
    $FontAlreadyConfigured = Install-NerdFont

    Clear-Host
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "       WSL Data Science Instance Successfully Deployed!     " -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  * Distribution Name : " -NoNewline; Write-Host "$DistroName" -ForegroundColor Cyan
    Write-Host "  * Default User      : " -NoNewline; Write-Host "$ConfiguredUser" -ForegroundColor Cyan
    Write-Host "  * Install Path      : " -NoNewline; Write-Host "$InstallPath" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "To launch your session, run:" -ForegroundColor Yellow
    Write-Host "  wsl -d $DistroName" -ForegroundColor White
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "============================================================" -ForegroundColor Magenta
    Write-Host " ⚠️ UI REQUIRED ACTION: TERMINAL FONT CONFIGURATION" -ForegroundColor Magenta
    Write-Host "============================================================" -ForegroundColor Magenta
    Write-Host " To see the icons properly (no missing squares/tofu):"
    Write-Host " 1. Open Windows Terminal settings (Ctrl + ,)"
    Write-Host " 2. Select '$DistroName' profile on the left"
    Write-Host " 3. Go to 'Appearance' > 'Font face'"
    Write-Host " 4. Select 'MesloLGS NF' and save"
    Write-Host " 5. Close your terminal"
    Write-Host " 6. Reopen it"
    Write-Host " 7. Click the dropdown arrow (v) next to the new tab button, and select '$DistroName'."
    Write-Host ""
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
    docker rm -f $ContainerName 2>$null | Out-Null

    if (Test-Path -Path $TarPath) {
        Remove-Item -Path $TarPath -Force -ErrorAction SilentlyContinue
    }

    # Prompt whether to retain or purge the local Docker image
    Write-Host ""
    Write-Host "Keep local Docker image ('$ImageTag')?" -ForegroundColor Cyan
    Write-Host "  [Enter] : Keep image (speeds up future builds via caching)" -ForegroundColor DarkGray
    Write-Host "  [n]     : Remove image to free up disk space" -ForegroundColor DarkGray
    $KeepDockerImage = Read-Host "Keep image? [Y/n]"

    if ($KeepDockerImage -match "^[nN]$") {
        Write-Host "==> Removing Docker image '$ImageTag'..." -ForegroundColor Yellow
        docker rmi -f $ImageTag 2>$null | Out-Null
        Write-Host "Docker image removed successfully." -ForegroundColor Green
    } else {
        Write-Host "Docker image retained." -ForegroundColor Green
    }
}
