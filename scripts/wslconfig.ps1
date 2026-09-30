[CmdletBinding()]
param ()

# No parameter on purpose: there is one .wslconfig on a machine, and it is the
# user's own file - no list, nothing to pick.

$ErrorActionPreference = "Stop"

# What the whole family shares: how to tell one of our instances from any other
# registered one, and the colours every line is written in.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
    exit 1
}
. $InstanceLib

# The file WSL reads before it starts the virtual machine: the memory cap, the
# processors, the DNS tunnel, the networking mode. Not the instance's own
# /etc/wsl.conf - that one is per distro, and the gmake side opens it (gmake
# wsl_config, from inside).
$Path = Join-Path $env:USERPROFILE ".wslconfig"

Write-Host ""
if (-not (Test-Path $Path)) {
    # Created commented, so the file documents itself and WSL reads no setting
    # nobody asked for - the rule the instance's own files follow too.
    @'
# WSL's Windows-wide settings. Read when the WSL machine starts: `wsl --shutdown`
# then a new start applies a change.
#
# The common keys: https://learn.microsoft.com/windows/wsl/wsl-config
#
# [wsl2]
# memory=8GB          # the machine's memory cap
# processors=4        # the CPUs it may use
# dnsTunneling=true   # WSL answers the DNS itself (the default)
'@ | Set-Content -Path $Path -Encoding ascii
    Write-Host "  * .wslconfig : " -NoNewline
    Write-Host "created - there was none" -ForegroundColor (Get-MessageColour success)
} else {
    Write-Host "  * .wslconfig : " -NoNewline
    Write-Host "$Path" -ForegroundColor (Get-MessageColour info)
}

Write-Host ""
Write-Host "==> Opening it - Windows picks the application it gives a .wslconfig..." -ForegroundColor (Get-MessageColour info)
try {
    Start-Process -FilePath $Path
} catch {
    Write-Host ""
    Write-Host "[WARNING] Windows did not open it: $($_.Exception.Message)" -ForegroundColor (Get-MessageColour warning)
    Write-Host "          No application is set for .wslconfig yet - open the file" -ForegroundColor (Get-MessageColour muted)
    Write-Host "          once from Explorer and pick one; Windows remembers it." -ForegroundColor (Get-MessageColour muted)
    exit 1
}

Write-Host ""
Write-Host "  A change here is read when the WSL machine starts - not by" -ForegroundColor (Get-MessageColour muted)
Write-Host "  .\wsl.ps1 restart, which restarts one instance. Stop the machine" -ForegroundColor (Get-MessageColour muted)
Write-Host "  with  wsl --shutdown  first, then open an instance again." -ForegroundColor (Get-MessageColour muted)
Write-Host ""
