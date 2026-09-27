[CmdletBinding()]
param (
    # The instance, when the theme menu has already asked which one. Not an
    # option and not documented as one: no command of this family takes a name
    # typed by heart - this is how the level above hands over, and the command is
    # not a command of wsl.ps1 in the first place.
    [string]$DistroName
)

# The icon is a file, not a setting: terminal-icon.png in the instance's own
# folder, the one the Terminal profile points at. This command draws another
# over it, or copies an image of yours there. Nothing else is written - and
# nothing has to be stopped for it: an icon belongs to a tab as it is opened.
#
# It keeps asking: one change keeps the others, so changing two things is the
# ordinary way to use it, and the menu comes back after each one. Escape is how
# it ends.

$ErrorActionPreference = "Stop"

$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

# One script draws every icon, whether an instance is built or its icon is
# redrawn years later: the letters and the colours cannot drift apart.
$IconScript = Join-Path (Split-Path -Path $PSScriptRoot -Parent) "assets\make-icon.ps1"
if (-not (Test-Path $IconScript)) {
    Write-Host ""
    Write-Host "[ABORT] assets\make-icon.ps1 is missing - the checkout is incomplete." -ForegroundColor Red
    Write-Host "        Nothing was modified." -ForegroundColor DarkGray
    exit 1
}

# 1. Which instance, and where its icon lives. Given, or asked.
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

# The menus it came through - the way in, the instance it picked - come off the
# screen: this command opens on its own question, and a visit of four turns is
# one screen rather than four stacked menus.
Clear-MenuScreen

# The one thing worth saying before the question - where the icon is, and what
# was drawn there last, are both said inside it. This one is said because it is
# what would make all of it invisible: an icon is only ever read through the
# fragment this repository writes.
$OurFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-datascience-template\$DistroName.json"
if (-not (Test-Path $OurFragment)) {
    Write-Host ""
    Write-Host "[WARNING] This instance has no Terminal profile of ours - the icon would not show." -ForegroundColor Yellow
    Write-Host "          Build it again, or set the icon by hand in Ctrl+," -ForegroundColor DarkGray
}

# The escape character, and whether colours are worth writing: the second from
# menu.ps1, where it is written once for every command that shows a colour.
$Escape = [char]27
$Coloured = Test-ColourOutput

# An empty answer, wherever it is asked, is a cancel like any other. The question
# is written here and Read-Host asked bare: what Read-Host writes itself never
# reaches a pipe, and a question worth asking is worth showing.
function Read-Answer {
    param([string]$Question)

    Write-Host -NoNewline "${Question}: "
    $Answer = [string](Read-Host).Trim()
    if ([string]::IsNullOrWhiteSpace($Answer)) {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
        exit 0
    }
    return $Answer
}

# One turn of the menu: ask for whatever the choice needs, then draw the icon or
# copy the image there, and note what it is made of in the instance's own file -
# the one an archive carries.
#
# A drawing that fails leaves the icon that was there: the drawing script writes
# the picture once, at the end, and nothing before that.
function Invoke-IconChoice {
    param([hashtable]$Choice, [hashtable]$Recipe, [string]$Suggestion)

    # What the drawing script is told, by name: -Name gives the letters and the
    # colours, whatever is put beside it wins over it - and what the icon is
    # already made of is put beside it first, so only the part being changed
    # moves.
    #
    # A table of parameters, not a list of them. Handed a LIST, the drawing script
    # receives its values in order and not by name: "-Text" would land where a
    # colour is expected, and the tile would be drawn in the colour of the word
    # "-Text" - which is to say not at all. (Measured, on the day this command was
    # first run.)
    $Draw = @{ Name = $DistroName }
    $Draw += $Recipe
    $Source = $null

    switch ($Choice.How) {
        "auto" {
            # Start again from the name: whatever was kept of the previous drawing
            # goes with it, letters and colours both.
            $Draw = @{ Name = $DistroName }
        }
        "letters" {
            # Up to three. A tab is about sixteen pixels tall, and past three
            # letters stop being letters - which is the point of the tile.
            $Question = if ($Suggestion) { "Letters, 1 to 3 [$Suggestion]" } else { "Letters, 1 to 3" }
            while ($true) {
                Write-Host -NoNewline "${Question}: "
                $Answer = [string](Read-Host).Trim()
                # Enter takes what is suggested - the letters the icon has now, or
                # the name's when nothing was drawn. With nothing to suggest, it
                # cancels, like every other empty answer in this family.
                if ([string]::IsNullOrWhiteSpace($Answer)) {
                    if (-not $Suggestion) {
                        Write-Host ""
                        Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
                        exit 0
                    }
                    $Draw.Text = $Suggestion
                    break
                }
                if ($Answer -match '^[A-Za-z0-9]{1,3}$') {
                    $Draw.Text = $Answer.ToUpper()
                    break
                }
                Write-Host "  One to three letters or digits." -ForegroundColor Yellow
            }
        }
        "colours" {
            $Rows = @(& $IconScript -ListPairs | Where-Object { $_ })
            $Picked = Select-FromList -Title "Colours for '$DistroName'" -Items $Rows -Label {
                param($Row)
                $Field = $Row -split "`t"
                # What is being chosen is a look, and two hex codes say nothing to
                # the eye: the letters are shown in the colours of the pair. Only
                # the background is exact - the ink is white, or dark on the light
                # tile - which is one escape fewer and the same picture.
                $Sample = $Suggestion
                if ($Coloured) {
                    $Ink = if ($Field[3] -eq "#FFFFFF") { "97" } else { "30" }
                    $Sample = "{0}[48;2;{1}m{0}[{2}m {3} {0}[0m" -f $Escape, (ConvertTo-Rgb $Field[1]), $Ink, $Suggestion
                }
                # The pair the icon is on now, said rather than left to be guessed:
                # choosing is easier when you know where you are.
                $Here = if ($Recipe.Top -eq $Field[1] -and $Recipe.Bottom -eq $Field[2]) { "  (current)" } else { "" }
                "{0}  {1,-9}{2}" -f $Sample, $Field[0], $Here
            }
            if (-not $Picked) {
                Write-Host ""
                Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
                exit 0
            }
            $Field = $Picked -split "`t"
            $Draw.Top = $Field[1]
            $Draw.Bottom = $Field[2]
            $Draw.TextColor = $Field[3]
        }
        "image" {
            while (-not $Source) {
                $Answer = (Read-Answer "Path of the image, PNG JPG ICO or BMP (CTRL+C to abort)").Trim('"')
                if (-not (Test-Path -LiteralPath $Answer -PathType Leaf)) {
                    Write-Host "  No file at that path." -ForegroundColor Yellow
                    continue
                }
                if ((Split-Path -Leaf $Answer) -notmatch '\.(png|jpg|jpeg|ico|bmp)$') {
                    Write-Host "  The name has to end in .png, .jpg, .jpeg, .ico or .bmp." -ForegroundColor Yellow
                    continue
                }
                $Source = (Resolve-Path -LiteralPath $Answer).Path
            }
        }
    }

    # Nothing is announced: the menu comes straight back, and the icon in the
    # tab is the answer. A failure is the one thing worth saying.
    if ($Source) {
        Copy-Item -LiteralPath $Source -Destination $IconPath -Force
        # The recipe stays where it is: an image replaces the picture, not what you
        # had drawn before it. Changing your mind starts from there again.
    } else {
        try {
            $Drawn = & $IconScript @Draw -Out $IconPath -Quiet -What | ConvertFrom-Json
        } catch {
            Write-Host ""
            Write-Host "[ABORT] The icon could not be drawn: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "        The icon that was there is still there." -ForegroundColor DarkGray
            exit 1
        }
        $Icon = @{
            Text      = $Drawn.Text
            Top       = $Drawn.Top
            Bottom    = $Drawn.Bottom
            TextColor = $Drawn.TextColor
        }
        Set-InstanceLook -InstallPath $Distro.BasePath -Look (New-InstanceLook -Name $DistroName -Icon $Icon)
    }
}

# 2. The question, again and again
$Choices = @(
    @{ What = "By Default"; How = "auto" },
    @{ What = "text";       How = "letters" },
    @{ What = "colors";     How = "colours" },
    @{ What = "local file"; How = "image" }
)

$Default = 0
$Changed = $false

while ($true) {
    # Read again every turn: the questions offer what the icon is made of now, and
    # the turn before may have changed it. The recipe is what makes one change
    # keep the others - redraw the colours and the letters you typed stay - and it
    # is kept whatever the icon on disk is, an image of your own included.
    $Current = Get-IconRecipe -Name $DistroName
    $Suggested = $Current.Text
    if (-not $Suggested) {
        $Suggested = [string](@(& $IconScript -Letters -Name $DistroName | Select-Object -First 1)[0])
    }

    Write-Host ""
    $Chosen = Select-FromList -Title "Icon of '$DistroName'" -Items $Choices -Label {
        param($Choice) $Choice.What
    } -DefaultIndex $Default

    if (-not $Chosen) { break }

    # The menu has been answered: the screen goes clean, and the answer takes its
    # place - then the screen again, so the menu comes back on its own.
    Clear-MenuScreen

    # The same place next time: two changes are one visit.
    $Default = [array]::IndexOf($Choices, $Chosen)

    Invoke-IconChoice -Choice $Chosen -Recipe $Current -Suggestion $Suggested

    # And the question goes when the answer is in: the menu comes back exactly
    # where it was, so the screen holds one thing at a time.
    Clear-MenuScreen
    $Changed = $true
}

if (-not $Changed) {
    # Handed over: the level above owns the goodbye, and it has its menu to draw
    # where this one was.
    if ($HandedOver) { exit 0 }
    Write-Host ""
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
    exit 0
}

if (-not $HandedOver) {
    Update-TerminalSettings
    Write-Host "'$DistroName' is done, and Windows Terminal has re-read its settings: a new tab" -ForegroundColor DarkGray
    Write-Host "wears the icon you chose." -ForegroundColor DarkGray
    Write-Host ""
}
exit 0
