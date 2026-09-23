# ==============================================================================
# THE WAY IN: one command at the root, the scripts themselves in scripts\
# ==============================================================================
# Bare, it says what the repository can do. With a command, it runs it.
#
#   .\wsl.ps1                       the list
#   .\wsl.ps1 archive               archive an instance
#   .\wsl.ps1 archive -Format tar.xz
#
# None of the commands behind it takes an instance name on the command line:
# they list what exists, and you pick. scripts\instance.ps1 is not a command -
# it holds what the others share, and is not listed here.
# ==============================================================================

$Scripts = Join-Path $PSScriptRoot "scripts"

$Commands = @(
    @{ Name = "build";      What = "build an instance from the image (Docker, then WSL)" },
    @{ Name = "unregister"; What = "remove an instance, and what it left on Windows" },
    @{ Name = "archive";    What = "write an instance to a named archive" },
    @{ Name = "restore";    What = "rebuild an instance from an archive" },
    @{ Name = "duplicate";  What = "copy an instance under another name" },
    @{ Name = "shrink";     What = "reclaim the space an instance has freed" }
)

if ($args.Count -eq 0) {
    Write-Host ""
    Write-Host "WSL DataScience template" -ForegroundColor Cyan
    Write-Host ""
    foreach ($Command in $Commands) {
        Write-Host ("  {0,-12} {1}" -f $Command.Name, $Command.What)
    }
    Write-Host ""
    Write-Host "  .\wsl.ps1 <command> [options]" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

$Verb = "$($args[0])".ToLower()
$Chosen = $Commands | Where-Object { $_.Name -eq $Verb } | Select-Object -First 1

if (-not $Chosen) {
    Write-Host ""
    Write-Host "[ABORT] '$($args[0])' is not one of the commands." -ForegroundColor Red
    Write-Host "        Known:" -ForegroundColor Yellow
    foreach ($Command in $Commands) {
        Write-Host "          $($Command.Name)" -ForegroundColor Yellow
    }
    exit 1
}

$Script = Join-Path $Scripts "$($Chosen.Name).ps1"
if (-not (Test-Path $Script)) {
    Write-Host ""
    Write-Host "[ABORT] $Script is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}

# Whatever followed the command is handed over as it came: a command that has
# options keeps them, the others ignore them.
$Rest = @()
if ($args.Count -gt 1) { $Rest = $args[1..($args.Count - 1)] }
& $Script @Rest

if ($null -eq $LASTEXITCODE) { exit 0 }
exit $LASTEXITCODE
