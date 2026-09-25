# ==============================================================================
# ASKING: THE LIST EVERY COMMAND SHOWS
# ==============================================================================
# The instances, the packs, the archives: every command in this family offers a
# list, and until now each one printed it by hand and asked for a number.
#
# Select-FromList draws the same list so it can be walked with the arrows: up
# and down move (and wrap), Enter chooses, Escape cancels, and in a list of
# nine or fewer a digit chooses directly.
#
# With -Multi the same list is a checklist: space checks and unchecks where the
# cursor is, Enter applies, Escape cancels, and what comes back is the list of
# checked items - in the order they appear, and empty when none was checked.
# "None checked" and "cancelled" are different answers, and the comma before the
# return is what keeps them apart.
#
# It falls back to the numbered prompt - the one every command used before -
# and the fallback is the important half, because a menu that waits for a key
# on a machine with no keyboard waits forever:
#
#   - no console (input redirected: a pipe, a script, a test), or a host without
#     one to speak of (the ISE). The check is made BEFORE reading, never with a
#     try/catch around the read: [Console]::ReadKey does not throw there, it
#     BLOCKS - measured on 2026-09-25, with two minutes of nothing to show for
#     it - and a menu that waits for a key nobody can press waits forever.
#
# Nothing else sends a reader to the numbered prompt. A narrow window and a long
# list used to, and that was wrong: the arrows are what was asked for, so the
# drawing gives way instead - the labels are cut to the width, the list scrolls
# inside the window.
#
# This file defines functions; it is not a command. instance.ps1 loads it, and
# every command loads instance.ps1.
# ==============================================================================

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

# The cursor, asked gently, and answered honestly: $null means the host would
# not say, which is not the same as "row zero". A terminal that refuses to be
# drawn on - a redrawn window, a capture, a test - leaves the menu working, only
# uglier: the choice is the keys, never the paint.
function Get-ConsoleTop {
    try { return [Console]::CursorTop } catch { return $null }
}

# Moves the cursor, and says whether it moved. A silent failure here is what
# turned a menu into a stack of copies once: every repaint that could not be
# placed was written where the cursor already was, so each arrow added a block.
function Set-ConsoleTop {
    param([int]$Top)
    try {
        [Console]::SetCursorPosition(0, $Top)
        return ([Console]::CursorTop -eq $Top)
    } catch {
        return $false
    }
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

# One row is one line, always. A label wider than the window would wrap, and a
# wrapped block is a block whose rows are no longer where the arithmetic says
# they are - which is the shape of the bug this file already had once. So the
# tail is cut rather than the menu refused: the description loses its end, the
# arrows keep working. A window that will not say how wide it is (a test, a
# captured run) gets no cutting at all.
function Format-MenuLabels {
    param([string[]]$Labels, [int]$Width)
    if ($Width -le 0) { return $Labels }
    $Room = $Width - 1
    return @($Labels | ForEach-Object {
        $Max = $Room - 4                      # the "  > " marker in front
        if ($_.Length -le $Max) { $_ }
        else { $_.Substring(0, [Math]::Max(1, $Max - 3)) + "..." }
    })
}

function Write-MenuRow {
    param([int]$Index, [int]$Current, [string[]]$Labels, [bool[]]$Checked)
    $Row = Format-MenuRow -Index $Index -Current $Current -Labels $Labels -Checked $Checked
    if ($Index -eq $Current) {
        Write-Host $Row -ForegroundColor Cyan
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
    param([string]$Title, [string[]]$Labels, [object[]]$Items, [switch]$Multi, [bool[]]$Checked)

    $Count = $Items.Count

    if ($Multi) {
        if ($null -eq $Checked) { $Checked = New-Object bool[] $Count }
        while ($true) {
            # The list is written again at every turn: a box that changed has to
            # be seen, and with no console to paint on there is nowhere else to
            # put it.
            Write-Host ""
            if ($Title) { Write-Host "$Title" -ForegroundColor Cyan }
            for ($Index = 0; $Index -lt $Count; $Index++) {
                $Box = if ($Checked[$Index]) { "[x]" } else { "[ ]" }
                Write-Host ("  {0,2}.  {1} {2}" -f ($Index + 1), $Box, $Labels[$Index])
            }
            Write-Host "   0.  Cancel"

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
            Write-Host "  '$Answer' is not one of the numbers above." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    if ($Title) { Write-Host "$Title" -ForegroundColor Cyan }
    for ($Index = 0; $Index -lt $Count; $Index++) {
        Write-Host ("  {0,2}.  {1}" -f ($Index + 1), $Labels[$Index])
    }
    Write-Host "   0.  Cancel"

    while ($true) {
        $Answer = [string](Read-Host "Which one? (0 to cancel)")
        if ([string]::IsNullOrWhiteSpace($Answer)) { return $null }
        $Number = 0
        if ([int]::TryParse($Answer.Trim(), [ref]$Number)) {
            if ($Number -eq 0) { return $null }
            if ($Number -ge 1 -and $Number -le $Count) { return $Items[$Number - 1] }
        }
        Write-Host "  '$Answer' is not one of the numbers above." -ForegroundColor Yellow
    }
}

# The arrow menu. The rows are drawn once and repainted in place: the cursor
# goes back up to the first row and each line is written again. Every label
# keeps its length, so nothing has to be erased - and no Clear-Host, which
# would wipe what the user scrolled through before.
#
# -KeyReader exists for the tests: it replaces the keyboard with a script that
# returns a [ConsoleKey] on demand, so the whole loop - wrapping included - runs
# with no terminal in sight.
function Select-WithArrows {
    param(
        [string]$Title,
        [string[]]$Labels,
        [object[]]$Items,
        [scriptblock]$KeyReader,
        [int]$Start = 0,
        [switch]$Multi,
        [bool[]]$Checked
    )

    $Count = $Items.Count
    $Current = $Start
    if ($Multi -and $null -eq $Checked) { $Checked = New-Object bool[] $Count }
    $Hint = if ($Multi) { "  up/down to move, space to check, Enter to apply, Escape to cancel" }
            else { "  up/down to move, Enter to choose, Escape to cancel" }
    $Size = Get-ConsoleSize
    $Shown = Format-MenuLabels -Labels $Labels -Width $Size[0]

    # A list taller than the window is scrolled rather than refused: only the
    # rows that fit are drawn, and the window follows the choice. Three lines
    # are kept for the blank above the title and the hint below it.
    $Visible = if ($Size[1] -gt 0) { [Math]::Min($Count, [Math]::Max(1, $Size[1] - 3)) } else { $Count }
    # The choice starts in the middle when it can: it is where the eye goes.
    $First = [Math]::Max(0, [Math]::Min($Current - [int](($Visible - 1) / 2), $Count - $Visible))

    # Drawn once, in the natural course of the output - and the top row is READ
    # BACK from the cursor only after that. Not computed before drawing: writing
    # the block can scroll the console (a command that prints a lot before its
    # menu leaves the cursor near the bottom), the lines just written move up
    # with the scroll, and a row number remembered from before it is wrong by
    # exactly what scrolled. That was the bug: every arrow added one more copy
    # of the list, lower each time, whenever the console had scrolled.
    Write-Host ""
    if ($Title) { Write-Host "$Title" -ForegroundColor Cyan }
    for ($Row = 0; $Row -lt $Visible; $Row++) {
        Write-MenuRow -Index ($First + $Row) -Current $Current -Labels $Shown -Checked $Checked
    }
    Write-Host $Hint -ForegroundColor DarkGray

    $Cursor = Get-ConsoleTop
    $Top = if ($null -ne $Cursor) { $Cursor - ($Visible + 1) } else { 0 }
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
            if ($CanPaint) { $null = Set-ConsoleTop ($Top + $Visible + 1) }
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
            if ($CanPaint) { $null = Set-ConsoleTop ($Top + $Visible + 1) }
            return $null
        } elseif (($Key -ge [ConsoleKey]::D1 -and $Key -le [ConsoleKey]::D9) -or
                  ($Key -ge [ConsoleKey]::NumPad1 -and $Key -le [ConsoleKey]::NumPad9)) {
            $Wanted = if ($Key -ge [ConsoleKey]::NumPad1) { [int]$Key - [int][ConsoleKey]::NumPad1 }
                      else { [int]$Key - [int][ConsoleKey]::D1 }
            if ($Wanted -lt $Count) {
                if ($Multi) {
                    $Checked[$Wanted] = -not $Checked[$Wanted]    # a digit checks, it does not leave
                } else {
                    if ($CanPaint) { $null = Set-ConsoleTop ($Top + $Visible + 1) }
                    return $Items[$Wanted]
                }
            }
        } else {
            $Moved = $false                   # a key the menu has no use for
        }

        if (-not $Moved -or -not $CanPaint) { continue }

        # Bring the choice back into the window if it left it, then repaint the
        # rows where they already are. If the cursor will not go back, the whole
        # block is written again instead: one more copy is ugly, a screen
        # showing a choice that is no longer the current one is worse - and this
        # is the one failure that must never pass unnoticed.
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
        [int[]]$CheckedIndexes = @()
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

    # A -KeyReader means a test asked for the arrows: it stands in for the
    # console, which a test has not got. Nothing else sends us to the numbered
    # prompt - a narrow window or a long list used to, and that was wrong: the
    # arrows are what the reader asked for, so the drawing gives way instead
    # (the labels are cut to the width, the list scrolls in the window).
    $Arrows = [bool]$KeyReader -or (Test-KeyInput)

    if (-not $Arrows) {
        if ($Multi) {
            return (Select-ByNumber -Title $Title -Labels $Labels -Items $Items -Multi -Checked $Checked)
        }
        return (Select-ByNumber -Title $Title -Labels $Labels -Items $Items)
    }

    $Chosen = Select-WithArrows -Title $Title -Labels $Labels -Items $Items -KeyReader $KeyReader `
        -Start $DefaultIndex -Multi:$Multi -Checked $Checked
    # Multi hands back a list, and a list has to survive the trip: without the
    # comma, a single checked item arrives as that item and none arrives as
    # nothing, and the caller cannot tell "none" from "cancelled".
    if ($Multi) { return ,$Chosen }
    return $Chosen
}

# ---------------------------------------------------------------------------
# THE LIST THIS FAMILY SHOWS MOST
# ---------------------------------------------------------------------------
# The instances that are OURS, with the state and the room each takes. The list
# is filtered on the marker: the machine holds other distributions - Docker
# Desktop's, a colleague's - and none of them are ours to touch. An instance
# that is not in this list is not missing; it is not ours.
function Select-Distro {
    $All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.BasePath } | Sort-Object Name)
    if ($All.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor Red
        Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor Yellow
        Write-Host "        Already have one? Make it ours with  .\wsl.ps1 adopt" -ForegroundColor Yellow
        exit 1
    }

    $Running = Get-DistroNames -Running
    $Chosen = Select-FromList -Title "Our Instances" -Items $All -Label {
        param($Instance)
        $State = if ($Running -contains $Instance.Name) { "running" } else { "stopped" }
        "{0,-30} {1,-8} {2,10}" -f $Instance.Name, $State, (Format-Size (Get-VhdxSize $Instance.BasePath))
    }

    if (-not $Chosen) {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
        exit 0
    }
    return $Chosen
}
