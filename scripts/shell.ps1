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

# The choice every command in this family offers: the instances that exist,
# numbered, with what is worth knowing about each, and a way out. The question
# comes back until the answer is one of the numbers - an empty answer cancels,
# so a run with no console can never loop forever.
function Select-Distro {
    # Sorted by name: the registry order changes between runs, and a menu whose
    # numbers move is a menu you cannot trust twice. Filtered on the marker:
    # the machine holds other distributions - Docker Desktop's, a colleague's -
    # and none of them are ours to touch.
    $All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.BasePath } | Sort-Object Name)
    if ($All.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor Red
        Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor Yellow
        Write-Host "        Already have one? Make it ours with  .\wsl.ps1 adopt" -ForegroundColor Yellow
        exit 1
    }

    $Running = Get-DistroNames -Running

    Write-Host ""
    Write-Host "Instances of this template:" -ForegroundColor Cyan
    for ($Index = 0; $Index -lt $All.Count; $Index++) {
        $Entry = $All[$Index]
        $State = if ($Running -contains $Entry.Name) { "running" } else { "stopped" }
        Write-Host ("  {0,2}.  {1,-30} {2,-8} {3,10}" -f ($Index + 1), $Entry.Name, $State,
            (Format-Size (Get-VhdxSize $Entry.BasePath)))
    }
    Write-Host "   0.  Cancel"

    while ($true) {
        $Answer = [string](Read-Host "Which one? (0 to cancel)")
        if ([string]::IsNullOrWhiteSpace($Answer)) {
            Write-Host ""
            Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
            exit 0
        }
        $Number = 0
        if ([int]::TryParse($Answer.Trim(), [ref]$Number)) {
            if ($Number -eq 0) {
                Write-Host ""
                Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
                exit 0
            }
            if ($Number -ge 1 -and $Number -le $All.Count) {
                return $All[$Number - 1]
            }
        }
        Write-Host "  '$Answer' is not one of the numbers above." -ForegroundColor Yellow
    }
}

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
