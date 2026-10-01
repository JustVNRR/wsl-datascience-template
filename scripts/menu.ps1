# ==============================================================================
# ASKING: THE LIST EVERY COMMAND SHOWS
# ==============================================================================
# The instances, the packs, the archives: every command in this family offers a
# list, and Select-FromList draws it so it can be walked with the arrows:
# up/down move (and wrap), Enter chooses, Escape cancels, and a digit chooses
# directly in short lists. -Note adds one line under the list; -Multi makes it a
# checklist (space checks, Enter applies) - "none checked" and "cancelled" are
# different answers, kept apart by the comma before the return.
#
# The one reason it falls back to the numbered prompt: no console (a pipe, a
# script, a test), or a host without one. The check is made BEFORE reading -
# [Console]::ReadKey does not throw there, it BLOCKS. A narrow window or a long
# list does not send us back any more: the drawing gives way instead - the
# labels are cut to the width, the list scrolls inside the window.
#
# This file defines functions; it is not a command.
# ==============================================================================

# Loaded here too: tests\menu-test.ps1 drives this file on its own, and a file
# that draws every line as a message says where the colour comes from.
. (Join-Path $PSScriptRoot "message.ps1")

# Is there a keyboard we can read without hanging? Both checks are cheap and
# neither one blocks: CursorTop and KeyAvailable throw without a console, and
# a throw is an answer.
function Test-KeyInput {
    if ([Console]::IsInputRedirected) { return $false }
    try {
        $null = $Host.UI.RawUI.KeyAvailable
        return $true
    } catch {
        return $false
    }
}

# The one line in the project that touches the keyboard. [ConsoleKey] is what
# the loop below compares: UpArrow, DownArrow, Enter, Escape, D1..D9.
function Read-MenuKey {
    return [Console]::ReadKey($true).Key
}

# $null means the host would not say - not the same as "row zero". A terminal
# that refuses to be drawn on leaves the menu working, only uglier: the choice
# is the keys, never the paint.
function Get-ConsoleTop {
    try { return [Console]::CursorTop } catch { return $null }
}

# Says whether it moved: a silent failure here is what turned a menu into a
# stack of copies once - every repaint landed where the cursor already was.
function Set-ConsoleTop {
    param([int]$Top)
    try {
        [Console]::SetCursorPosition(0, $Top)
        return ([Console]::CursorTop -eq $Top)
    } catch {
        return $false
    }
}

# Both questions have to be yes: a console that reads the escape sequences, and
# somebody looking at them - a pipe is reading a file, not a screen.
function Test-ColourOutput {
    $Coloured = $false
    try { $Coloured = [bool]$Host.UI.SupportsVirtualTerminal } catch { $Coloured = $false }
    if ($env:WT_SESSION) { $Coloured = $true }
    if ($Coloured) { $Coloured = Test-KeyInput }
    return $Coloured
}

# "#CF7040" -> "207;112;64": how a terminal spells a colour.
function ConvertTo-Rgb {
    param([string]$Hex)

    $Hex = $Hex.TrimStart("#")
    return "{0};{1};{2}" -f [Convert]::ToInt32($Hex.Substring(0, 2), 16),
                           [Convert]::ToInt32($Hex.Substring(2, 2), 16),
                           [Convert]::ToInt32($Hex.Substring(4, 2), 16)
}

# A clean screen, for going down a level or coming back up one. The first
# version blanked exactly the rows each menu had drawn - row numbers are
# absolute and the console moves, so one scroll made every remembered row a row
# off. Clearing is one call and cannot drift; the price, chosen: what was above
# goes with it.
function Clear-MenuScreen {
    try { Clear-Host } catch { }
}

# One row of the list, as it is drawn: the marker and the colours say where the
# choice is, so a terminal that renders neither still reads correctly.
function Format-MenuRow {
    param([int]$Index, [int]$Current, [string[]]$Labels, [bool[]]$Checked)

    $Marker = if ($Index -eq $Current) { "  > " } else { "    " }
    if ($null -eq $Checked) { return ($Marker + $Labels[$Index]) }
    # A multi-select list says what is checked and what is not. The marker keeps
    # saying where the cursor is - two questions, two signs.
    $Box = if ($Checked[$Index]) { "[x] " } else { "[ ] " }
    return ($Marker + $Box + $Labels[$Index])
}

# One row is one line, always: a wrapped row is a row whose neighbours are no
# longer where the arithmetic says. The tail is cut rather than the menu
# refused; a window that will not say how wide it is gets no cutting at all.
#
# -Prefix says what goes in front of the label: 4 for the marker, 8 for a
# checklist row, 0 for the title and the hint. The box is what this was written
# for - the cut left room for the marker only, the row wrapped, and the same
# pack appeared twice. Title and hint obey the same rule: any line that wraps
# moves everything below by one.
function Format-MenuLabels {
    param([string[]]$Labels, [int]$Width, [int]$Prefix = 4)
    if ($Width -le 0) { return $Labels }
    $Room = $Width - 1
    return @($Labels | ForEach-Object {
        $Max = $Room - $Prefix
        if ($_.Length -le $Max) { $_ }
        else { $_.Substring(0, [Math]::Max(1, $Max - 3)) + "..." }
    })
}

function Write-MenuRow {
    param([int]$Index, [int]$Current, [string[]]$Labels, [bool[]]$Checked)
    $Row = Format-MenuRow -Index $Index -Current $Current -Labels $Labels -Checked $Checked
    if ($Index -eq $Current) {
        Write-Host $Row -ForegroundColor (Get-MessageColour info)
    } else {
        Write-Host $Row
    }
}

# Width and height, or zeroes when the host will not say - zero meaning "no
# constraint", so a host that keeps quiet is never a reason to give up on the
# arrows. ($null, unlike 0, means the host said nothing at all.)
function Get-ConsoleSize {
    try {
        $Size = $Host.UI.RawUI.WindowSize
        return @([int]$Size.Width, [int]$Size.Height)
    } catch {
        return @(0, 0)
    }
}

# The prompt every command used before the arrows: numbered rows, a number
# typed, an empty answer cancelling. Read-Host returns an empty string when its
# input is closed, so a run with no console can never loop forever.
function Select-ByNumber {
    param([string]$Title, [string[]]$Labels, [object[]]$Items, [switch]$Multi, [bool[]]$Checked,
          [string]$Note = "")

    $Count = $Items.Count

    if ($Multi) {
        if ($null -eq $Checked) { $Checked = New-Object bool[] $Count }
        while ($true) {
            # The list is written again at every turn: a box that changed has to
            # be seen, and with no console to paint on there is nowhere else to
            # put it.
            Write-Host ""
            if ($Title) { Write-Host "$Title" -ForegroundColor (Get-MessageColour info) }
            for ($Index = 0; $Index -lt $Count; $Index++) {
                $Box = if ($Checked[$Index]) { "[x]" } else { "[ ]" }
                Write-Host ("  {0,2}.  {1} {2}" -f ($Index + 1), $Box, $Labels[$Index])
            }
            Write-Host "   0.  Cancel"
            if ($Note) { Write-Host "  $Note" -ForegroundColor (Get-MessageColour muted) }

            $Answer = [string](Read-Host "Number toggles, v applies, 0 cancels")
            if ([string]::IsNullOrWhiteSpace($Answer) -or $Answer.Trim() -eq "0") { return $null }
            if ($Answer.Trim() -match "^[vV]$") {
                $Chosen = @()
                for ($Index = 0; $Index -lt $Count; $Index++) {
                    if ($Checked[$Index]) { $Chosen += $Items[$Index] }
                }
                return ,$Chosen
            }
            $Number = 0
            if ([int]::TryParse($Answer.Trim(), [ref]$Number) -and
                $Number -ge 1 -and $Number -le $Count) {
                $Checked[$Number - 1] = -not $Checked[$Number - 1]
                continue
            }
            Write-Host "  '$Answer' is not one of the numbers above." -ForegroundColor (Get-MessageColour warning)
        }
    }

    Write-Host ""
    if ($Title) { Write-Host "$Title" -ForegroundColor (Get-MessageColour info) }
    for ($Index = 0; $Index -lt $Count; $Index++) {
        Write-Host ("  {0,2}.  {1}" -f ($Index + 1), $Labels[$Index])
    }
    Write-Host "   0.  Cancel"
    if ($Note) { Write-Host "  $Note" -ForegroundColor (Get-MessageColour muted) }

    while ($true) {
        $Answer = [string](Read-Host "Which one? (0 to cancel)")
        if ([string]::IsNullOrWhiteSpace($Answer)) { return $null }
        $Number = 0
        if ([int]::TryParse($Answer.Trim(), [ref]$Number)) {
            if ($Number -eq 0) { return $null }
            if ($Number -ge 1 -and $Number -le $Count) { return $Items[$Number - 1] }
        }
        Write-Host "  '$Answer' is not one of the numbers above." -ForegroundColor (Get-MessageColour warning)
    }
}

# The rows are drawn once and repainted in place - every label keeps its length,
# so nothing has to be erased, and no Clear-Host.
#
# -KeyReader exists for the tests: a script returns a [ConsoleKey] on demand, so
# the whole loop - wrapping included - runs with no terminal in sight.
function Select-WithArrows {
    param(
        [string]$Title,
        [string[]]$Labels,
        [object[]]$Items,
        [scriptblock]$KeyReader,
        [int]$Start = 0,
        [switch]$Multi,
        [bool[]]$Checked,
        [string]$Note = ""
    )

    $Count = $Items.Count
    $Current = $Start
    if ($Multi -and $null -eq $Checked) { $Checked = New-Object bool[] $Count }
    $Hint = if ($Multi) { "  up/down to move, space to check, Enter to apply, Escape to cancel" }
            else { "  up/down to move, Enter to choose, Escape to cancel" }
    $Size = Get-ConsoleSize
    # Every line of the block is cut to the window, title and hint included: one
    # line that wraps moves the rows below by one, and the arithmetic below is
    # written for exactly Visible + 3 lines, plus the note when there is one. A
    # line the arithmetic does not know about is the bug this file was written
    # against.
    $Extra = if ($Note) { 1 } else { 0 }
    $Shown = Format-MenuLabels -Labels $Labels -Width $Size[0] -Prefix $(if ($Multi) { 8 } else { 4 })
    $ShownTitle = @(Format-MenuLabels -Labels @($Title) -Width $Size[0] -Prefix 0)[0]
    $ShownHint = @(Format-MenuLabels -Labels @($Hint) -Width $Size[0] -Prefix 0)[0]
    $ShownNote = @(Format-MenuLabels -Labels @($Note) -Width $Size[0] -Prefix 0)[0]

    # A list taller than the window scrolls rather than refuse: only the rows
    # that fit are drawn, and the window follows the choice. Three lines kept
    # for the blank and the hint, one more for the note.
    $Visible = if ($Size[1] -gt 0) { [Math]::Min($Count, [Math]::Max(1, $Size[1] - 3 - $Extra)) } else { $Count }
    # The choice starts in the middle when it can: it is where the eye goes.
    $First = [Math]::Max(0, [Math]::Min($Current - [int](($Visible - 1) / 2), $Count - $Visible))

    # The top row is READ BACK from the cursor after drawing, never computed
    # before: writing the block can scroll the console, and a row number from
    # before is wrong by what scrolled - that was the bug: every arrow added one
    # more copy of the list.
    Write-Host ""
    if ($ShownTitle) { Write-Host "$ShownTitle" -ForegroundColor (Get-MessageColour info) }
    for ($Row = 0; $Row -lt $Visible; $Row++) {
        Write-MenuRow -Index ($First + $Row) -Current $Current -Labels $Shown -Checked $Checked
    }
    Write-Host $ShownHint -ForegroundColor (Get-MessageColour muted)
    if ($ShownNote) { Write-Host $ShownNote -ForegroundColor (Get-MessageColour muted) }

    $Cursor = Get-ConsoleTop
    $Top = if ($null -ne $Cursor) { $Cursor - ($Visible + 1 + $Extra) } else { 0 }
    # No cursor reading (a test, a host that will not say): the loop still
    # answers the keys, it simply does not repaint - there is nothing to paint
    # on.
    $CanPaint = ($null -ne $Cursor) -and ($Top -ge 0)

    while ($true) {
        $Key = if ($KeyReader) { & $KeyReader } else { Read-MenuKey }
        $Last = $Count - 1
        $Moved = $true

        if ($Key -eq [ConsoleKey]::UpArrow) {
            $Current = if ($Current -eq 0) { $Last } else { $Current - 1 }
        } elseif ($Key -eq [ConsoleKey]::DownArrow) {
            $Current = if ($Current -eq $Last) { 0 } else { $Current + 1 }
        } elseif ($Key -eq [ConsoleKey]::Spacebar -and $Multi) {
            # Space checks and unchecks where the cursor is. In a single-choice
            # list it means nothing, and nothing is what it does.
            $Checked[$Current] = -not $Checked[$Current]
        } elseif ($Key -eq [ConsoleKey]::Enter) {
            if ($CanPaint) { $null = Set-ConsoleTop ($Top + $Visible + 1 + $Extra) }
            if ($Multi) {
                $Wanted = @()
                for ($Index = 0; $Index -lt $Count; $Index++) {
                    if ($Checked[$Index]) { $Wanted += $Items[$Index] }
                }
                # The comma: without it an empty list arrives as nothing at all,
                # and "I checked none" is not the same answer as "I cancelled".
                return ,$Wanted
            }
            return $Items[$Current]
        } elseif ($Key -eq [ConsoleKey]::Escape) {
            if ($CanPaint) { $null = Set-ConsoleTop ($Top + $Visible + 1 + $Extra) }
            return $null
        } elseif (($Key -ge [ConsoleKey]::D1 -and $Key -le [ConsoleKey]::D9) -or
                  ($Key -ge [ConsoleKey]::NumPad1 -and $Key -le [ConsoleKey]::NumPad9)) {
            $Wanted = if ($Key -ge [ConsoleKey]::NumPad1) { [int]$Key - [int][ConsoleKey]::NumPad1 }
                      else { [int]$Key - [int][ConsoleKey]::D1 }
            if ($Wanted -lt $Count) {
                if ($Multi) {
                    $Checked[$Wanted] = -not $Checked[$Wanted]    # a digit checks, it does not leave
                } else {
                    if ($CanPaint) { $null = Set-ConsoleTop ($Top + $Visible + 1 + $Extra) }
                    return $Items[$Wanted]
                }
            }
        } else {
            $Moved = $false                   # a key the menu has no use for
        }

        if (-not $Moved -or -not $CanPaint) { continue }

        # Bring the choice back into the window, then repaint where the rows
        # already are; if the cursor will not go back, the block is written
        # again - one more copy is ugly, a screen showing the wrong current row
        # is worse.
        if ($Current -lt $First) { $First = $Current }
        if ($Current -ge ($First + $Visible)) { $First = $Current - $Visible + 1 }

        $Placed = $true
        for ($Row = 0; $Row -lt $Visible; $Row++) {
            if (-not (Set-ConsoleTop ($Top + $Row))) { $Placed = $false; break }
            Write-MenuRow -Index ($First + $Row) -Current $Current -Labels $Shown -Checked $Checked
        }
        if (-not $Placed) {
            for ($Row = 0; $Row -lt $Visible; $Row++) {
                Write-MenuRow -Index ($First + $Row) -Current $Current -Labels $Shown -Checked $Checked
            }
        }
    }
}

# What every caller wants: the list, the arrows when the machine can have them,
# the numbered prompt otherwise, and the chosen item - or $null, which every
# caller reads as "the user cancelled".
function Select-FromList {
    param(
        [string]$Title = "",
        [object[]]$Items = @(),
        [scriptblock]$Label = { param($Item) [string]$Item },
        [scriptblock]$KeyReader,
        [int]$DefaultIndex = 0,
        [switch]$Multi,
        [int[]]$CheckedIndexes = @(),
        [string]$Note = ""
    )

    $Items = @($Items)
    if ($Items.Count -eq 0) { return $null }
    if ($Multi) {
        $Checked = New-Object bool[] $Items.Count
        foreach ($Index in $CheckedIndexes) {
            if ($Index -ge 0 -and $Index -lt $Items.Count) { $Checked[$Index] = $true }
        }
    } else {
        $Checked = $null
    }
    # Where the choice starts, so that Enter takes the answer the command would
    # have taken anyway. An index that is not in the list is the first one: a
    # default is a favour, not a way to fail.
    if ($DefaultIndex -lt 0 -or $DefaultIndex -ge $Items.Count) { $DefaultIndex = 0 }
    $Labels = @($Items | ForEach-Object { [string](& $Label $_) })

    # A -KeyReader means a test asked for the arrows - it stands in for the
    # console a test has not got. Nothing else sends us to the numbered prompt:
    # the drawing gives way instead.
    $Arrows = [bool]$KeyReader -or (Test-KeyInput)

    if (-not $Arrows) {
        $Chosen = Select-ByNumber -Title $Title -Labels $Labels -Items $Items -Multi:$Multi -Checked $Checked -Note $Note
    } else {
        $Chosen = Select-WithArrows -Title $Title -Labels $Labels -Items $Items -KeyReader $KeyReader `
            -Start $DefaultIndex -Multi:$Multi -Checked $Checked -Note $Note
    }

    # Multi hands back a list that has to survive the trip: an array written to
    # the pipeline is unrolled - a single checked item arrives as that item, an
    # empty list as NOTHING AT ALL, which is what a cancellation looks like.
    # Hence the comma, and the cancellation checked first.
    if ($Multi) {
        if ($null -eq $Chosen) { return $null }
        return ,$Chosen
    }
    return $Chosen
}

# ---------------------------------------------------------------------------
# THE LIST THIS FAMILY SHOWS MOST
# ---------------------------------------------------------------------------
# The instances that are OURS, with the state and the room each takes - filtered
# on the marker: the machine holds other distributions, and none of them are
# ours to touch.
#
# Escape is the end of the command that asked, unless -AllowCancel: then it is
# $null, for a command that has somewhere to go back to.
function Select-Distro {
    param([switch]$AllowCancel)

    $All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.BasePath } | Sort-Object Name)
    if ($All.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor (Get-MessageColour error)
        Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor (Get-MessageColour hint)
        exit 1
    }

    $Running = Get-DistroNames -Running
    $Chosen = Select-FromList -Title "Our Instances" -Items $All -Label {
        param($Instance)
        $State = if ($Running -contains $Instance.Name) { "running" } else { "stopped" }
        "{0,-30} {1,-8} {2,10}" -f $Instance.Name, $State, (Format-Size (Get-VhdxSize $Instance.BasePath))
    }

    if (-not $Chosen) {
        if ($AllowCancel) { return $null }
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor (Get-MessageColour success)
        exit 0
    }
    return $Chosen
}
