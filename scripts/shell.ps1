[CmdletBinding()]
param ()

# No parameter on purpose: the instance comes from the list, like everywhere
# else in this family. This is the one command that does not act on an
# instance - it opens a session in it and steps aside.

$ErrorActionPreference = "Stop"

# What the whole family shares: how to tell one of our instances from any other
# registered one.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

# 1. Which instance to open a shell in
$Distro = Select-Distro
$DistroName = $Distro.Name

Write-Host ""
Write-Host "==> Opening a shell in '$DistroName'..." -ForegroundColor Cyan
if ((Get-DistroNames -Running) -notcontains $DistroName) {
    Write-Host "  It was stopped: WSL starts it on the way in, which takes a moment." -ForegroundColor DarkGray
}

# 2. The shell itself. `--cd ~` lands in the instance's home rather than in the
# Windows folder this script was launched from, which WSL would otherwise map
# into the session - the same reason build.ps1 ends with it. Nothing is
# captured from wsl.exe here: it owns the terminal until the user leaves it.
wsl.exe -d $DistroName --cd ~

# The exit code is the shell's own. A session that ended with `exit 1` in it is
# not a failure of this command, and a shell that could not start must not look
# like a success - so it is handed over rather than interpreted.
exit $LASTEXITCODE
