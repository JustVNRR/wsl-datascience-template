[CmdletBinding()]
param ()

# No parameter on purpose: the instance comes from the list. The one command
# that does not act on an instance - it opens a session and steps aside.

$ErrorActionPreference = "Stop"

# The family's shared half: the marker.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
    exit 1
}
. $InstanceLib

# 1. Which instance to open a shell in
$Distro = Select-Distro
$DistroName = $Distro.Name

Write-Host ""
Write-Host "==> Opening a shell in '$DistroName'..." -ForegroundColor (Get-MessageColour info)
if ((Get-DistroNames -Running) -notcontains $DistroName) {
    Write-Host "  It was stopped: WSL starts it on the way in, which takes a moment." -ForegroundColor (Get-MessageColour muted)
}

# 2. The shell itself. `--cd "~"` lands in the instance's home, not the Windows
# folder this script was launched from (which WSL would map into the session) -
# build.ps1 ends the same way. The tilde is quoted because PowerShell expands a
# bare one into the Windows home before wsl.exe ever sees it. Nothing is
# captured from wsl.exe: it owns the terminal until the user leaves.
wsl.exe -d $DistroName --cd "~"

# The exit code is the shell's own - `exit 1` typed in there is not a failure
# of this command - and a shell that could not start must not look like a
# success: handed over, not interpreted.
exit $LASTEXITCODE
