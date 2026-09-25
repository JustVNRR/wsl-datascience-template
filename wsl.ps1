# ==============================================================================
# THE WAY IN: one command at the root, the scripts themselves in scripts\
# ==============================================================================
# Bare, it asks which command: the list, walked with the arrows and taken with
# Enter, Escape to cancel. With a command, it runs it.
#
#   .\wsl.ps1                       the menu
#   .\wsl.ps1 archive               archive an instance
#   .\wsl.ps1 archive -Format tar.xz
#
# None of the commands behind it takes an instance name on the command line:
# they list what exists - this template's instances only, the ones carrying the
# marker - or, for start and stop, what can still be acted on, and you pick.
# scripts\instance.ps1 is not a command: it holds what the other scripts share,
# and is not listed here.
# ==============================================================================

$Scripts = Join-Path $PSScriptRoot "scripts"

# The order is the one the documentation uses, and it starts with the command
# that answers "what do I have?" - list, then the rest along an instance's life.
# Each line says what the command does and stops there: a menu is read at a
# glance. The longest description is 42 characters - 63 columns numbered, 60
# behind the arrow marker, measured - so an 80-column window shows them whole
# and the cut never eats a word that mattered. What deserves a sentence is in
# docs\wsl\commands.md.
$Commands = @(
    @{ Name = "list";       What = "list our instances and the archives" },
    @{ Name = "build";      What = "build an instance from the image" },
    @{ Name = "adopt";      What = "mark an existing instance as ours" },
    @{ Name = "start";      What = "start a stopped instance" },
    @{ Name = "stop";       What = "stop a running instance" },
    @{ Name = "shell";      What = "open a shell inside an instance" },
    @{ Name = "add_pack";   What = "install optional tooling into an instance" },
    @{ Name = "remove_pack"; What = "uninstall optional tooling from an instance" },
    @{ Name = "manage_packs"; What = "choose the packs an instance should carry" },
    @{ Name = "unregister"; What = "remove an instance" },
    @{ Name = "archive";    What = "write an instance to a named archive" },
    @{ Name = "restore";    What = "rebuild an instance from an archive" },
    @{ Name = "duplicate";  What = "copy an instance under another name" },
    @{ Name = "shrink";     What = "reclaim the space an instance has freed" }
)

# Bare, the repository asks its first question - which command - and it is a
# question like the ones inside the commands: the same menu, walked with the
# arrows, cancelled with Escape. The dispatcher loads what they load, for that
# reason and no other: asking is scripts\menu.ps1's job, and it must not be
# written a second time here.
if ($args.Count -eq 0) {
    $InstanceLib = Join-Path $Scripts "instance.ps1"
    if (-not (Test-Path $InstanceLib)) {
        Write-Host ""
        Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
        exit 1
    }
    . $InstanceLib

    Write-Host ""
    Write-Host "  (a command can also be typed:  .\wsl.ps1 <command> [options])" -ForegroundColor DarkGray

    $Chosen = Select-FromList -Title "WSL DataScience template" -Items $Commands -Label {
        param($Command)
        "{0,-12} {1}" -f $Command.Name, $Command.What
    }

    if (-not $Chosen) {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was run." -ForegroundColor Green
        exit 0
    }
    $Verb = $Chosen.Name
} else {
    $Verb = "$($args[0])".ToLower()
}

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
