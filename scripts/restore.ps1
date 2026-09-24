[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# One working folder, no guessing: instances live in <Root>\<name>, every
# archive in <Root>\archives - the rule the whole family follows.
$Root = if (Test-Path "D:\") { "D:\WSL" } else { "$env:USERPROFILE\WSL" }
$ArchiveFolder = Join-Path $Root "archives"

# What the whole family shares: how to tell one of our instances from any other
# registered one, and what Windows knows about its look - stored next to the
# tar, and re-applied here.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

# Halts script execution if an external command (like wsl) fails
function Invoke-External {
    param([scriptblock]$Command, [string]$ErrorMessage)
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$ErrorMessage (Exit code: $LASTEXITCODE)"
    }
}

function Get-DistroNames {
    $Found = @()
    foreach ($Key in Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss -ErrorAction SilentlyContinue) {
        $Props = Get-ItemProperty $Key.PSPath
        if ($Props.DistributionName) { $Found += $Props.DistributionName }
    }
    return @($Found)
}

function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N1} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N1} MB" -f ($Bytes / 1MB)) }
    return ("{0:N0} KB" -f ($Bytes / 1KB))
}

# 1. What is there to restore from. An empty folder is not an error to work
# around: it is the answer, and it says how to fill it.
if (-not (Test-Path $ArchiveFolder)) {
    Write-Host ""
    Write-Host "[ABORT] There are no archives: $ArchiveFolder does not exist." -ForegroundColor Red
    Write-Host "        Nothing to restore:" -ForegroundColor Yellow
    Write-Host "            - Create one with  .\wsl.ps1 archive" -ForegroundColor Yellow
    Write-Host "            - Or move the existing ones back into $ArchiveFolder" -ForegroundColor Yellow
    exit 1
}

# An archive is a folder - the tar, and the look of the instance it was taken
# from - so what this lists is the folders that hold one. Most recent first:
# the last archive taken is usually the one wanted back.
$Archives = @(Get-ChildItem -Path $ArchiveFolder -Directory |
    Where-Object { (Get-ChildItem -Path $_.FullName -Filter "*.tar*" -File).Count -gt 0 } |
    Sort-Object LastWriteTime -Descending)

if ($Archives.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] The archives folder is empty: $ArchiveFolder" -ForegroundColor Red
    Write-Host "        Nothing to restore:" -ForegroundColor Yellow
    Write-Host "            - Create one with  .\wsl.ps1 archive" -ForegroundColor Yellow
    Write-Host "            - Or move the existing ones back into $ArchiveFolder" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Archives in $ArchiveFolder (most recent first):" -ForegroundColor Cyan
for ($i = 0; $i -lt $Archives.Count; $i++) {
    $Entry = $Archives[$i]
    $Tar = Get-ChildItem -Path $Entry.FullName -Filter "*.tar*" -File |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host ("  {0,2}.  {1}  -  {2}, {3}" -f ($i + 1), $Entry.Name,
        (Format-Size $Tar.Length), $Entry.LastWriteTime.ToString("yyyy-MM-dd HH:mm"))
}
Write-Host "   0.  Cancel"

# 2. Pick one by number. An empty answer cancels, as everywhere else in this
# repository; a wrong number asks again, but not forever.
$Chosen = $null
while (-not $Chosen) {
    $Answer = [string](Read-Host "Which archive? (1-$($Archives.Count), 0 to cancel)")
    if ([string]::IsNullOrWhiteSpace($Answer)) {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was created." -ForegroundColor Green
        exit 0
    }
    $Number = 0
    if ([int]::TryParse($Answer.Trim(), [ref]$Number)) {
        if ($Number -eq 0) {
            Write-Host ""
            Write-Host "[ABORT] Operation cancelled by user. Nothing was created." -ForegroundColor Green
            exit 0
        }
        if ($Number -ge 1 -and $Number -le $Archives.Count) {
            $Chosen = $Archives[$Number - 1]
        }
    }
    if (-not $Chosen) {
        Write-Host "  '$Answer' is not one of the numbers above." -ForegroundColor Yellow
    }
}

# 3. Name the new instance
Write-Host ""
Write-Host "Restoring $($Chosen.Name) as a new instance." -ForegroundColor Cyan
$Name = [string](Read-Host "Name of the new instance (Enter to cancel)")
if ([string]::IsNullOrWhiteSpace($Name)) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was created." -ForegroundColor Green
    exit 0
}
$Name = $Name.Trim()

if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
    Write-Host ""
    Write-Host "[ABORT] '$Name' is not usable as an instance name" -ForegroundColor Red
    Write-Host "        (letters, digits, '.', '_' and '-' only)." -ForegroundColor Yellow
    Write-Host "        Nothing was created." -ForegroundColor DarkGray
    exit 1
}

# An instance of that name has to go first, and removing an instance is
# unregister.ps1's job - with its typed-name confirmation. This script does
# not do it, and does not pretend to: it names the command.
if ((Get-DistroNames) -contains $Name) {
    Write-Host ""
    Write-Host "[ABORT] An instance named '$Name' already exists." -ForegroundColor Red
    Write-Host "        Remove it first, then run this again:" -ForegroundColor Yellow
    Write-Host "          .\wsl.ps1 unregister        (pick '$Name' in the list)" -ForegroundColor White
    exit 1
}

# The install folder must be free too: a leftover folder of that name would
# live inside the new instance's disk.
$InstallPath = [System.IO.Path]::GetFullPath((Join-Path $Root $Name))
if (Test-Path $InstallPath) {
    Write-Host ""
    Write-Host "[ABORT] A folder with that name already exists:" -ForegroundColor Red
    Write-Host "        $InstallPath" -ForegroundColor Yellow
    Write-Host "        Move or delete it, then run this again." -ForegroundColor Yellow
    exit 1
}

# 4. Import. Version 2, like build.ps1: an archive does not carry the version
# of the instance it came from, and WSL 1 is not what this repository builds.
$ChosenTar = Get-ChildItem -Path $Chosen.FullName -Filter "*.tar*" -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

Write-Host ""
Write-Host "==> Creating '$Name' from $($Chosen.Name)" -ForegroundColor Cyan
Write-Host "  * Archive          : $($ChosenTar.FullName) ($(Format-Size $ChosenTar.Length))" -ForegroundColor DarkGray
Write-Host "  * Install folder   : $InstallPath" -ForegroundColor DarkGray
Write-Host ""

try {
    Invoke-External { wsl.exe --import $Name $InstallPath $ChosenTar.FullName --version 2 } "The import failed."
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        The archive is untouched. A half-registered '$Name' may be left" -ForegroundColor Yellow
    Write-Host "        behind:  .\wsl.ps1 unregister        (pick '$Name' in the list)" -ForegroundColor Yellow
    exit 1
}

# Our mark, so every other command sees the instance - then the look, and
# Docker Desktop's knowledge of it, which a tar carries neither of.
New-InstanceMarker -Folder $InstallPath -By "restore"

Set-InstanceState -Name $Name -InstallPath $InstallPath -Folder $Chosen.FullName

Write-Host "============================================================" -ForegroundColor Green
Write-Host "       '$Name' restored from an archive" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$InstallPath" -ForegroundColor Cyan
Write-Host "  * From             : " -NoNewline; Write-Host "$($Chosen.Name)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  The archive is kept." -ForegroundColor Yellow
Write-Host "  Windows Terminal: restart it to see the icon, the font and the colour" -ForegroundColor DarkGray
Write-Host "  scheme that came back with the archive." -ForegroundColor DarkGray
Write-Host ""
