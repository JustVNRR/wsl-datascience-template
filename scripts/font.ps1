[CmdletBinding()]
param (
    # The instance, when the theme menu has already asked which one. Not an
    # option and not documented as one: no command of this family takes a name
    # typed by heart - this is how the level above hands over.
    [string]$DistroName
)

# What an instance is written in: the font of its Terminal profile - the whole
# terminal, prompt and icons included. Reached through `.\wsl.ps1 theme`.
#
# The list is the fonts Windows says it has, asked of GDI+ rather than read off
# the registry: those are the family names a Terminal profile takes. Beside each
# name is what that font can do with the glyphs a prompt is drawn with, and the
# ones that have them come first - a font without them draws a box where your
# prompt has an icon.
#
# What no console can do is show a font in itself: a terminal writes every row in
# the font IT is set to, whatever we ask for. So the list says what can be
# measured, and the preview is the choice itself - the profile changes, and the
# next tab is written in it. (Windows Terminal's own settings, Ctrl+, show them
# all in their own face, for anyone who wants to browse that way.)
#
# It keeps asking, like the icon command: Escape leaves.

$ErrorActionPreference = "Stop"

$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

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

# The menus it came through - the way in, the theme menu, the instance it picked
# - come off the screen: this command asks its own question.
Clear-MenuScreen

$OurFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-datascience-template\$DistroName.json"
if (-not (Test-Path $OurFragment)) {
    Write-Host ""
    Write-Host "[WARNING] This instance has no Terminal profile of ours - the font would not show." -ForegroundColor Yellow
    Write-Host "          Build it again, or set the font by hand in Ctrl+," -ForegroundColor DarkGray
}

# The glyph a prompt is drawn with, and the one that says a font is a Nerd Font
# rather than a text font that happens to be installed: the folder, and the
# powerline arrow. Either one is enough - a prompt needs both, but a font that
# has the arrows is one somebody meant for a terminal.
$Folder = 0xF07B
$Arrow = 0xE0B0

# The fonts keys name every file after the face it holds - "MesloLGS NF Regular
# (TrueType)" - so one pass over them gives family -> file, which is what asking
# a font about its glyphs needs.
function Get-FontFiles {
    $Files = @{}
    foreach ($Root in @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
                        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")) {
        $Key = Get-ItemProperty -Path $Root -ErrorAction SilentlyContinue
        if (-not $Key) { continue }
        foreach ($Property in $Key.psobject.properties) {
            $Face = ($Property.Name -replace '\s*\(TrueType\)\s*$', '').Trim()
            if (-not $Face -or $Files.ContainsKey($Face)) { continue }
            $Path = [string]$Property.Value
            if (-not [System.IO.Path]::IsPathRooted($Path)) { $Path = Join-Path $env:WINDIR "Fonts\$Path" }
            $Files[$Face] = $Path
        }
    }
    return $Files
}

# Which glyphs this family has, read off the font file itself: every font carries
# a map from characters to glyphs, and a character it does not have maps to glyph
# zero - the box. Measured, and not guessed at by looking for ink where the glyph
# should be: a box has ink too.
#
# $null when the file could not be found or read, which is not the same answer as
# "no glyphs": the list then says nothing rather than something wrong. Read once
# per family - opening a font file is the expensive half, and the map is good for
# every character asked after it.
function Get-FontGlyphMap {
    param([System.Collections.Hashtable]$Files, [string]$Family)

    $Path = $null
    if ($Files.ContainsKey($Family)) { $Path = $Files[$Family] }
    if (-not $Path) {
        foreach ($Face in $Files.Keys) {
            if ($Face -like "$Family *") { $Path = $Files[$Face]; break }
        }
    }
    if (-not $Path -or -not (Test-Path $Path)) { return $null }

    try {
        Add-Type -AssemblyName PresentationCore
        $Typeface = New-Object Windows.Media.GlyphTypeface (New-Object System.Uri $Path)
        # The comma: a dictionary written to the pipeline is unrolled into its
        # entries, and the caller would get the first pair - a KeyValuePair with
        # no ContainsKey on it - instead of the map. Measured, the day this was
        # written.
        return ,$Typeface.CharacterToGlyphMap
    } catch {
        return $null
    }
}

# A terminal font is monospaced. Measured rather than assumed - 'i' and 'W' take
# the same room in one - and it is what keeps a list a person can read: Windows
# carries a few hundred fonts and most of them are for reading prose, where a
# prompt would come out ragged. Wingdings and its kind are monospaced too but
# nothing else, which is why one half of this list is short.
function Test-MonospaceFont {
    param([string]$Family)

    $Font = $null
    $Bitmap = $null
    $Canvas = $null
    try {
        $Font = New-Object System.Drawing.Font($Family, 20)
        $Format = [System.Drawing.StringFormat]::GenericTypographic
        $Bitmap = New-Object System.Drawing.Bitmap(64, 64)
        $Canvas = [System.Drawing.Graphics]::FromImage($Bitmap)
        $Narrow = $Canvas.MeasureString("iiii", $Font, 1000, $Format).Width
        $Wide = $Canvas.MeasureString("WWWW", $Font, 1000, $Format).Width
        return ([Math]::Abs($Narrow - $Wide) -lt 0.05)
    } catch {
        return $false
    } finally {
        if ($Canvas) { $Canvas.Dispose() }
        if ($Bitmap) { $Bitmap.Dispose() }
        if ($Font) { $Font.Dispose() }
    }
}

# Every font Windows has that a terminal can use, by the name a profile takes,
# with what it can draw. Asked once: the answers do not change while the command
# runs.
Write-Host ""
Write-Host "Reading the fonts Windows has..." -ForegroundColor DarkGray

Add-Type -AssemblyName System.Drawing
$Files = Get-FontFiles
$Families = @([System.Drawing.FontFamily]::Families | ForEach-Object { $_.Name } | Sort-Object)

# The styles of a font are families of their own to GDI+ - "JetBrainsMono NF
# ExtraBold" beside "JetBrainsMono NF" - and a profile takes the family. A name
# that is another font's plus a style word is left out; one that is another
# font's plus anything else is not, because "Segoe UI Emoji" is a font of its own.
$Styles = @("Regular", "Bold", "Italic", "Oblique", "Light", "SemiLight", "Medium",
            "Thin", "Black", "Heavy", "SemiBold", "Semibold", "DemiBold", "ExtraBold",
            "ExtraLight", "UltraLight", "Book", "Condensed", "Narrow")

# The symbol fonts Windows ships under its own names. Monospaced, so the test
# above keeps them, and full of private-area glyphs, so the one below finds every
# icon in them - measured: Wingdings 2 answers yes to both. They are not fonts to
# write in, whatever their glyphs say, and the list is short because it is the
# whole of them.
$SymbolFonts = @("Wingdings", "Wingdings 2", "Wingdings 3", "Webdings", "Symbol", "Marlett")

$Fonts = @()
foreach ($Family in $Families) {
    $Base = $Family
    foreach ($Style in $Styles) {
        if ($Family -like "* $Style") {
            $Base = $Family.Substring(0, $Family.Length - $Style.Length - 1)
            break
        }
    }
    if ($Base -ne $Family -and $Families -contains $Base) { continue }
    if (-not (Test-MonospaceFont -Family $Family)) { continue }
    if ($SymbolFonts -contains $Family) { continue }

    $Glyphs = Get-FontGlyphMap -Files $Files -Family $Family

    # A font with no plain capital A is a symbol font too - the piled symbols
    # Windows keeps for its own use. It is monospaced, and the private area it
    # lives in makes it look like it has every icon there is; a prompt written in
    # one is a row of boxes. Left out.
    if ($Glyphs -and -not $Glyphs.ContainsKey([int][char]"A")) { continue }

    $HasIcons = if ($Glyphs) { $Glyphs.ContainsKey($Folder) -or $Glyphs.ContainsKey($Arrow) } else { $null }
    $Fonts += @{ Name = $Family; Icons = $HasIcons }
}

# The ones that can draw a prompt first: the rest are for reading, not for a
# terminal, and a long list is easier to walk when the short one is on top.
$Fonts = @($Fonts | Sort-Object @{ Expression = { if ($_.Icons -eq $true) { 0 } else { 1 } } }, @{ Expression = { $_.Name } })

$Default = 0
$Changed = $false

while ($true) {
    # Read again every turn: the font in use is what the list marks, and the turn
    # before may have changed it.
    $Current = (Get-InstanceAppearance -Name $DistroName).Font

    $Picked = Select-FromList -Title "Font of '$DistroName'" -Items $Fonts -Label {
        param($Font)
        $Mark = if ($Font.Icons -eq $true) { "icons" } else { "" }
        $Here = if ($Font.Name -eq $Current) { "  (current)" } else { "" }
        "{0,-33} {1,-6}{2}" -f $Font.Name, $Mark, $Here
    } -DefaultIndex $Default

    if (-not $Picked) { break }

    # The menu has been answered: the screen goes clean, and the question takes
    # its place - then the screen again, so the list comes back on its own.
    Clear-MenuScreen

    $Default = [array]::IndexOf($Fonts, $Picked)

    # The profile is ours to write: the icon and the colours stay as they are,
    # the font is the one just chosen. WSL's own profile is only ever layered
    # over - "updates" - so the user's settings.json is never touched.
    $Guid = Get-WslProfileGuid -Name $DistroName
    if (-not $Guid) {
        Write-Host ""
        Write-Host "[ABORT] Windows Terminal has no profile for '$DistroName' - the font cannot be applied." -ForegroundColor Red
        Write-Host "        Nothing was modified." -ForegroundColor DarkGray
        exit 1
    }

    $Appearance = Get-InstanceAppearance -Name $DistroName
    Set-InstanceFragment -Name $DistroName -Guid $Guid -Font $Picked.Name `
        -ColorScheme $Appearance.ColorScheme -IconPath $IconPath
    Set-InstanceLook -InstallPath $Distro.BasePath -Look (New-InstanceLook -Name $DistroName)

    if (-not (Test-FontInstalled $Picked.Name)) {
        Write-Host "  Not installed on Windows: '$($Picked.Name)' - the profile points at it anyway." -ForegroundColor Yellow
    }

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

# Ask Terminal to look again - on both ways in. It started life inside the block
# below, which only the command run on its own reaches: through the menu, the
# change was written and Terminal was never told, so nothing appeared until every
# window was closed.
Update-TerminalSettings

if (-not $HandedOver) {
    Write-Host "'$DistroName' is done, and Windows Terminal has re-read its settings: a new tab is" -ForegroundColor DarkGray
    Write-Host "written in that font." -ForegroundColor DarkGray
    Write-Host ""
}
exit 0
