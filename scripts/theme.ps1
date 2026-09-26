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
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
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
        Write-Host "[ABORT] scripts\$($Choice.Name).ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
        exit 1
    }
}

# 1. Which instance. The commands behind this menu are given the name rather than
# asking again: it has been asked, and asking twice is how a visit becomes three.
$Distro = Select-Distro
$DistroName = $Distro.Name

# 2. Which of the two, again and again. What has been done is written in the
# instance, and the menu comes back until Escape says the visit is over - the
# level below takes itself off the screen and this one is drawn again where it
# was.
Clear-MenuBlocks

$Default = 0
$Visited = $false

while ($true) {
    Write-Host ""
    $Chosen = Select-FromList -Title "Theme of '$DistroName'" -Items $Choices -Label {
        param($Choice)
        "{0,-6} {1}" -f $Choice.Name, $Choice.About
    } -DefaultIndex $Default

    if (-not $Chosen) { break }

    $Default = [array]::IndexOf($Choices, $Chosen)

    # The menu has been answered: it goes, and the command it named takes the
    # screen - to give it back when it is done with it.
    Clear-MenuBlock
    & (Join-Path $PSScriptRoot "$($Chosen.Name).ps1") -DistroName $DistroName
    $Visited = $true
}

if (-not $Visited) {
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

Write-Host "'$DistroName' is done, and Windows Terminal has re-read its settings: the colours are" -ForegroundColor DarkGray
Write-Host "there already, and a new tab shows the rest." -ForegroundColor DarkGray
Write-Host ""
exit 0
