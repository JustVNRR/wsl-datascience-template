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
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
    exit 1
}
. $InstanceLib

# 1. What is there to restore from. An empty folder is not an error to work
# around: it is the answer, and it says how to fill it.
if (-not (Test-Path $ArchiveFolder)) {
    Write-Host ""
    Write-Host "[ABORT] There are no archives: $ArchiveFolder does not exist." -ForegroundColor (Get-MessageColour error)
    Write-Host "        Nothing to restore:" -ForegroundColor (Get-MessageColour hint)
    Write-Host "            - Create one with  .\wsl.ps1 archive" -ForegroundColor (Get-MessageColour hint)
    Write-Host "            - Or move the existing ones back into $ArchiveFolder" -ForegroundColor (Get-MessageColour hint)
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
    Write-Host "[ABORT] The archives folder is empty: $ArchiveFolder" -ForegroundColor (Get-MessageColour error)
    Write-Host "        Nothing to restore:" -ForegroundColor (Get-MessageColour hint)
    Write-Host "            - Create one with  .\wsl.ps1 archive" -ForegroundColor (Get-MessageColour hint)
    Write-Host "            - Or move the existing ones back into $ArchiveFolder" -ForegroundColor (Get-MessageColour hint)
    exit 1
}

# 2. Pick one. An answer of nothing cancels, as everywhere else in this
# repository.
$Chosen = Select-FromList -Title "Archives in $ArchiveFolder (most recent first):" -Items $Archives -Label {
    param($Entry)
    $Tar = Get-ChildItem -Path $Entry.FullName -Filter "*.tar*" -File |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    "{0}  -  {1}, {2}" -f $Entry.Name, (Format-Size $Tar.Length),
        $Entry.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
}

if (-not $Chosen) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was created." -ForegroundColor (Get-MessageColour success)
    exit 0
}

# 3. Name the new instance
Write-Host ""
Write-Host "Restoring $($Chosen.Name) as a new instance." -ForegroundColor (Get-MessageColour info)
$Name = [string](Read-Host "Name of the new instance (Enter to cancel)")
if ([string]::IsNullOrWhiteSpace($Name)) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was created." -ForegroundColor (Get-MessageColour success)
    exit 0
}
$Name = $Name.Trim()

if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
    Write-Host ""
    Write-Host "[ABORT] '$Name' is not usable as an instance name" -ForegroundColor (Get-MessageColour error)
    Write-Host "        (letters, digits, '.', '_' and '-' only)." -ForegroundColor (Get-MessageColour hint)
    Write-Host "        Nothing was created." -ForegroundColor (Get-MessageColour muted)
    exit 1
}

# An instance of that name has to go first, and removing an instance is
# unregister.ps1's job - with its typed-name confirmation. This script does
# not do it, and does not pretend to: it names the command.
if ((Get-DistroNames) -contains $Name) {
    Write-Host ""
    Write-Host "[ABORT] An instance named '$Name' already exists." -ForegroundColor (Get-MessageColour error)
    Write-Host "        Remove it first, then run this again:" -ForegroundColor (Get-MessageColour hint)
    Write-Host "          .\wsl.ps1 unregister        (pick '$Name' in the list)" -ForegroundColor (Get-MessageColour hint)
    exit 1
}

# The install folder must be free too: a leftover folder of that name would
# live inside the new instance's disk.
$InstallPath = [System.IO.Path]::GetFullPath((Join-Path $Root $Name))
if (Test-Path $InstallPath) {
    Write-Host ""
    Write-Host "[ABORT] A folder with that name already exists:" -ForegroundColor (Get-MessageColour error)
    Write-Host "        $InstallPath" -ForegroundColor (Get-MessageColour hint)
    Write-Host "        Move or delete it, then run this again." -ForegroundColor (Get-MessageColour hint)
    exit 1
}

# 4. Import. Version 2, like build.ps1: an archive does not carry the version
# of the instance it came from, and WSL 1 is not what this repository builds.
$ChosenTar = Get-ChildItem -Path $Chosen.FullName -Filter "*.tar*" -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

Write-Host ""
Write-Host "==> Creating '$Name' from $($Chosen.Name)" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Archive          : $($ChosenTar.FullName) ($(Format-Size $ChosenTar.Length))" -ForegroundColor (Get-MessageColour muted)
Write-Host "  * Install folder   : $InstallPath" -ForegroundColor (Get-MessageColour muted)
Write-Host ""

try {
    Invoke-External { wsl.exe --import $Name $InstallPath $ChosenTar.FullName --version 2 } "The import failed."
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    Write-Host "        The archive is untouched. A half-registered '$Name' may be left" -ForegroundColor (Get-MessageColour warning)
    Write-Host "        behind:  .\wsl.ps1 unregister        (pick '$Name' in the list)" -ForegroundColor (Get-MessageColour hint)
    exit 1
}

# Our mark, so every other command sees the instance - then the look, and
# Docker Desktop's knowledge of it, which a tar carries neither of.
New-InstanceMarker -Folder $InstallPath -By "restore"

Set-InstanceState -Name $Name -InstallPath $InstallPath -Folder $Chosen.FullName

Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "       '$Name' restored from an archive" -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$InstallPath" -ForegroundColor (Get-MessageColour info)
Write-Host "  * From             : " -NoNewline; Write-Host "$($Chosen.Name)" -ForegroundColor (Get-MessageColour info)
Write-Host ""
Write-Host "  The archive is kept." -ForegroundColor (Get-MessageColour hint)
Write-Host "  Windows Terminal: restart it to see the icon, the font and the colour" -ForegroundColor (Get-MessageColour muted)
Write-Host "  scheme that came back with the archive." -ForegroundColor (Get-MessageColour muted)
Write-Host ""
