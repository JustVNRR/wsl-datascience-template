[CmdletBinding()]
param (
    # The instance, when the theme menu has already asked which one. Not an
    # option and not documented as one: no command of this family takes a name
    # typed by heart - this is how the level above hands over.
    [string]$DistroName
)

# What a terminal's colours are: the colour scheme of its profile - the
# background, the text, and the sixteen colours a program may ask for by number.
# Reached through `.\wsl.ps1 theme`.
#
# The list is every scheme this machine can be told to use: those Windows
# Terminal ships (read from the file inside its own package) and those the user
# added or wrote over, their own settings winning over the built-in of the same
# name. Each is shown in its own colours, and the one in use is marked. It keeps
# asking, like the two commands beside it: Escape leaves.

$ErrorActionPreference = "Stop"

$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

# Windows Terminal writes JSON with comments and with a comma left before a
# closing bracket. PowerShell's reader refuses both - and a blind replace on the
# text is worse than refusing: that file holds a string of every punctuation
# mark there is ("wordDelimiters"), and taking a comma out of IT breaks the JSON
# somewhere that has nothing to do with commas. Measured, after two attempts
# that did exactly that.
#
# So the walk below knows what a string is: inside quotes nothing is touched, a
# "//" outside quotes runs to the end of its line, and a comma followed by a
# closing bracket - outside a string - is dropped. Anything else is left alone,
# and a file that still will not parse is no schemes at all, not a crash.
function Read-TerminalJson {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path $Path)) { return $null }
    try {
        $Text = [System.IO.File]::ReadAllText($Path)
    } catch {
        return $null
    }

    try {
        $Out = New-Object System.Text.StringBuilder
        $InString = $false
        for ($Index = 0; $Index -lt $Text.Length; $Index++) {
            $Char = $Text[$Index]

            if ($InString) {
                $null = $Out.Append($Char)
                if ($Char -eq '\') {
                    $Index++
                    if ($Index -lt $Text.Length) { $null = $Out.Append($Text[$Index]) }
                    continue
                }
                if ($Char -eq '"') { $InString = $false }
                continue
            }

            if ($Char -eq '"') { $InString = $true; $null = $Out.Append($Char); continue }

            if ($Char -eq '/' -and ($Index + 1) -lt $Text.Length -and $Text[$Index + 1] -eq '/') {
                while ($Index -lt $Text.Length -and $Text[$Index] -ne "`n") { $Index++ }
                $null = $Out.Append("`n")
                continue
            }

            if ($Char -eq ',') {
                $Next = $Index + 1
                while ($Next -lt $Text.Length -and [char]::IsWhiteSpace($Text[$Next])) { $Next++ }
                if ($Next -lt $Text.Length -and ($Text[$Next] -eq '}' -or $Text[$Next] -eq ']')) { continue }
            }

            $null = $Out.Append($Char)
        }
        return ($Out.ToString() | ConvertFrom-Json)
    } catch {
        return $null
    }
}

# Every colour scheme this machine can wear, by name: the name is what a profile
# takes, and what is behind it is what the list shows.
function Get-ColorSchemes {
    $Schemes = @{}

    # What Windows Terminal ships, from the file inside its own package. Readable
    # by a normal account - the folder is not, and the file is, which was worth
    # measuring before ruling it out.
    # Asked one at a time: an array handed to -Name binds to a parameter that
    # takes one name, and the call is refused before it runs - measured.
    $Packages = @()
    foreach ($PackageName in @("Microsoft.WindowsTerminal", "Microsoft.WindowsTerminalPreview")) {
        $Packages += @(Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue)
    }
    foreach ($Package in $Packages) {
        $Parsed = Read-TerminalJson -Path (Join-Path $Package.InstallLocation "defaults.json")
        foreach ($Scheme in @($Parsed.schemes)) {
            if ($Scheme -and $Scheme.name -and -not $Schemes.ContainsKey($Scheme.name)) {
                $Schemes[$Scheme.name] = $Scheme
            }
        }
    }

    # And what the user added, or wrote over: read last, so their own version of
    # a name wins over the one Terminal ships.
    foreach ($Path in @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )) {
        $Parsed = Read-TerminalJson -Path $Path
        foreach ($Scheme in @($Parsed.schemes)) {
            if ($Scheme -and $Scheme.name) { $Schemes[$Scheme.name] = $Scheme }
        }
    }

    # And the schemes our instances already wear, when nothing above named them:
    # a name with no colours behind it is still a choice a profile takes, and
    # leaving it out would hide the scheme the instance is using right now.
    $Ours = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-datascience-template"
    foreach ($File in @(Get-ChildItem $Ours -Filter *.json -ErrorAction SilentlyContinue)) {
        $Parsed = Read-TerminalJson -Path $File.FullName
        $Named = @($Parsed.profiles)[0].colorScheme
        if ($Named -and -not $Schemes.ContainsKey($Named)) { $Schemes[$Named] = $null }
    }

    # The comma: a table written to the pipeline is unrolled into its entries,
    # and the caller would get the first pair instead of the table.
    return ,$Schemes
}

# 1. Which instance. Given, or asked.
$HandedOver = [bool]$DistroName
if ($HandedOver) {
    $Distro = Get-Distros | Where-Object { $_.Name -eq $DistroName } | Select-Object -First 1
    if (-not $Distro) {
        Write-Host ""
        Write-Host "[ABORT] No instance named '$DistroName' is registered here." -ForegroundColor Red
        exit 1
    }
} else {
    $Distro = Select-Distro
    $DistroName = $Distro.Name
}
$IconPath = Join-Path $Distro.BasePath "terminal-icon.png"

Clear-MenuScreen

$OurFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-datascience-template\$DistroName.json"
if (-not (Test-Path $OurFragment)) {
    Write-Host ""
    Write-Host "[WARNING] This instance has no Terminal profile of ours - the colours would not show." -ForegroundColor Yellow
    Write-Host "          Build it again, or set them by hand in Ctrl+," -ForegroundColor DarkGray
}

$Escape = [char]27
$Coloured = Test-ColourOutput

Write-Host ""
Write-Host "Reading the colour schemes Windows Terminal has..." -ForegroundColor DarkGray

$Schemes = Get-ColorSchemes
if ($Schemes.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No colour scheme could be read on this machine." -ForegroundColor Red
    Write-Host "        Nothing was modified." -ForegroundColor DarkGray
    exit 1
}
$Rows = @($Schemes.Keys | Sort-Object)

$Default = 0
$Changed = $false

while ($true) {
    # Read again every turn: the scheme in use is what the list marks, and the
    # turn before may have changed it.
    $Current = (Get-InstanceAppearance -Name $DistroName).ColorScheme

    $Picked = Select-FromList -Title "Colours of '$DistroName'" -Items $Rows -Label {
        param($Name)

        $Scheme = $Schemes[$Name]

        # Padded, and padded INSIDE the colours: every row has to end at the same
        # column, or the painted blocks come out raggeder the longer the names
        # get, and a list of coloured bars of different lengths is a barcode, not
        # a list. The mark gets a column of its own for the same reason - jumping
        # after the name it belongs to, it jumped from row to row.
        $Here = if ($Name -eq $Current) { "(current)" } else { "" }
        $Text = "{0,-20} {1,-11}" -f $Name, $Here

        # The mark in red, so it is found before the row is read - and the colour
        # is put around the word INSIDE the padded text: padding a string that
        # already carries escapes would count them as letters and break the
        # column the rows are aligned on.
        if ($Here -and $Coloured) {
            $Text = $Text -replace [regex]::Escape($Here), ("{0}[91m{1}{0}[39m" -f $Escape, $Here)
        }
        $Sample = $Text

        # The scheme itself, and three of its colours beside it. What is being
        # chosen is a look, and a name says nothing to the eye - the icons and
        # the font have the same problem and the same answer.
        #
        # The reset comes first: a label long enough to be cut by a narrow window
        # would otherwise leave the terminal wearing the colours of the row it
        # was cut in, and nothing after it would clear them.
        if ($Coloured -and $Scheme -and $Scheme.background -and $Scheme.foreground) {
            $Sample = "{0}[0m{0}[48;2;{1}m{0}[38;2;{2}m{3}{0}[0m" -f $Escape,
                (ConvertTo-Rgb $Scheme.background), (ConvertTo-Rgb $Scheme.foreground), $Text
        }

        # And nothing else. There used to be three coloured swatches beside the
        # name, and they were the wrong idea twice over: the row is already
        # painted in the colours of its scheme, which is the whole preview, and
        # the swatches made the label longer than the window - so it was cut, and
        # what showed was a fragment of a colour block and the menu's own "...".
        # Reported as "je sais pas ce que c'est ces trucs au bout".
        $Sample
    } -DefaultIndex $Default

    if (-not $Picked) { break }

    # The menu has been answered: the screen goes clean, and the answer takes its
    # place - then the screen again, so the list comes back on its own.
    Clear-MenuScreen

    $Default = [array]::IndexOf($Rows, $Picked)

    # The profile is ours to write: the icon and the font stay as they are, the
    # scheme is the one just chosen.
    $Guid = Get-WslProfileGuid -Name $DistroName
    if (-not $Guid) {
        Write-Host ""
        Write-Host "[ABORT] Windows Terminal has no profile for '$DistroName' - the colours cannot be applied." -ForegroundColor Red
        Write-Host "        Nothing was modified." -ForegroundColor DarkGray
        exit 1
    }

    $Appearance = Get-InstanceAppearance -Name $DistroName
    Set-InstanceFragment -Name $DistroName -Guid $Guid -Font $Appearance.Font `
        -ColorScheme $Picked -IconPath $IconPath
    Set-InstanceLook -InstallPath $Distro.BasePath -Look (New-InstanceLook -Name $DistroName)

    Clear-MenuScreen
    $Changed = $true
}

# Leaving, by Escape or because the visit is over: the menu goes too, so that the
# level above draws its own on a clean screen instead of under this one. It is
# the mirror of the clear at the top - down a level, up a level, same screen.
Clear-MenuScreen

if (-not $Changed) {
    # Handed over: the level above owns the goodbye, and it has its menu to draw
    # where this one was.
    if ($HandedOver) { exit 0 }
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

# Ask Terminal to look again, and only when this command was run on its own: the
# visit is over, the prompt is back, and the pane is idle - the one moment a
# reload lands. Behind the theme menu this is not done here at all: the menu is
# still running, and it asks when IT is over (see theme.ps1). Reported that way
# too: "it works when I run the command, not through the menu".
if (-not $HandedOver) { Update-TerminalSettings }
exit 0
