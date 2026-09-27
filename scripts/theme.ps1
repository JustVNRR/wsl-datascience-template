[CmdletBinding()]
param ()

# What an instance wears: its icon, its font and its colours - the three things
# Windows Terminal takes from the profile this repository writes.
#
# The instance comes first, once, then the commands - and each of them comes back
# here when it is done, so changing the icon and then the font is one visit to
# one instance. Escape on this menu is the way out.
#
# The italic face and the background picture are not offered: the first is a coin
# toss with the fonts that have one, the second is a Windows setting this
# repository does not own.

$ErrorActionPreference = "Stop"

$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
    exit 1
}
. $InstanceLib

$Choices = @(
    @{ Name = "icon";  About = "the tile in the tab" },
    @{ Name = "font";  About = "what the whole terminal is written in" },
    @{ Name = "color"; About = "the background, the text, and sixteen colours" }
)

foreach ($Choice in $Choices) {
    $Script = Join-Path $PSScriptRoot "$($Choice.Name).ps1"
    if (-not (Test-Path $Script)) {
        Write-Host ""
        Write-Host "[ABORT] scripts\$($Choice.Name).ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
        exit 1
    }
}

# 1. Which instance, and then which of the three - and Escape walks back up the
# way it came: from the theme menu to the list of instances, so that another one
# can be picked, and from the list to the prompt. One visit per instance is the
# ordinary way to use this; changing two instances is two visits, and there is no
# reason to leave the command to start it again.
$Visited = $false

while ($true) {
    # The menu this one was reached from - and everything typed before it - goes
    # first: the instance list gets a screen of its own.
    Clear-MenuScreen

    $Distro = Select-Distro -AllowCancel
    if (-not $Distro) { break }
    $DistroName = $Distro.Name

    Clear-MenuScreen

    # What has been done is written in the instance, and the menu comes back
    # until Escape says the visit to THIS one is over - the level below clears
    # the screen, and this one is drawn on a clean one.
    $Default = 0
    while ($true) {
        Write-Host ""
        $Chosen = Select-FromList -Title "Theme of '$DistroName'" -Items $Choices -Label {
            param($Choice)
            "{0,-6} {1}" -f $Choice.Name, $Choice.About
        } -DefaultIndex $Default

        if (-not $Chosen) { break }

        $Default = [array]::IndexOf($Choices, $Chosen)

        # The menu has been answered: the command it named takes the screen - and
        # clears it itself, the way it came in.
        & (Join-Path $PSScriptRoot "$($Chosen.Name).ps1") -DistroName $DistroName
        $Visited = $true
    }
}

# Coming out: the menu goes with the visit. Ending on the menu you have just
# finished with reads like the command never returned - what is left is the line
# below, and the prompt.
Clear-MenuScreen

if (-not $Visited) {
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor (Get-MessageColour success)
    exit 0
}

# The visit is over, and this is the moment Terminal can be asked to look again:
# the menu is answered for good, and the pane is about to be idle at its prompt.
# Asked any earlier - inside the menu, right after a change - nothing happens: a
# reload cannot land on a pane that is running a menu. That is measured, and it
# is why the change shows when you leave, not while you are still in there.
Update-TerminalSettings

# And nothing is said: the screen was cleared, the change is in the tab, and a
# line explaining that would be one line too many. Silence is the report.
exit 0
